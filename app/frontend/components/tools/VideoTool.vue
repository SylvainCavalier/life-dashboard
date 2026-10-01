<template>
  <div>
    <!-- Seul outil de la page qui passe par le serveur : Voxtral et Claude ne tournent pas dans le navigateur -->
    <div v-if="availability && !availability.transcription" class="bg-amber-50 border border-amber-100 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
      Transcription indisponible : la clé <code>MISTRAL_API_KEY</code> n'est pas configurée sur ce serveur.
    </div>
    <div v-else-if="availability && !availability.summary" class="bg-amber-50 border border-amber-100 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
      Résumé indisponible : la clé <code>ANTHROPIC_API_KEY</code> n'est pas configurée. Seule la transcription sera faite.
    </div>

    <!-- Choix de la source -->
    <div class="flex flex-wrap gap-2 mb-4">
      <button
        v-for="m in MODES"
        :key="m.key"
        class="text-sm px-4 py-2 rounded-lg transition-colors"
        :class="mode === m.key ? 'bg-gray-900 text-white' : 'bg-white text-gray-600 shadow-sm hover:bg-gray-100'"
        @click="switchMode(m.key)"
      >
        <span class="mr-1">{{ m.icon }}</span>{{ m.label }}
      </button>
    </div>

    <!-- Import d'une video -->
    <template v-if="mode === 'upload'">
      <FileDropZone
        v-if="!file"
        class="mb-6"
        accept="video/*,audio/*"
        icon="🎬"
        label="Cliquez ou glissez une vidéo ici"
        :hint="`mp4, mov, webm, mkv... (ou un fichier audio). ${maxSizeLabel} maximum.`"
        note="La vidéo est envoyée au serveur pour être transcrite, puis supprimée dès que la transcription est faite."
        @file="pickFile"
      />
      <p v-if="!file && formError" class="text-sm text-red-600 mt-2 mb-4">{{ formError }}</p>

      <div v-if="file" class="bg-white rounded-xl shadow-sm p-5 mb-6">
        <div class="flex flex-col md:flex-row gap-5">
          <div class="md:w-80 flex-shrink-0">
            <video v-if="isVideo" :src="previewUrl" controls class="w-full rounded-lg bg-black max-h-56"></video>
            <audio v-else :src="previewUrl" controls class="w-full"></audio>
            <p class="text-xs text-gray-400 mt-2 truncate">{{ file.name }} · {{ humanSize(file.size) }}</p>
          </div>
          <div class="flex-1 min-w-0">
            <TranscriptOptions v-model:title="title" v-model:language="language" :languages="languages" />
          </div>
        </div>

        <div v-if="uploadProgress !== null" class="mt-4">
          <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
            <div class="h-full bg-gray-900 transition-all" :style="{ width: `${uploadProgress}%` }"></div>
          </div>
          <p class="text-xs text-gray-500 mt-1">Envoi de la vidéo : {{ uploadProgress }} %</p>
        </div>
        <p v-if="formError" class="text-sm text-red-600 mt-4">{{ formError }}</p>

        <div class="flex justify-end gap-2 mt-4">
          <button class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2" :disabled="submitting" @click="clearFile">Autre vidéo</button>
          <button
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
            :disabled="submitting || !title.trim() || availability?.transcription === false"
            @click="submitUpload"
          >
            {{ submitting ? 'Envoi...' : 'Transcrire' }}
          </button>
        </div>
      </div>
    </template>

    <!-- Video deja rangee par le Downloader -->
    <div v-else class="bg-white rounded-xl shadow-sm p-5 mb-6">
      <div class="flex items-center justify-between gap-3 mb-3">
        <p class="text-sm text-gray-600">Vidéos et pistes audio du Downloader dont le fichier est encore disponible.</p>
        <input v-model="sourceSearch" type="text" placeholder="Rechercher..." class="border rounded-lg px-3 py-1.5 text-sm w-40 sm:w-56" />
      </div>
      <p v-if="sourcesLoaded && !sources.length" class="text-sm text-gray-400 py-6 text-center">
        Aucun téléchargement disponible. <router-link to="/downloader" class="text-indigo-600 hover:underline">Aller au Downloader</router-link>
      </p>
      <div v-else class="max-h-72 overflow-y-auto divide-y border rounded-lg">
        <button
          v-for="source in filteredSources"
          :key="source.id"
          class="w-full text-left px-3 py-2 flex items-center justify-between gap-3 hover:bg-gray-50"
          :class="selectedSource?.id === source.id ? 'bg-indigo-50' : ''"
          @click="pickSource(source)"
        >
          <span class="min-w-0">
            <span class="block text-sm text-gray-900 truncate">{{ source.title || `Téléchargement #${source.id}` }}</span>
            <span class="block text-xs text-gray-400">
              {{ [source.platform, source.uploader, source.format, source.clip_label ? `extrait ${source.clip_label}` : null, source.duration ? formatDuration(source.duration) : null].filter(Boolean).join(' · ') }}
            </span>
          </span>
          <span class="text-xs text-gray-400 flex-shrink-0">{{ source.storage === 'cloud' ? 'Cloud' : 'Local' }}</span>
        </button>
      </div>

      <div v-if="selectedSource" class="mt-4">
        <TranscriptOptions v-model:title="title" v-model:language="language" :languages="languages" />
        <p v-if="formError" class="text-sm text-red-600 mt-4">{{ formError }}</p>
        <div class="flex justify-end mt-4">
          <button
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
            :disabled="submitting || !title.trim() || availability?.transcription === false"
            @click="submitDownload"
          >
            {{ submitting ? 'Lancement...' : 'Transcrire' }}
          </button>
        </div>
      </div>
    </div>

    <!-- Transcription ouverte -->
    <VideoTranscriptDetail
      v-if="openId"
      :key="openId"
      :id="openId"
      class="mb-6"
      @changed="fetchTranscripts"
      @close="openId = null"
      @deleted="onDeleted"
    />

    <!-- Historique -->
    <h2 class="text-sm font-semibold text-gray-900 mb-2">Historique</h2>
    <p v-if="loaded && !transcripts.length" class="text-sm text-gray-400 py-6 text-center">Aucune transcription pour l'instant</p>
    <div class="space-y-2">
      <button
        v-for="t in transcripts"
        :key="t.id"
        class="w-full text-left bg-white rounded-xl shadow-sm p-4 hover:shadow-md transition"
        :class="openId === t.id ? 'ring-2 ring-indigo-200' : ''"
        @click="openId = t.id"
      >
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <p class="font-medium text-gray-900 truncate">{{ t.title }}</p>
            <p class="text-xs text-gray-500 mt-0.5">
              {{ formatDateTime(t.created_at) }} · {{ t.source }} · {{ t.language_label }}
              <span v-if="t.duration_seconds"> · {{ formatDuration(t.duration_seconds) }}</span>
              <span v-if="t.document"> · dans les documents</span>
            </p>
          </div>
          <span :class="['flex-shrink-0 text-xs px-2 py-0.5 rounded-full', statusClass(t)]">{{ statusLabel(t) }}</span>
        </div>
        <p v-if="t.overview" class="text-sm text-gray-600 mt-2 line-clamp-2">{{ t.overview }}</p>
        <p v-else-if="t.status === 'failed'" class="text-sm text-red-600 mt-2 line-clamp-2">{{ t.error }}</p>
      </button>
    </div>
  </div>
