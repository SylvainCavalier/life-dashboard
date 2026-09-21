<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-4xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Downloader</h1>
        <p class="text-sm text-gray-500 mt-1">
          Collez l'URL d'une video (YouTube, Dailymotion, X / Twitter, Crowdbunker...), choisissez le format : le fichier est recupere en local ou range sur le cloud OVH.
        </p>
      </div>

      <!-- yt-dlp / ffmpeg absents ou casses sur cet hote -->
      <div v-if="unavailable" class="bg-amber-50 border-2 border-amber-200 rounded-xl p-5 mb-6">
        <p class="text-sm font-medium text-amber-900">Module indisponible sur ce serveur</p>
        <p class="text-sm text-amber-800 mt-1">
          Binaire{{ missingBinaries.length > 1 ? 's' : '' }} absent{{ missingBinaries.length > 1 ? 's' : '' }} ou inutilisable{{ missingBinaries.length > 1 ? 's' : '' }} :
          <span class="font-mono">{{ missingBinaries.join(', ') }}</span>.
          Les telechargements lances ici echoueront.
        </p>
      </div>

      <!-- Nouveau telechargement -->
      <form class="bg-white rounded-xl shadow-sm p-6 mb-6" @submit.prevent="submit">
        <label class="block text-sm font-medium text-gray-700 mb-1">URL de la video</label>
        <input
          v-model="form.url"
          type="url"
          required
          placeholder="https://www.youtube.com/watch?v=...  ou  https://x.com/compte/status/..."
          class="w-full border rounded-lg px-3 py-2 text-sm mb-4"
        />

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Format</label>
            <select v-model="form.format" class="w-full border rounded-lg px-3 py-2 text-sm bg-white">
              <option v-for="option in formatOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
            </select>
          </div>

          <div v-if="form.format === 'mp4'">
            <label class="block text-sm font-medium text-gray-700 mb-1">Qualite</label>
            <select v-model="form.quality" class="w-full border rounded-lg px-3 py-2 text-sm bg-white">
              <option v-for="option in qualityOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
            </select>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Stockage</label>
            <select v-model="form.storage" class="w-full border rounded-lg px-3 py-2 text-sm bg-white">
              <option v-for="option in storageOptions" :key="option.value" :value="option.value">{{ option.label }}</option>
            </select>
          </div>
        </div>

        <div v-if="form.storage === 'cloud'" class="mt-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Dossier (optionnel)</label>
          <select v-model="form.video_folder_id" class="w-full border rounded-lg px-3 py-2 text-sm bg-white">
            <option :value="null">Aucun dossier</option>
            <option v-for="folder in folders" :key="folder.id" :value="folder.id">{{ folder.name }}</option>
          </select>
        </div>

        <p v-if="submitError" class="text-sm text-red-500 mt-3">{{ submitError }}</p>

        <div class="flex justify-end mt-4">
          <button
            type="submit"
            :disabled="submitting"
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
          >
            {{ submitting ? 'Mise en file...' : 'Telecharger' }}
          </button>
        </div>
      </form>

      <!-- Historique -->
      <div class="flex items-center justify-between mb-3">
        <h2 class="text-lg font-semibold text-gray-900">Historique</h2>
        <span v-if="hasActive" class="text-xs text-blue-600 animate-pulse">Telechargement en cours...</span>
      </div>

      <div v-if="loading && !downloads.length" class="text-center text-gray-400 py-12 bg-white rounded-xl shadow-sm">
        Chargement...
      </div>
      <div v-else-if="!downloads.length" class="text-center text-gray-400 py-12 bg-white rounded-xl shadow-sm">
        Aucun telechargement
      </div>

      <div v-else class="space-y-3 mb-8">
        <div v-for="download in downloads" :key="download.id" class="bg-white rounded-xl shadow-sm p-5">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <h3 class="font-medium text-gray-900 truncate">{{ download.title || download.url }}</h3>
              <p class="text-xs text-gray-400 mt-1">
                <span
                  v-if="sourceOf(download.url)"
                  :class="['font-medium px-1.5 py-0.5 rounded mr-1', sourceOf(download.url).badge]"
                >{{ sourceOf(download.url).label }}</span>
                {{ download.format.toUpperCase() }}<span v-if="download.quality"> &middot; {{ download.quality }}</span>
                &middot; {{ download.storage === 'cloud' ? 'Cloud OVH' : 'Local' }}
                <span v-if="folderName(download)"> &middot; {{ folderName(download) }}</span>
                <span v-if="download.duration"> &middot; {{ formatDuration(download.duration) }}</span>
                <span v-if="download.file_size"> &middot; {{ formatSize(download.file_size) }}</span>
              </p>
              <!-- Source : de quoi citer la video -->
              <p v-if="download.uploader || download.published_at" class="text-xs text-gray-500 mt-1">
                <a
                  v-if="download.uploader && download.uploader_url"
                  :href="download.uploader_url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="font-medium hover:underline"
                >{{ download.uploader }}</a>
                <span v-else-if="download.uploader" class="font-medium">{{ download.uploader }}</span>
                <span v-if="download.published_at"> &middot; publie le {{ formatDate(download.published_at) }}</span>
                <span v-if="download.view_count !== null && download.view_count !== undefined">
                  &middot; {{ formatCount(download.view_count) }} vues au telechargement
                </span>
              </p>
              <p v-if="download.status === 'failed' && download.error_message" class="text-xs text-red-500 mt-2 break-words">
                {{ download.error_message }}
              </p>
              <p v-else-if="download.status === 'completed' && !download.file_available" class="text-xs text-gray-400 mt-2">
                Fichier local supprime du serveur
              </p>
            </div>

            <div class="flex items-center gap-2 flex-shrink-0">
              <span :class="['text-xs font-medium px-2 py-1 rounded', statusBadge(download.status)]">
                {{ statusLabel(download.status) }}
              </span>
              <button
                v-if="download.citation"
                class="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50 transition"
                title="Copier la reference de la source"
                @click="copyCitation(download)"
              >
                {{ copiedId === download.id ? 'Copie !' : 'Citer' }}
              </button>
              <a
                v-if="download.file_url"
                :href="download.file_url"
                class="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50 transition"
              >
                Recuperer
              </a>
              <button class="text-xs text-red-400 hover:text-red-600 px-2 py-1.5" @click="remove(download)">
                Supprimer
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Dossiers -->
      <h2 class="text-lg font-semibold text-gray-900 mb-3">Dossiers cloud</h2>

      <div class="bg-white rounded-xl shadow-sm p-5">
        <form class="flex gap-2" @submit.prevent="createFolder">
          <input
            v-model="newFolderName"
            type="text"
            required
            maxlength="100"
            placeholder="Nom du nouveau dossier"
            class="flex-1 border rounded-lg px-3 py-2 text-sm"
          />
          <button
            type="submit"
            :disabled="creatingFolder"
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
          >
            Ajouter
          </button>
        </form>
        <p v-if="folderError" class="text-sm text-red-500 mt-2">{{ folderError }}</p>

        <p v-if="!folders.length" class="text-sm text-gray-400 mt-4">Aucun dossier</p>
        <ul v-else class="divide-y divide-gray-100 mt-3">
          <li v-for="folder in folders" :key="folder.id" class="py-3 flex items-center gap-3">
            <input
              v-if="editingFolderId === folder.id"
              v-model="editFolderName"
              maxlength="100"
              class="flex-1 border rounded-lg px-2 py-1 text-sm"
              @keyup.enter="saveFolder(folder)"
              @keyup.esc="editingFolderId = null"
            />
            <router-link
              v-else
              :to="{ name: 'DownloaderFolder', params: { id: folder.id } }"
              class="flex-1 min-w-0 truncate text-sm font-medium text-gray-900 hover:underline"
            >
              {{ folder.name }}
            </router-link>
            <span class="text-xs text-gray-400 whitespace-nowrap">
              {{ folder.downloads_count }} fichier{{ folder.downloads_count > 1 ? 's' : '' }}
            </span>
            <button
              v-if="editingFolderId === folder.id"
              class="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50 transition"
              @click="saveFolder(folder)"
            >
              Enregistrer
            </button>
            <button
              v-else
              class="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50 transition"
              @click="startFolderEdit(folder)"
            >
              Renommer
            </button>
            <button class="text-xs text-red-400 hover:text-red-600 px-2 py-1.5" @click="removeFolder(folder)">
              Supprimer
            </button>
          </li>
        </ul>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import {
  useVideoDownloads, formatOptions, qualityOptions, storageOptions,
  statusLabel, statusBadge, formatSize, formatDuration, formatDate, formatCount, sourceOf,
} from '../../composables/useVideoDownloads'

