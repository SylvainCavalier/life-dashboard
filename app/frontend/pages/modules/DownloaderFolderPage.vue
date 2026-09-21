<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <!-- Retour -->
      <router-link to="/downloader" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au Downloader</router-link>

      <!-- Header -->
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">{{ folder?.name || '...' }}</h1>
        <p class="text-sm text-gray-500 mt-1">{{ completed.length }} fichier{{ completed.length > 1 ? 's' : '' }}</p>
      </div>

      <div v-if="loading" class="text-center text-gray-400 py-12 bg-white rounded-xl shadow-sm">Chargement...</div>
      <div v-else-if="!completed.length" class="text-center text-gray-400 py-12 bg-white rounded-xl shadow-sm">
        Aucun telechargement termine dans ce dossier
      </div>

      <div v-else class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5">
        <button
          v-for="download in completed"
          :key="download.id"
          class="text-left bg-white rounded-xl shadow-sm overflow-hidden hover:shadow-md hover:-translate-y-0.5 transition-all"
          @click="active = download"
        >
          <div class="aspect-video bg-gray-900 flex items-center justify-center overflow-hidden">
            <img
              v-if="download.thumbnail_url"
              :src="download.thumbnail_url"
              :alt="download.title"
              class="w-full h-full object-cover"
              loading="lazy"
            />
            <span v-else class="text-gray-500 text-xs">Pas d'apercu</span>
          </div>
          <div class="p-4">
            <div class="font-medium text-gray-900 line-clamp-2">{{ download.title || download.url }}</div>
            <div class="text-xs text-gray-400 mt-1">
              {{ download.format.toUpperCase() }}
              <span v-if="download.duration"> &middot; {{ formatDuration(download.duration) }}</span>
              <span v-if="download.file_size"> &middot; {{ formatSize(download.file_size) }}</span>
            </div>
            <p v-if="download.description" class="text-xs text-gray-500 mt-2 line-clamp-3 whitespace-pre-line">
              {{ download.description }}
            </p>
          </div>
        </button>
      </div>
    </div>

    <!-- Lecteur -->
    <div
      v-if="active"
      class="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4"
      @click.self="active = null"
    >
      <div class="bg-gray-900 rounded-xl w-full max-w-4xl overflow-hidden shadow-2xl">
        <div class="flex items-center justify-between gap-4 px-4 py-3 text-white">
          <div class="font-medium truncate">{{ active.title || active.url }}</div>
          <div class="flex items-center gap-4 flex-shrink-0">
            <a :href="active.file_url" class="text-sm text-gray-300 hover:text-white">Recuperer</a>
            <button class="text-gray-300 hover:text-white text-xl leading-none" @click="active = null">&times;</button>
          </div>
        </div>

        <video
          v-if="active.format === 'mp4'"
          :src="inlineUrl(active)"
          controls
          autoplay
          class="w-full bg-black aspect-video"
        />
        <div v-else class="p-6 flex flex-col items-center gap-4 bg-black">
          <img v-if="active.thumbnail_url" :src="active.thumbnail_url" :alt="active.title" class="max-h-60 rounded" />
          <audio :src="inlineUrl(active)" controls autoplay class="w-full" />
        </div>

        <div v-if="active.description" class="px-4 py-3 text-sm text-gray-300 max-h-40 overflow-y-auto whitespace-pre-line">
          {{ active.description }}
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRoute } from 'vue-router'
import { useApi } from '../../composables/useApi'
import { useVideoDownloads, formatSize, formatDuration } from '../../composables/useVideoDownloads'

const route = useRoute()
const { useCrud } = useApi()
const { downloads, fetchAll } = useVideoDownloads({ video_folder_id: route.params.id })

const folder = ref(null)
const loading = ref(true)
const active = ref(null)

const completed = computed(() => downloads.value.filter((d) => d.status === 'completed' && d.file_available))

// Le lecteur demande le fichier en `inline` ; le lien "Recuperer" garde `attachment`.
const inlineUrl = (download) => `${download.file_url}?disposition=inline`

const onKey = (event) => {
  if (event.key === 'Escape') active.value = null
}

onMounted(async () => {
  window.addEventListener('keydown', onKey)
  try {
    const [folderData] = await Promise.all([useCrud('video_folders').show(route.params.id), fetchAll()])
    folder.value = folderData
  } finally {
    loading.value = false
  }
})

onUnmounted(() => window.removeEventListener('keydown', onKey))
</script>
