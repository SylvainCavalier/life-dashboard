<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Dashboard</router-link>

      <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <div class="flex items-center gap-3">
          <img :src="avatar" alt="" class="h-12 w-12 rounded-full object-cover shadow-sm" />
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Rapports</h1>
            <p class="text-sm text-gray-500">Le tour d'horizon d'Alfred, chaque matin à 9 h</p>
          </div>
        </div>
        <button
          v-if="!todayReport"
          class="bg-gray-900 text-white text-sm px-3 py-2 rounded-lg hover:bg-gray-700 disabled:opacity-40"
          :disabled="busy"
          @click="generateToday"
        >
          Rapport du jour maintenant
        </button>
      </div>

      <p v-if="actionError" class="text-sm text-red-600 mb-4">{{ actionError }}</p>

      <div class="flex flex-col lg:flex-row gap-6">
        <!-- Rapport affiche -->
        <div class="flex-1 min-w-0">
          <div v-if="loading" class="text-center text-gray-400 py-12">Chargement...</div>
          <div v-else-if="notFound" class="text-center text-gray-400 py-12">Rapport introuvable</div>
          <div v-else-if="!report" class="bg-white rounded-xl shadow-sm p-8 text-center text-gray-500">
            Aucun rapport pour l'instant. Le premier arrivera demain à 9 h, à moins que Monsieur ne le réclame dès maintenant.
          </div>

          <article v-else class="bg-white rounded-xl shadow-sm p-5 sm:p-8">
            <header class="flex flex-wrap items-start justify-between gap-3 border-b border-gray-100 pb-4 mb-5">
              <div>
                <p class="text-xs uppercase tracking-wide text-gray-400">
                  Rapport du matin<span v-if="report.weekend"> · week-end</span>
                </p>
                <h2 class="text-xl font-semibold text-gray-900 first-letter:uppercase">{{ report.human_date }}</h2>
              </div>
              <div v-if="report.status === 'done'" class="flex flex-wrap gap-2">
                <button class="bg-gray-900 text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-700 disabled:opacity-40" :disabled="busy" @click="discuss">
                  En parler à Alfred
                </button>
                <button class="bg-white border text-sm px-3 py-1.5 rounded-lg hover:bg-gray-50 disabled:opacity-40" :disabled="busy" @click="regenerate">
                  Régénérer
                </button>
              </div>
            </header>

            <!-- Traitement en cours -->
            <div v-if="report.in_progress" class="py-8 text-center">
              <p class="text-gray-600">{{ report.step === 'write' ? 'Alfred rédige le rapport...' : 'Alfred fait le tour de la maison...' }}</p>
              <p class="text-xs text-gray-400 mt-2">Comptez une minute environ. Vous pouvez quitter la page.</p>
            </div>

            <div v-else-if="report.status === 'failed'" class="bg-red-50 border border-red-100 rounded-lg p-4">
              <p class="text-sm text-red-700">{{ report.error || 'Le rapport a échoué.' }}</p>
              <button class="mt-3 bg-white border text-sm px-3 py-1.5 rounded-lg hover:bg-gray-50 disabled:opacity-40" :disabled="busy" @click="regenerate">
                Relancer
              </button>
            </div>

            <template v-else-if="report.content">
              <p class="text-gray-700 italic leading-relaxed">{{ report.content.opening }}</p>

              <section v-for="section in visibleSections" :key="section.key" class="mt-7">
                <h3 :class="['text-sm font-semibold uppercase tracking-wide mb-3', section.color]">{{ section.title }}</h3>
                <ul class="space-y-3">
                  <li
                    v-for="(item, index) in report.content[section.key]"
                    :key="index"
                    :class="['border-l-4 pl-3 py-0.5', item.urgent ? 'border-red-500' : section.border]"
                  >
                    <p class="font-medium text-gray-900">
                      {{ item.title }}
                      <span v-if="item.urgent" class="ml-1 align-middle text-[10px] uppercase tracking-wide bg-red-50 text-red-600 px-1.5 py-0.5 rounded">urgent</span>
                    </p>
                    <p class="text-sm text-gray-600 mt-0.5 leading-relaxed">{{ item.detail }}</p>
                    <div v-if="item.refs?.length" class="flex flex-wrap gap-1.5 mt-1.5">
                      <template v-for="refKey in item.refs" :key="refKey">
                        <a
                          v-if="report.links[refKey]?.url"
                          :href="report.links[refKey].url"
                          target="_blank"
                          rel="noopener"
                          class="ref-chip"
                        >{{ report.links[refKey].label }} ↗</a>
                        <router-link v-else-if="report.links[refKey]?.path" :to="report.links[refKey].path" class="ref-chip">
                          {{ report.links[refKey].label }}
                        </router-link>
                      </template>
                    </div>
                  </li>
                </ul>
              </section>

              <p v-if="!visibleSections.length" class="mt-6 text-sm text-gray-500">Rien à signaler, Monsieur. Profitez-en.</p>

              <p class="text-gray-700 italic leading-relaxed mt-8">{{ report.content.closing }}</p>

              <div v-if="report.warnings?.length" class="mt-6 bg-amber-50 border border-amber-100 rounded-lg p-3 text-sm text-amber-800">
                <p v-for="warning in report.warnings" :key="warning">{{ warning }}</p>
              </div>
              <p class="text-xs text-gray-300 mt-6">
                {{ report.model }} · {{ report.input_tokens }} tokens en entrée, {{ report.output_tokens }} en sortie
              </p>
            </template>
          </article>
        </div>

        <!-- Archive -->
        <aside class="lg:w-72 flex-shrink-0">
          <h2 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-2">Archive</h2>
          <p v-if="!reports.length" class="text-sm text-gray-400">Aucun rapport.</p>
          <ul class="bg-white rounded-xl shadow-sm divide-y divide-gray-100 overflow-hidden">
            <li v-for="item in reports" :key="item.id">
              <router-link
                :to="`/reports/${item.id}`"
                :class="['block px-4 py-3 hover:bg-gray-50', item.id === report?.id ? 'bg-gray-50' : '']"
              >
                <div class="flex items-center justify-between gap-2">
                  <span :class="['text-sm first-letter:uppercase', item.read ? 'text-gray-700' : 'font-semibold text-gray-900']">
                    {{ item.human_date }}
                  </span>
                  <span v-if="!item.read && item.status === 'done'" class="h-2 w-2 rounded-full bg-blue-500 flex-shrink-0" title="Non lu"></span>
                </div>
                <p class="text-xs text-gray-400 mt-0.5 truncate">
                  <template v-if="item.status === 'done'">
                    {{ item.items_count }} point{{ item.items_count > 1 ? 's' : '' }}<span v-if="item.urgent_count" class="text-red-500"> · {{ item.urgent_count }} urgent{{ item.urgent_count > 1 ? 's' : '' }}</span>
                  </template>
                  <template v-else-if="item.status === 'failed'">Échec</template>
                  <template v-else>En cours...</template>
                </p>
              </router-link>
            </li>
          </ul>
        </aside>
      </div>
    </div>
  </div>