const { get, useCrud } = useApi()
const folderApi = useCrud('video_folders')
const { downloads, loading, hasActive, fetchAll, createDownload, destroyDownload } = useVideoDownloads()

const folders = ref([])
const missingBinaries = ref([])
const unavailable = computed(() => missingBinaries.value.length > 0)

const submitting = ref(false)
const submitError = ref('')
const form = ref({
  url: '',
  format: 'mp4',
  quality: 'original',
  storage: 'local',
  video_folder_id: null,
})

const newFolderName = ref('')
const creatingFolder = ref(false)
const folderError = ref('')
const editingFolderId = ref(null)
const editFolderName = ref('')

const errorMessage = (error) =>
  error.response?.data?.errors?.join(', ') || error.response?.data?.error || error.message

const fetchFolders = async () => {
  folders.value = await folderApi.list()
}

const fetchAvailability = async () => {
  try {
    const availability = await get('/video_downloads/availability')
    missingBinaries.value = availability.missing_binaries || []
  } catch {
    // Sonde purement informative : son echec ne doit pas bloquer la page
  }
}

const folderName = (download) =>
  folders.value.find((folder) => folder.id === download.video_folder_id)?.name

const submit = async () => {
  submitting.value = true
  submitError.value = ''
  try {
    const payload = {
      url: form.value.url,
      format: form.value.format,
      storage: form.value.storage,
    }
    if (form.value.format === 'mp4') payload.quality = form.value.quality
    if (form.value.storage === 'cloud' && form.value.video_folder_id) {
      payload.video_folder_id = form.value.video_folder_id
    }

    await createDownload(payload)
    form.value.url = ''
    if (payload.video_folder_id) await fetchFolders()
  } catch (error) {
    submitError.value = errorMessage(error)
  } finally {
    submitting.value = false
  }
}

