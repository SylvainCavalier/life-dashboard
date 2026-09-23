// Enregistrement d'une reunion en direct, dans le navigateur.
//
// - Presentiel : micro de l'appareil (iPhone pose sur la table, ou Mac).
// - Visio : audio d'un onglet (Meet, Teams web, Zoom web...) capture par getDisplayMedia,
//   mixe avec le micro dans un AudioContext. Chrome/Edge sur ordinateur uniquement.
//
// MediaRecorder tourne avec un timeslice de 30 s : chaque tranche part aussitot au
// serveur (POST /meetings/:id/chunks), dans une file sequentielle qui relance tant
// que le reseau ne repond pas. Les tranches d'un meme flux, recollees, reforment le
// fichier : c'est le job qui les assemble. Une interruption (micro coupe, partage
// arrete, page suspendue par iOS) ferme la partie ; « Reprendre » en ouvre une autre.
import { ref, onBeforeUnmount } from 'vue'
import apiClient from '../plugins/axios'

const CHUNK_MS = 30000
const BITRATE = 48000
const MIME_TYPES = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4']
const EXTENSIONS = { 'audio/webm': 'webm', 'audio/mp4': 'm4a', 'audio/ogg': 'ogg' }
const MAX_RETRY_DELAY = 30000

export const canRecordMic = () =>
  typeof window !== 'undefined' &&
  window.isSecureContext &&
  !!navigator.mediaDevices?.getUserMedia &&
  typeof window.MediaRecorder !== 'undefined'

// Safari sait partager l'ecran mais pas l'audio d'un onglet ; sur mobile, pas de partage du tout.
export const canCaptureTab = () =>
  canRecordMic() &&
  !!navigator.mediaDevices?.getDisplayMedia &&
  !/iPhone|iPad|Android/i.test(navigator.userAgent) &&
  /Chrome|Edg\//.test(navigator.userAgent)

class TabAudioMissing extends Error {}

const pickMimeType = () => MIME_TYPES.find((type) => MediaRecorder.isTypeSupported?.(type)) || ''
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

const describe = (e) => {
  if (e instanceof TabAudioMissing) return "Aucun son capte sur l'onglet : relancez en choisissant l'onglet de la visio et en cochant « Partager aussi l'audio de l'onglet »."
  if (e?.name === 'NotAllowedError') return "Acces refuse (micro ou partage d'onglet). Autorisez-le dans les reglages du site puis reessayez."
  if (e?.name === 'NotFoundError') return 'Aucun micro detecte.'
  return e?.response?.data?.errors?.join(', ') || e?.message || "L'enregistrement n'a pas pu demarrer."
}

