// Module Sentinelle : helpers d'affichage partages entre la page des domaines
// et la page d'une semaine, et suivi d'un traitement en cours.
import { ref, computed, onUnmounted } from 'vue'
import { useApi } from './useApi'

// Le job met a jour la table, l'interface la relit. 3 s : assez reactif, et
// loin du plafond Rack::Attack (100 requetes API par minute).
const POLL_INTERVAL = 3000

export const importanceLabel = (value) => ({
  high: 'Majeur',
  medium: 'Notable',
  low: 'Mineur',
}[value] || 'Non évalué')

export const importanceBadge = (value) => ({
  high: 'bg-rose-100 text-rose-700',
  medium: 'bg-amber-100 text-amber-700',
  low: 'bg-emerald-100 text-emerald-700',
}[value] || 'bg-gray-100 text-gray-500')

export const stepLabel = (step) => ({
  collect: 'Collecte des sources',
  summarize: 'Résumés IA',
  digest: 'Synthèse de la semaine',
}[step] || 'En attente')

export const statusLabel = (status) => ({
  pending: 'En attente',
  running: 'En cours',
  done: 'Terminée',
  failed: 'Échec',
}[status] || 'Jamais lancée')

export const statusBadge = (status) => ({
  pending: 'bg-gray-100 text-gray-600',
  running: 'bg-blue-100 text-blue-700',
  done: 'bg-green-100 text-green-700',
  failed: 'bg-red-100 text-red-700',
}[status] || 'bg-gray-100 text-gray-500')

const parseDay = (value) => new Date(`${value}T12:00:00`)

export const formatDay = (value, options = { day: 'numeric', month: 'long' }) =>
  (value ? parseDay(value).toLocaleDateString('fr-FR', options) : '')

// « du 14 au 20 septembre 2026 », ou « du 28 septembre au 4 octobre 2026 »
export const weekLabel = (week) => {
  if (!week?.monday) return ''
  const sameMonth = week.monday.slice(0, 7) === week.sunday.slice(0, 7)
  const start = formatDay(week.monday, sameMonth ? { day: 'numeric' } : { day: 'numeric', month: 'long' })
  return `du ${start} au ${formatDay(week.sunday, { day: 'numeric', month: 'long', year: 'numeric' })}`
}

export const formatDateTime = (value) =>
  (value ? new Date(value).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }) : null)

export const isRunning = (week) =>
  !!week && ['pending', 'running'].includes(week.status) && !week.stuck

export const progressPercent = (week) =>
  (week?.progress_total ? Math.round((week.progress_done / week.progress_total) * 100) : 0)

// Charge une ressource et la relit tant que `active(data)` est vrai.
export function usePolledResource(loader, active) {
  const data = ref(null)
  const loading = ref(false)
  let pollTimer = null
  let stopped = false

  const load = async () => {
    data.value = await loader()
  }

  const refresh = async () => {
    loading.value = true
    try {
      await load()
    } finally {
      loading.value = false
    }
    schedulePoll()
  }

  function schedulePoll() {
    clearTimeout(pollTimer)
    if (stopped || !active(data.value)) return

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

  return { data, loading, refresh, schedulePoll }
}

export function useSentinelDomains() {
  const { get } = useApi()
  const domains = ref([])
  const configuration = ref({ openai: true, piste: true, tavily: true })

  const fetchDomains = async () => {
    const payload = await get('/sentinel_domains')
    domains.value = payload.domains
    configuration.value = payload.configuration
  }

  const domainByKey = (key) => computed(() => domains.value.find((d) => d.key === key) || null)

  return { domains, configuration, fetchDomains, domainByKey }
}
