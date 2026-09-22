// Module Downloader : etat des telechargements, sondage tant qu'un job tourne,
// et helpers d'affichage partages entre la page principale et la page dossier.
import { ref, computed, onUnmounted } from 'vue'
import { useApi } from './useApi'

// Le job met a jour la table, l'interface la relit. 3 s : assez reactif, et
// loin du plafond Rack::Attack (100 requetes API par minute).
const POLL_INTERVAL = 3000

export const formatOptions = [
  { value: 'mp4', label: 'Video (MP4)' },
  { value: 'mp3', label: 'Audio (MP3)' },
]

export const qualityOptions = [
  { value: 'original', label: 'Originale (jusqu\'a 1080p)' },
  { value: '720p', label: 'Reduite (720p)' },
]

export const storageOptions = [
  { value: 'local', label: 'Telechargement local' },
  { value: 'cloud', label: 'Cloud OVH' },
]

export const statusLabel = (status) => ({
  pending: 'En attente',
  processing: 'En cours',
  completed: 'Termine',
  failed: 'Echec',
}[status] || status)

export const statusBadge = (status) => ({
  pending: 'bg-gray-100 text-gray-600',
  processing: 'bg-blue-100 text-blue-700',
  completed: 'bg-green-100 text-green-700',
  failed: 'bg-red-100 text-red-700',
}[status] || 'bg-gray-100 text-gray-500')

// Plateforme d'origine, deduite de l'URL (yt-dlp gere bien d'autres sites :
// ceux-ci sont simplement ceux que l'on etiquette).
const sources = [
  { label: 'YouTube', hosts: ['youtube.com', 'youtu.be'], badge: 'bg-red-50 text-red-700' },
  { label: 'Dailymotion', hosts: ['dailymotion.com', 'dai.ly'], badge: 'bg-sky-50 text-sky-700' },
  { label: 'X / Twitter', hosts: ['twitter.com', 'x.com'], badge: 'bg-gray-900 text-white' },
  { label: 'Crowdbunker', hosts: ['crowdbunker.com'], badge: 'bg-amber-50 text-amber-800' },
]

export const sourceOf = (url) => {
  let host = ''
  try {
    host = new URL(url).hostname.replace(/^(www|m|mobile)\./, '')
  } catch {
    return null
  }
  const known = sources.find((source) => source.hosts.some((h) => host === h || host.endsWith(`.${h}`)))
  return known || { label: host, badge: 'bg-gray-100 text-gray-600' }
}

export const formatDate = (value) => (value ? new Date(value).toLocaleDateString('fr-FR') : null)

export const formatCount = (value) =>
  (value === null || value === undefined ? null : new Intl.NumberFormat('fr-FR').format(value))

export const formatSize = (bytes) => {
  if (!bytes) return '0 o'
  const units = ['o', 'Ko', 'Mo', 'Go']
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1)} ${units[i]}`
}

export const formatDuration = (seconds) => {
  const s = Math.round(seconds)
  const h = Math.floor(s / 3600)
  const m = Math.floor((s % 3600) / 60)
  const sec = s % 60
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`
  return `${m}:${String(sec).padStart(2, '0')}`
}

export function useVideoDownloads(params = {}) {
  // useApi expose la suppression sous `delete` (mot reserve : on la renomme ici)
  const { get, post, delete: del } = useApi()

  const downloads = ref([])
  const loading = ref(false)
  let pollTimer = null
  let stopped = false

  const hasActive = computed(() =>
    downloads.value.some((d) => d.status === 'pending' || d.status === 'processing')
  )

  const load = async () => {
    downloads.value = await get('/video_downloads', { params })
  }

  const fetchAll = async () => {
    loading.value = true
    try {
      await load()
    } finally {
      loading.value = false
    }
    schedulePoll()
  }

  const createDownload = async (payload) => {
    const download = await post('/video_downloads', { video_download: payload })
    downloads.value.unshift(download)
    schedulePoll()
    return download
  }

  const destroyDownload = async (id) => {
    await del(`/video_downloads/${id}`)
    downloads.value = downloads.value.filter((d) => d.id !== id)
  }

  function schedulePoll() {
    clearTimeout(pollTimer)
    if (stopped || !hasActive.value) return

    pollTimer = setTimeout(async () => {
      try {
        await load()
      } catch {
        // Une erreur de sondage ne doit pas interrompre le suivi : on retente au prochain tour
      }
      schedulePoll()
    }, POLL_INTERVAL)
  }

  onUnmounted(() => {
    stopped = true
    clearTimeout(pollTimer)
  })

  return { downloads, loading, hasActive, fetchAll, createDownload, destroyDownload }
}