const copiedId = ref(null)

const copyCitation = async (download) => {
  try {
    await navigator.clipboard.writeText(download.citation)
    copiedId.value = download.id
    setTimeout(() => {
      if (copiedId.value === download.id) copiedId.value = null
    }, 2000)
  } catch {
    // Presse-papier indisponible (contexte non securise) : on affiche la reference a copier a la main
    window.prompt('Reference a copier :', download.citation)
  }
}

const remove = async (download) => {
  if (!confirm(`Supprimer "${download.title || download.url}" ? Le fichier sera supprime.`)) return

  await destroyDownload(download.id)
  if (download.video_folder_id) await fetchFolders()
}

const createFolder = async () => {
  creatingFolder.value = true
  folderError.value = ''
  try {
    await folderApi.create({ video_folder: { name: newFolderName.value } })
    newFolderName.value = ''
    await fetchFolders()
  } catch (error) {
    folderError.value = errorMessage(error)
  } finally {
    creatingFolder.value = false
  }
}

const startFolderEdit = (folder) => {
  editingFolderId.value = folder.id
  editFolderName.value = folder.name
  folderError.value = ''
}

const saveFolder = async (folder) => {
  try {
    await folderApi.update(folder.id, { video_folder: { name: editFolderName.value } })
    editingFolderId.value = null
    await fetchFolders()
  } catch (error) {
    folderError.value = errorMessage(error)
  }
}

const removeFolder = async (folder) => {
  if (!confirm(`Supprimer le dossier "${folder.name}" ? Ses fichiers sont conserves, sans dossier.`)) return

  await folderApi.destroy(folder.id)
  await Promise.all([fetchFolders(), fetchAll()])
}

onMounted(() => {
  fetchAll()
  fetchFolders()
  fetchAvailability()
})
</script>
