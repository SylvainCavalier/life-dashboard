// Dictee vocale : enregistrement par MediaRecorder (natif, sans librairie), puis
// transcription par Voxtral via POST /api/transcriptions. Chrome produit du
// webm/opus, Safari (Mac et iPhone) du mp4/aac : les deux passent tels quels.
// Le micro exige un contexte securise (HTTPS, ou localhost en developpement).
import { ref, computed, onBeforeUnmount } from 'vue'
import apiClient from '../plugins/axios'

// Par ordre de preference ; le premier que le navigateur sait produire l'emporte.
const MIME_TYPES = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4', 'audio/ogg;codecs=opus']
const EXTENSIONS = { 'audio/webm': 'webm', 'audio/mp4': 'm4a', 'audio/ogg': 'ogg' }
// En dessous, c'est un clic accidentel : on n'envoie rien.
const MIN_BYTES = 1000

export const voiceSupported = () =>
  typeof window !== 'undefined' &&
  window.isSecureContext &&
  !!navigator.mediaDevices?.getUserMedia &&
  typeof window.MediaRecorder !== 'undefined'

const pickMimeType = () => MIME_TYPES.find((type) => MediaRecorder.isTypeSupported?.(type)) || ''

// Transcription synchrone cote serveur, bornee sous le delai du routeur Heroku (30 s).
const transcribe = async (blob) => {
  const type = (blob.type || 'audio/webm').split(';')[0]
  const form = new FormData()
  form.append('audio', blob, `dictee.${EXTENSIONS[type] || 'webm'}`)
  // Content-Type explicite : avec l'en-tete JSON par defaut, axios serialiserait le FormData en JSON.
  const { data } = await apiClient.post('/transcriptions', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
    timeout: 45000,
  })
  return data.text || ''
}

const errorMessage = (e) => {
  if (e?.name === 'NotAllowedError') return 'Acces au micro refuse (reglages du navigateur).'
  if (e?.name === 'NotFoundError') return 'Aucun micro detecte.'
  if (e?.response?.status === 429) return 'Trop de dictees d\'affilee, patientez une minute.'
  return e?.response?.data?.error || 'La dictee a echoue.'
}

// state : idle | recording | transcribing
export function useVoiceRecorder({ maxSeconds = 300, onText } = {}) {
  const state = ref('idle')
  const elapsed = ref(0)
  const error = ref(null)

  let recorder = null
  let stream = null
  let chunks = []
  let ticker = null
  let cancelled = false

  const releaseMic = () => {
    clearInterval(ticker)
    ticker = null
    stream?.getTracks().forEach((track) => track.stop())
    stream = null
  }

  const finish = async () => {
    const blob = new Blob(chunks, { type: recorder?.mimeType || chunks[0]?.type || '' })
    chunks = []
    recorder = null
    releaseMic()
    if (cancelled || blob.size < MIN_BYTES) {
      state.value = 'idle'
      return
    }
    state.value = 'transcribing'
    try {
      const text = await transcribe(blob)
      if (text) onText?.(text)
      else error.value = 'Rien d\'audible dans l\'enregistrement.'
    } catch (e) {
      error.value = errorMessage(e)
    } finally {
      state.value = 'idle'
    }
  }

  const start = async () => {
    if (state.value !== 'idle') return
    error.value = null
    cancelled = false
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mimeType = pickMimeType()
      recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined)
      chunks = []
      recorder.ondataavailable = (event) => {
        if (event.data?.size) chunks.push(event.data)
      }
      recorder.onstop = finish
      recorder.start()
      state.value = 'recording'
      elapsed.value = 0
      ticker = setInterval(() => {
        elapsed.value += 1
        if (elapsed.value >= maxSeconds) stop()
      }, 1000)
    } catch (e) {
      releaseMic()
      recorder = null
      state.value = 'idle'
      error.value = errorMessage(e)
    }
  }

  const stop = () => {
    if (recorder?.state === 'recording') recorder.stop()
  }

  const cancel = () => {
    cancelled = true
    stop()
  }

  const toggle = () => (state.value === 'recording' ? stop() : start())

  const clock = computed(() => {
    const m = Math.floor(elapsed.value / 60)
    const s = String(elapsed.value % 60).padStart(2, '0')
    return `${m}:${s}`
  })

  // Quitter la page en pleine dictee : couper le micro sans rien envoyer.
  onBeforeUnmount(cancel)

  return { state, elapsed, clock, error, start, stop, cancel, toggle }
}

// Insere le texte dicte a la position du curseur d'un textarea (a la fin s'il n'a
// jamais eu le focus), avec les espaces qu'il faut de part et d'autre.
// Renvoie la nouvelle valeur ; le curseur est replace juste apres l'insertion.
export function insertAtCursor(el, value, text) {
  const current = value || ''
  const start = el ? el.selectionStart ?? current.length : current.length
  const end = el ? el.selectionEnd ?? current.length : current.length
  const before = current.slice(0, start)
  const after = current.slice(end)
  const lead = before && !/\s$/.test(before) ? ' ' : ''
  const trail = after && !/^[\s.,;:!?)]/.test(after) ? ' ' : ''
  const inserted = `${lead}${text}${trail}`
  if (el) {
    const caret = before.length + inserted.length
    requestAnimationFrame(() => {
      el.focus()
      el.setSelectionRange(caret, caret)
    })
  }
  return before + inserted + after
}
