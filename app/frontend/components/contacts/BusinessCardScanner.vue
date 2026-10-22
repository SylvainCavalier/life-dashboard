<template>
  <div class="fixed inset-0 z-50 flex flex-col bg-black text-white" role="dialog" aria-modal="true">
    <div class="flex items-center justify-between px-4 py-3" style="padding-top: max(0.75rem, env(safe-area-inset-top))">
      <h2 class="text-base font-semibold">Scan carte de visite</h2>
      <button type="button" class="p-2 -mr-2 text-white/80 hover:text-white" title="Fermer" @click="close">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>

    <!-- Viseur / photo prise -->
    <div class="relative flex-1 overflow-hidden flex items-center justify-center">
      <!-- playsinline + muted : sans eux, iOS ouvre le lecteur plein ecran ou refuse l'autoplay -->
      <video
        v-show="!snapshot"
        ref="videoEl"
        class="absolute inset-0 w-full h-full object-cover"
        autoplay
        muted
        playsinline
      ></video>
      <img v-if="snapshot" :src="snapshot" alt="Carte de visite" class="absolute inset-0 w-full h-full object-contain" />

      <!-- Cadre au format carte de visite (85 x 55 mm) -->
      <div
        v-if="state === 'live'"
        class="relative w-[88%] max-w-xl aspect-[85/55] rounded-xl border-2 border-white/90 pointer-events-none"
        style="box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.45)"
      ></div>

      <div v-if="state === 'starting'" class="relative text-sm text-white/70">Ouverture de la caméra...</div>

      <div v-if="state === 'scanning'" class="relative flex flex-col items-center gap-3 bg-black/60 rounded-xl px-6 py-5">
        <svg class="w-8 h-8 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
        </svg>
        <span class="text-sm">Lecture de la carte...</span>
      </div>

      <div v-if="state === 'nocamera'" class="relative max-w-sm px-6 text-center text-sm text-white/80 space-y-2">
        <p>{{ cameraError }}</p>
        <p class="text-white/60">Vous pouvez prendre la photo avec l'appareil, ou en choisir une existante.</p>
      </div>
    </div>

    <p v-if="error" class="mx-4 mb-2 rounded-lg bg-red-500/90 px-3 py-2 text-sm">{{ error }}</p>
    <p v-else-if="state === 'live'" class="px-4 pb-2 text-center text-xs text-white/60">
      Placez la carte dans le cadre, bien à plat et éclairée.
    </p>

    <!-- Commandes -->
    <div class="flex items-center justify-center gap-6 px-4 pt-3" style="padding-bottom: max(1.25rem, env(safe-area-inset-bottom))">
      <button
        type="button"
        class="text-sm text-white/80 hover:text-white disabled:opacity-40"
        :disabled="state === 'scanning'"
        @click="fileInput.click()"
      >
        {{ state === 'nocamera' ? 'Prendre / choisir une photo' : 'Importer' }}
      </button>

      <button
        v-if="state === 'live'"
        type="button"
        class="w-16 h-16 rounded-full border-4 border-white bg-white/20 active:bg-white/60"
        title="Capturer"
        @click="capture"
      ></button>

      <button
        v-if="snapshot && state !== 'scanning'"
        type="button"
        class="bg-white text-gray-900 px-4 py-2 rounded-lg text-sm font-medium"
        @click="retake"
      >
        Reprendre
      </button>

      <input ref="fileInput" type="file" accept="image/*" class="hidden" @change="onFile" />
    </div>
  </div>
</template>

<script setup>
// Viseur dans la page (getUserMedia) plutot que l'appareil photo de l'iPhone : dans la
// webapp installee sur l'ecran d'accueil, on reste dans l'application et sa session
// (meme lecon que la skill qr-scanner-web). Le champ fichier sert de repli : pas de
// camera, permission refusee, ou photo deja prise.
// La photo est reduite et reencodee en JPEG dans le navigateur avant envoi (HEIC de
// l'iPhone, photos de 12 Mpx) ; le serveur la passe a Mistral et ne garde rien.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import apiClient from '../../plugins/axios'

const emit = defineEmits(['scanned', 'close'])