</template>

<script setup>
// Onglet Videos : transcription (Voxtral, par intervenant) et resume (Claude) d'une video
// importee ou deja rangee par le Downloader. Seul outil de la page qui passe par le
// serveur. La video part en direct upload vers le bucket (pas de delai du routeur),
// puis la transcription est creee avec le signed_id ; la table fait foi pour l'etat.
import { ref, computed, onMounted, onBeforeUnmount, onActivated, onDeactivated } from 'vue'
import apiClient from '../../plugins/axios'
import { useDirectUpload } from '../../composables/useDirectUpload'
import FileDropZone from './FileDropZone.vue'
import TranscriptOptions from './video/TranscriptOptions.vue'
import VideoTranscriptDetail from './video/VideoTranscriptDetail.vue'
import { baseName, humanSize } from './files'
import { errorOf, formatDateTime, formatDuration, statusClass, statusLabel } from './video/videoTranscriptFormat'

const POLL_INTERVAL = 3000
const MODES = [
  { key: 'upload', label: 'Importer une vidéo', icon: '⬆️' },
  { key: 'downloader', label: 'Depuis le Downloader', icon: '📥' },
]

const { uploadFile } = useDirectUpload()

const availability = ref(null)
const mode = ref('upload')
const file = ref(null)
const previewUrl = ref(null)
const title = ref('')
const language = ref('auto')
const submitting = ref(false)
const uploadProgress = ref(null)
const formError = ref(null)