// state : idle | starting | recording | interrupted | stopping | finished | error
export function useMeetingRecorder() {
  const state = ref('idle')
  const error = ref(null)
  const notice = ref(null)
  const elapsed = ref(0)
  const micLevel = ref(0)
  const tabLevel = ref(0)
  const sent = ref(0)
  const pending = ref(0)
  const retrying = ref(false)
  const wakeLockActive = ref(false)

  let meetingId = null
  let mode = 'in_person'
  let part = 1
  let seq = 0
  let recorder = null
  let streams = []
  let audioCtx = null
  let analysers = {}
  let rafId = null
  let ticker = null
  let startedAt = 0
  let baseSeconds = 0
  let wakeLock = null
  let onRecorderStop = null
  let cancelled = false
  const queue = []
  let pumping = false

  // --- File d'envoi ---------------------------------------------------------

  const enqueue = (blob) => {
    queue.push({ part, seq: seq++, blob })
    pending.value = queue.length
    pump()
  }

  const pump = async () => {
    if (pumping) return
    pumping = true
    let delay = 2000
    while (queue.length && !cancelled) {
      const item = queue[0]
      const type = (item.blob.type || 'audio/webm').split(';')[0]
      const form = new FormData()
      form.append('chunk', item.blob, `part-${item.part}-${item.seq}.${EXTENSIONS[type] || 'webm'}`)
      form.append('part', item.part)
      form.append('seq', item.seq)
      try {
        await apiClient.post(`/meetings/${meetingId}/chunks`, form, {
          headers: { 'Content-Type': 'multipart/form-data' },
          timeout: 60000,
        })
        queue.shift()
        sent.value += 1
        pending.value = queue.length
        retrying.value = false
        delay = 2000
      } catch (e) {
        // 409 : la reunion n'est plus en enregistrement (terminee ou supprimee ailleurs).
        if (e?.response?.status === 409 || e?.response?.status === 404) {
          queue.length = 0
          pending.value = 0
          error.value = "Cette reunion n'accepte plus d'audio (terminee ou supprimee)."
          break
        }
        // Reseau coupe, serveur indisponible : on garde le morceau et on insiste.
        retrying.value = true
        await sleep(delay)
        delay = Math.min(delay * 2, MAX_RETRY_DELAY)
      }
    }
    pumping = false
  }

  const waitForDrain = async () => {
    while ((queue.length || pumping) && !cancelled) await sleep(300)
  }

  // --- Capture ---------------------------------------------------------------

  const analyserFor = (stream) => {
    const analyser = audioCtx.createAnalyser()
    analyser.fftSize = 1024
    audioCtx.createMediaStreamSource(stream).connect(analyser)
    return analyser
  }

  const levelOf = (analyser) => {
    if (!analyser) return 0
    const data = new Uint8Array(analyser.fftSize)
    analyser.getByteTimeDomainData(data)
    let sum = 0
    for (const value of data) sum += ((value - 128) / 128) ** 2
    return Math.min(1, Math.sqrt(sum / data.length) * 4)
  }

  const meter = () => {
    micLevel.value = levelOf(analysers.mic)
    tabLevel.value = levelOf(analysers.tab)
    rafId = requestAnimationFrame(meter)
  }

  // Le partage d'onglet exige un geste de l'utilisateur tout frais : il passe en premier,
  // avant tout await (le micro est en general deja autorise).
  const acquire = async () => {
    let tabStream = null
    if (mode === 'visio') {
      const display = await navigator.mediaDevices.getDisplayMedia({
        video: true,
        audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false, suppressLocalAudioPlayback: false },
        systemAudio: 'include',
        selfBrowserSurface: 'exclude',
        preferCurrentTab: false,
      })
      streams.push(display)
      const tabTracks = display.getAudioTracks()
      if (!tabTracks.length) throw new TabAudioMissing()
      // « Arreter le partage » dans la barre de Chrome : fin de la partie.
      display.getTracks().forEach((track) => track.addEventListener('ended', () => interrupt('Partage de l\'onglet arrete.')))
      tabStream = new MediaStream(tabTracks)
    }

    const mic = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
    })
    streams.push(mic)
    mic.getAudioTracks().forEach((track) => track.addEventListener('ended', () => interrupt('Le micro a ete coupe.')))

    const Context = window.AudioContext || window.webkitAudioContext
    audioCtx = new Context()
    await audioCtx.resume?.()
    analysers.mic = analyserFor(mic)
    if (!tabStream) return mic

    analysers.tab = analyserFor(tabStream)
    const destination = audioCtx.createMediaStreamDestination()
    audioCtx.createMediaStreamSource(mic).connect(destination)
    audioCtx.createMediaStreamSource(tabStream).connect(destination)
    return destination.stream
  }

  const releaseMedia = () => {
    cancelAnimationFrame(rafId)
    clearInterval(ticker)
    streams.forEach((stream) => stream.getTracks().forEach((track) => track.stop()))
    streams = []
    analysers = {}
    audioCtx?.close?.()
    audioCtx = null
    micLevel.value = 0
    tabLevel.value = 0
    releaseWakeLock()
  }

  // --- Ecran allume ------------------------------------------------------------

  const requestWakeLock = async () => {
    try {
      wakeLock = await navigator.wakeLock?.request('screen')
      wakeLockActive.value = !!wakeLock
      wakeLock?.addEventListener('release', () => { wakeLockActive.value = false })
    } catch {
      wakeLockActive.value = false
    }
  }

  const releaseWakeLock = () => {
    wakeLock?.release?.().catch(() => {})
    wakeLock = null
    wakeLockActive.value = false
  }

  // Retour sur la page : le verrou d'ecran est perdu a chaque masquage, et iOS a pu
  // couper l'enregistreur pendant que la page etait en arriere-plan.
  const onVisibility = () => {
    if (document.visibilityState !== 'visible' || state.value !== 'recording') return
    if (recorder?.state !== 'recording') interrupt("L'enregistrement s'est arrete pendant que la page etait masquee.")
    else requestWakeLock()
  }

  // --- Cycle de vie -------------------------------------------------------------

  // ensureMeeting : cree la reunion si besoin, APRES l'acquisition (geste utilisateur).
  const start = async ({ mode: requestedMode, ensureMeeting, part: requestedPart = 1, alreadyRecorded = 0 }) => {
    if (state.value === 'starting' || state.value === 'recording') return
    mode = requestedMode
    error.value = null
    notice.value = null
    cancelled = false
    state.value = 'starting'
    try {
      const stream = await acquire()
      meetingId = await ensureMeeting()
      part = requestedPart
      seq = 0
      const mimeType = pickMimeType()
      recorder = new MediaRecorder(stream, { ...(mimeType ? { mimeType } : {}), audioBitsPerSecond: BITRATE })
      recorder.ondataavailable = (event) => {
        if (event.data?.size && !cancelled) enqueue(event.data)
      }
      recorder.onerror = () => interrupt("L'enregistreur du navigateur s'est arrete.")
      recorder.onstop = () => onRecorderStop?.()
      recorder.start(CHUNK_MS)

      baseSeconds = alreadyRecorded
      startedAt = Date.now()
      elapsed.value = baseSeconds
      ticker = setInterval(() => { elapsed.value = baseSeconds + Math.floor((Date.now() - startedAt) / 1000) }, 1000)
      rafId = requestAnimationFrame(meter)
      requestWakeLock()
      document.addEventListener('visibilitychange', onVisibility)
      state.value = 'recording'
      return meetingId
    } catch (e) {
      releaseMedia()
      recorder = null
      state.value = 'error'
      error.value = describe(e)
      return null
    }
  }

  // Arrete l'enregistreur et attend sa derniere tranche.
  const stopRecorder = () =>
    new Promise((resolve) => {
      if (!recorder || recorder.state === 'inactive') return resolve()
      onRecorderStop = resolve
      recorder.stop()
    })

  const interrupt = async (message) => {
    if (state.value !== 'recording') return
    state.value = 'interrupted'
    notice.value = message
    document.removeEventListener('visibilitychange', onVisibility)
    await stopRecorder()
    recorder = null
    baseSeconds = elapsed.value
    releaseMedia()
  }

  // Terminer : derniere tranche, envoi de tout ce qui reste, puis lancement du traitement.
  const finish = async () => {
    if (!['recording', 'interrupted', 'error'].includes(state.value)) return null
    state.value = 'stopping'
    document.removeEventListener('visibilitychange', onVisibility)
    await stopRecorder()
    recorder = null
    releaseMedia()
    await waitForDrain()
    try {
      const { data } = await apiClient.post(`/meetings/${meetingId}/finish`)
      state.value = 'finished'
      return data
    } catch (e) {
      state.value = 'interrupted'
      error.value = describe(e)
      return null
    }
  }

  // Annuler : on coupe tout sans rien envoyer de plus ; la suppression est faite par la page.
  const cancel = async () => {
    cancelled = true
    queue.length = 0
    pending.value = 0
    document.removeEventListener('visibilitychange', onVisibility)
    await stopRecorder()
    recorder = null
    releaseMedia()
    state.value = 'idle'
  }

  const isActive = () => ['starting', 'recording', 'stopping'].includes(state.value)

  onBeforeUnmount(() => {
    document.removeEventListener('visibilitychange', onVisibility)
    if (recorder && recorder.state !== 'inactive') recorder.stop()
    releaseMedia()
  })

  return {
    state, error, notice, elapsed, micLevel, tabLevel, sent, pending, retrying, wakeLockActive,
    start, finish, cancel, isActive, currentPart: () => part,
  }
}