// Assez pour l'OCR des petits caracteres d'une carte, sans alourdir l'envoi.
const MAX_SIDE = 2000

const videoEl = ref(null)
const fileInput = ref(null)
// starting | live | nocamera | captured | scanning
const state = ref('starting')
const snapshot = ref(null)
const error = ref(null)
const cameraError = ref('')

let stream = null

const stopCamera = () => {
  stream?.getTracks().forEach((track) => track.stop())
  stream = null
}

const cameraMessage = (e) => {
  if (!window.isSecureContext) return 'La caméra exige une connexion HTTPS.'
  if (e?.name === 'NotAllowedError') {
    return 'Accès à la caméra refusé. Sur iPhone : Réglages > Safari > Caméra (ou réglages de la webapp), puis rouvrez le scan.'
  }
  if (e?.name === 'NotFoundError' || e?.name === 'OverconstrainedError') return 'Aucune caméra détectée.'
  return "Impossible d'ouvrir la caméra."
}

const startCamera = async () => {
  error.value = null
  snapshot.value = null
  if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
    cameraError.value = cameraMessage()
    state.value = 'nocamera'
    return
  }
  state.value = 'starting'
  try {
    // Sans resolution demandee, Safari iOS livre du 640x480 : illisible pour l'OCR.
    stream = await navigator.mediaDevices.getUserMedia({
      audio: false,
      video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } },
    })
    videoEl.value.srcObject = stream
    await videoEl.value.play().catch(() => {})
    state.value = 'live'
  } catch (e) {
    stopCamera()
    cameraError.value = cameraMessage(e)
    state.value = 'nocamera'
  }
}

// Dessine une source (video ou image) dans un canvas reduit a MAX_SIDE, renvoie un JPEG.
const toJpeg = (source, width, height) => {
  const scale = Math.min(1, MAX_SIDE / Math.max(width, height))
  const canvas = document.createElement('canvas')
  canvas.width = Math.round(width * scale)
  canvas.height = Math.round(height * scale)
  canvas.getContext('2d').drawImage(source, 0, 0, canvas.width, canvas.height)
  // data: et non blob: pour l'apercu : la CSP (img_src) n'autorise pas blob:.
  const preview = canvas.toDataURL('image/jpeg', 0.9)
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => (blob ? resolve({ blob, preview }) : reject(new Error('encodage'))), 'image/jpeg', 0.9)
  })
}

const capture = async () => {
  const video = videoEl.value
  if (!video?.videoWidth) return
  const { blob, preview } = await toJpeg(video, video.videoWidth, video.videoHeight)
  snapshot.value = preview
  stopCamera()
  await scan(blob)
}

const loadImage = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => {
      const img = new window.Image()
      img.onload = () => resolve(img)
      img.onerror = reject
      img.src = reader.result
    }
    reader.onerror = reject
    reader.readAsDataURL(file)
  })

const onFile = async (event) => {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  error.value = null
  try {
    const img = await loadImage(file)
    const { blob, preview } = await toJpeg(img, img.naturalWidth, img.naturalHeight)
    snapshot.value = preview
    stopCamera()
    await scan(blob)
  } catch {
    error.value = "Cette image n'a pas pu être ouverte."
  }
}

const scanError = (e) => {
  if (e?.response?.status === 429) return "Trop de scans d'affilée, patientez une minute."
  if (e?.code === 'ECONNABORTED') return 'La lecture a pris trop de temps, réessayez.'
  return e?.response?.data?.error || 'La lecture de la carte a échoué.'
}

const scan = async (blob) => {
  state.value = 'scanning'
  error.value = null
  const form = new FormData()
  form.append('image', blob, 'carte.jpg')
  try {
    // Content-Type explicite : avec l'en-tete JSON par defaut, axios serialiserait le FormData en JSON.
    const { data } = await apiClient.post('/business_card_scans', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
      timeout: 40000,
    })
    emit('scanned', data.contact)
  } catch (e) {
    error.value = scanError(e)
    state.value = 'captured'
  }
}

const retake = () => startCamera()

const close = () => {
  stopCamera()
  emit('close')
}

onMounted(startCamera)
onBeforeUnmount(stopCamera)
</script>