const sources = ref([])
const sourcesLoaded = ref(false)
const sourceSearch = ref('')
const selectedSource = ref(null)

const transcripts = ref([])
const loaded = ref(false)
const openId = ref(null)
let timer = null
let active = true

const languages = computed(() => availability.value?.languages || [{ code: 'auto', label: 'Détection automatique' }])
const isVideo = computed(() => file.value?.type?.startsWith('video/'))
const maxSizeLabel = computed(() => (availability.value ? humanSize(availability.value.max_bytes) : '2 Go'))

const filteredSources = computed(() => {
  const q = sourceSearch.value.trim().toLowerCase()
  if (!q) return sources.value
  return sources.value.filter((s) => [s.title, s.uploader, s.platform].some((v) => v?.toLowerCase().includes(q)))
})

const fetchTranscripts = async () => {
  const { data } = await apiClient.get('/video_transcripts')
  transcripts.value = data
  loaded.value = true
  schedule()
}

// Sondage de la liste tant qu'un traitement tourne (le detail ouvert a le sien).
const schedule = () => {
  clearTimeout(timer)
  if (active && transcripts.value.some((t) => t.in_progress)) timer = setTimeout(fetchTranscripts, POLL_INTERVAL)
}

const fetchSources = async () => {
  const { data } = await apiClient.get('/video_transcripts/sources')
  sources.value = data
  sourcesLoaded.value = true
}

const switchMode = (key) => {
  mode.value = key
  formError.value = null
  if (key === 'downloader' && !sourcesLoaded.value) fetchSources()
}

const pickFile = (picked) => {
  if (availability.value && picked.size > availability.value.max_bytes) {
    formError.value = `Fichier trop volumineux (${humanSize(picked.size)}), ${maxSizeLabel.value} maximum.`
    return
  }
  clearFile()
  file.value = picked
  previewUrl.value = URL.createObjectURL(picked)
  title.value = baseName(picked.name)
}

const clearFile = () => {
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
  file.value = null
  previewUrl.value = null
  formError.value = null
  uploadProgress.value = null
}

const pickSource = (source) => {
  selectedSource.value = source
  title.value = source.title || `Téléchargement #${source.id}`
  formError.value = null
}

const started = (data) => {
  transcripts.value = [data, ...transcripts.value.filter((t) => t.id !== data.id)]
  openId.value = data.id
  schedule()
}

const submitUpload = async () => {
  if (!file.value || !title.value.trim()) return
  submitting.value = true
  formError.value = null
  try {
    uploadProgress.value = 0
    const blob = await uploadFile(file.value, (p) => { uploadProgress.value = p })
    const { data } = await apiClient.post('/video_transcripts', {
      video_transcript: { title: title.value, language: language.value },
      video: blob.signed_id,
    })
    clearFile()
    started(data)
  } catch (e) {
    formError.value = errorOf(e, "L'envoi a échoué.")
  } finally {
    submitting.value = false
    uploadProgress.value = null
  }
}

const submitDownload = async () => {
  if (!selectedSource.value || !title.value.trim()) return
  submitting.value = true
  formError.value = null
  try {
    const { data } = await apiClient.post('/video_transcripts', {
      video_transcript: { title: title.value, language: language.value },
      video_download_id: selectedSource.value.id,
    })
    selectedSource.value = null
    started(data)
  } catch (e) {
    formError.value = errorOf(e, 'Le lancement a échoué.')
  } finally {
    submitting.value = false
  }
}

const onDeleted = (id) => {
  openId.value = null
  transcripts.value = transcripts.value.filter((t) => t.id !== id)
}

onMounted(async () => {
  fetchTranscripts()
  try {
    availability.value = (await apiClient.get('/video_transcripts/availability')).data
  } catch {
    // Sans cette information, l'outil reste utilisable : le serveur refusera s'il le faut.
  }
})

// Onglet garde en vie par KeepAlive : pas de sondage quand il n'est pas affiche.
onActivated(() => { active = true; if (loaded.value) fetchTranscripts() })
onDeactivated(() => { active = false; clearTimeout(timer) })
onBeforeUnmount(() => {
  clearTimeout(timer)
  if (previewUrl.value) URL.revokeObjectURL(previewUrl.value)
})
</script>