</template>

<script setup>
// Page Rapports : rapports du matin d'Alfred (DailyReport). /reports affiche le plus
// recent, /reports/:id un rapport de l'archive. La table fait foi pour l'etat du
// traitement : la page sonde le rapport tant qu'il est en cours. apiClient direct :
// passer par le store `api` ferait clignoter l'etat de chargement global a chaque sondage.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import apiClient from '../../plugins/axios'
import { useAlfred } from '../../composables/useAlfred'
import avatar from '../../images/alfred-avatar.png'

const props = defineProps({ id: { type: String, default: null } })

const POLL_INTERVAL = 3000

const SECTIONS = [
  { key: 'today', title: "Aujourd'hui", color: 'text-indigo-600', border: 'border-indigo-200' },
  { key: 'mails', title: 'Courrier', color: 'text-sky-600', border: 'border-sky-200' },
  { key: 'people', title: 'Personnes', color: 'text-pink-600', border: 'border-pink-200' },
  { key: 'money', title: 'Échéances et abonnements', color: 'text-amber-600', border: 'border-amber-200' },
  { key: 'priorities', title: 'Priorités', color: 'text-emerald-600', border: 'border-emerald-200' },
  { key: 'remarks', title: 'Remarques', color: 'text-gray-500', border: 'border-gray-200' },
]

const router = useRouter()
const { openInPanel } = useAlfred()

const reports = ref([])
const report = ref(null)
const loading = ref(true)
const notFound = ref(false)
const busy = ref(false)
const actionError = ref(null)
let timer = null

const todayIso = () => {
  const now = new Date()
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
}

const todayReport = computed(() => reports.value.find((r) => r.report_date === todayIso()))

const visibleSections = computed(() => SECTIONS.filter((s) => report.value?.content?.[s.key]?.length))

const errorOf = (err) => err.response?.data?.errors?.join(', ') || err.response?.data?.error || 'Une erreur est survenue.'

const stopPolling = () => {
  if (timer) clearTimeout(timer)
  timer = null
}

const schedule = () => {
  stopPolling()
  if (report.value?.in_progress) timer = setTimeout(() => fetchReport(report.value.id), POLL_INTERVAL)
}

const fetchList = async () => {
  reports.value = (await apiClient.get('/daily_reports')).data
}

const fetchReport = async (id) => {
  try {
    report.value = (await apiClient.get(`/daily_reports/${id}`)).data
    notFound.value = false
    // Fin de traitement, ou rapport ouvert (donc lu) : l'archive suit.
    const entry = reports.value.find((r) => r.id === report.value.id)
    if (!entry || entry.status !== report.value.status || entry.read !== report.value.read) await fetchList()
  } catch (err) {
    if (err.response?.status === 404) notFound.value = true
    else actionError.value = errorOf(err)
  }
  schedule()
}

const load = async () => {
  stopPolling()
  loading.value = true
  actionError.value = null
  try {
    await fetchList()
    const id = props.id || reports.value[0]?.id
    if (id) await fetchReport(id)
    else report.value = null
  } catch (err) {
    actionError.value = errorOf(err)
  } finally {
    loading.value = false
  }
}

const run = async (request) => {
  busy.value = true
  actionError.value = null
  try {
    return await request()
  } catch (err) {
    actionError.value = errorOf(err)
    return null
  } finally {
    busy.value = false
  }
}

const generateToday = () => run(async () => {
  const { data } = await apiClient.post('/daily_reports')
  report.value = data
  await fetchList()
  if (String(data.id) !== props.id) router.push(`/reports/${data.id}`)
  schedule()
})

const regenerate = () => run(async () => {
  report.value = (await apiClient.post(`/daily_reports/${report.value.id}/regenerate`)).data
  await fetchList()
  schedule()
})

const discuss = () => run(async () => {
  const { data } = await apiClient.post(`/daily_reports/${report.value.id}/discuss`)
  await openInPanel(data.conversation_id)
})

watch(() => props.id, load)
onMounted(load)
onBeforeUnmount(stopPolling)
</script>

<style scoped>
.ref-chip {
  @apply inline-block max-w-full truncate text-xs text-gray-500 bg-gray-100 hover:bg-gray-200 hover:text-gray-800 rounded px-2 py-0.5 transition-colors;
}
</style>
