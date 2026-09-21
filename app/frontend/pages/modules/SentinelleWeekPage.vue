<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <router-link :to="`/sentinelle/${domainKey}`" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">
        ← Retour à {{ domain?.label || 'Sentinelle' }}
      </router-link>

      <div v-if="loading && !week" class="text-center text-gray-400 py-12">Chargement...</div>

      <template v-else-if="week">
        <div class="flex flex-wrap items-start justify-between gap-4 mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">{{ domain?.icon || '🛰️' }}</span>
            <div>
              <h1 class="text-2xl font-bold text-gray-900">Semaine {{ weekLabel(week) }}</h1>
              <p class="text-sm text-gray-400">
                {{ domain?.label }}
                <span v-if="!week.complete"> · semaine en cours, veille partielle</span>
              </p>
            </div>
          </div>

          <div class="flex items-center gap-2">
            <button
              @click="runWeek"
              :disabled="running || launching"
              class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {{ week.status ? 'Relancer la veille' : 'Lancer la veille' }}
            </button>
            <button
              v-if="week.status"
              @click="destroyWeek"
              :disabled="running"
              class="text-sm px-3 py-2 rounded-lg text-red-600 hover:bg-red-50 transition disabled:opacity-40"
            >
              Supprimer
            </button>
          </div>
        </div>

        <!-- Etat du traitement -->
        <div v-if="running" class="bg-indigo-50 text-indigo-800 text-sm rounded-lg px-4 py-3 mb-4">
          <div class="flex items-center gap-2">
            <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" />
            </svg>
            <span>
              {{ stepLabel(week.step) }}
              <span v-if="week.progress_total"> · {{ week.progress_done }}/{{ week.progress_total }}</span>
            </span>
          </div>
          <div v-if="week.progress_total" class="mt-2 h-1.5 bg-indigo-100 rounded-full overflow-hidden">
            <div class="h-full bg-indigo-500 transition-all" :style="{ width: `${progressPercent(week)}%` }"></div>
          </div>
        </div>
        <div v-else-if="week.stuck" class="bg-amber-50 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
          Le traitement semble interrompu (redémarrage du serveur ?). Relancer la veille reprend là où il s'est arrêté.
        </div>
        <div v-else-if="week.status === 'failed'" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mb-4">
          Échec : {{ week.error }}
        </div>

        <details v-if="week.warnings.length && !running" class="bg-amber-50 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
          <summary class="cursor-pointer font-medium">
            {{ week.warnings.length }} avertissement{{ week.warnings.length > 1 ? 's' : '' }} lors de la dernière veille
          </summary>
          <ul class="mt-2 space-y-1 list-disc list-inside">
            <li v-for="warning in week.warnings" :key="warning">{{ warning }}</li>
          </ul>
        </details>

        <!-- Synthese de la semaine -->
        <section v-if="week.digest" class="bg-white rounded-xl shadow-sm p-6 mb-6 border-l-4 border-indigo-500">
          <div class="flex flex-wrap items-baseline justify-between gap-2 mb-3">
            <h2 class="text-lg font-bold text-gray-900">Synthèse de la semaine</h2>
            <p class="text-xs text-gray-400">
              {{ week.digest.documents_count }} document{{ week.digest.documents_count > 1 ? 's' : '' }}
              · {{ week.digest_model }} · {{ formatDateTime(week.digest_generated_at) }}
            </p>
          </div>

          <p class="text-gray-700 leading-relaxed">{{ week.digest.tldr }}</p>

          <div v-if="week.digest.key_themes?.length" class="mt-5">
            <h3 class="section-title">Thèmes saillants</h3>
            <div class="flex flex-wrap gap-2">
              <span v-for="theme in week.digest.key_themes" :key="theme" class="text-sm px-3 py-1 rounded-full bg-indigo-50 text-indigo-700">
                {{ theme }}
              </span>
            </div>
          </div>

          <div v-if="topDocuments.length" class="mt-5">
            <h3 class="section-title">À ne pas manquer</h3>
            <ul class="space-y-3">
              <li v-for="entry in topDocuments" :key="entry.document.id">
                <button @click="openDocument(entry.document)" class="text-left text-indigo-600 hover:underline font-medium">
                  {{ entry.document.display_title || entry.document.title }}
                </button>
                <p class="text-sm text-gray-600">{{ entry.why }}</p>
              </li>
            </ul>
          </div>

          <p v-if="week.digest.impact_summary" class="mt-5 text-sm text-gray-600 italic">{{ week.digest.impact_summary }}</p>
        </section>

        <div v-else-if="!week.status" class="bg-white rounded-xl shadow-sm p-8 mb-6 text-center">
          <p class="text-gray-600 mb-1">Aucune veille n'a encore été lancée pour cette semaine.</p>
          <p class="text-sm text-gray-400">
            Le lancement collecte les sources, résume chaque document retenu puis rédige la synthèse. Compter quelques minutes.
          </p>
        </div>

        <!-- Documents -->
        <template v-if="week.documents.length">
          <div class="flex flex-wrap items-center gap-3 mb-4">
            <h2 class="text-lg font-bold text-gray-900 mr-auto">
              Documents <span class="text-gray-400 font-normal">({{ filteredDocuments.length }})</span>
            </h2>
            <select v-model="filters.source" class="filter-select">
              <option value="">Toutes les sources</option>
              <option v-for="source in sourceOptions" :key="source" :value="source">{{ source }}</option>
            </select>
            <select v-if="kindOptions.length > 1" v-model="filters.kind" class="filter-select">
              <option value="">Tous les types</option>
              <option v-for="kind in kindOptions" :key="kind" :value="kind">{{ kindLabel(kind) }}</option>
            </select>
            <select v-model="filters.category" class="filter-select">
              <option value="">Toutes les catégories</option>
              <option v-for="(label, slug) in domain?.categories || {}" :key="slug" :value="slug">{{ label }}</option>
            </select>
            <label class="flex items-center gap-2 text-sm text-gray-500">
              <input v-model="filters.showIrrelevant" type="checkbox" class="rounded border-gray-300" />
              Hors champ ({{ week.counts.total - week.counts.relevant }})
            </label>
          </div>

          <div class="space-y-3">
            <button
              v-for="document in filteredDocuments"
              :key="document.id"
              @click="openDocument(document)"
              class="w-full text-left bg-white rounded-xl shadow-sm p-5 hover:shadow-md transition"
              :class="{ 'opacity-60': !document.relevant }"
            >
              <div class="flex flex-wrap items-center gap-2 text-xs text-gray-400 mb-2">
                <span class="px-2 py-0.5 rounded-full font-medium" :class="importanceBadge(document.importance)" v-if="document.relevant">
                  {{ importanceLabel(document.importance) }}
                </span>
                <span v-else class="px-2 py-0.5 rounded-full font-medium bg-gray-100 text-gray-500">Hors champ</span>
                <span class="px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">{{ kindLabel(document.kind) }}</span>
                <span>{{ document.source_name }}</span>
                <span v-if="document.published_at">· {{ formatDateTime(document.published_at) }}</span>
                <span v-if="document.author">· {{ document.author }}</span>
              </div>
              <h3 class="font-semibold text-gray-900">{{ document.display_title || document.title }}</h3>
              <p v-if="document.display_title" class="text-xs text-gray-400 mt-0.5">{{ document.title }}</p>
              <p v-if="document.tldr" class="text-sm text-gray-600 mt-2 line-clamp-3">{{ document.tldr }}</p>
              <p v-else-if="document.relevant" class="text-sm text-gray-400 mt-2">Pas encore de résumé</p>
              <div v-if="document.categories.length" class="flex flex-wrap gap-1.5 mt-3">
                <span v-for="slug in document.categories" :key="slug" class="text-xs px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700">
                  {{ domain?.categories?.[slug] || slug }}
                </span>
              </div>
            </button>
          </div>

          <div v-if="!filteredDocuments.length" class="text-center text-gray-400 py-12">Aucun document ne correspond à ces filtres</div>
        </template>
      </template>
    </div>

    <SentinelDocumentModal
      v-if="openedDocument"
      :document-id="openedDocument.id"
      :domain="domain"
      @close="openedDocument = null"
    />
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import {
  useSentinelDomains, usePolledResource, isRunning, progressPercent, weekLabel, stepLabel,
  importanceLabel, importanceBadge, formatDateTime,
} from '../../composables/useSentinel'
import SentinelDocumentModal from '../../components/sentinel/SentinelDocumentModal.vue'

const props = defineProps({
  domainKey: { type: String, required: true },
  monday: { type: String, required: true },
})

const router = useRouter()
const { get, post, delete: del } = useApi()
const { domains, fetchDomains } = useSentinelDomains()

const weekPath = `/sentinel_domains/${props.domainKey}/weeks/${props.monday}`
const { data: week, loading, refresh, schedulePoll } = usePolledResource(() => get(weekPath), isRunning)

const launching = ref(false)
const openedDocument = ref(null)
const filters = reactive({ source: '', kind: '', category: '', showIrrelevant: false })

const domain = computed(() => domains.value.find((d) => d.key === props.domainKey) || null)
const running = computed(() => isRunning(week.value))
const kindLabel = (kind) => domain.value?.kinds?.[kind] || kind

const sourceOptions = computed(() => [...new Set((week.value?.documents || []).map((d) => d.source_name))].sort())
const kindOptions = computed(() => [...new Set((week.value?.documents || []).map((d) => d.kind))])

const filteredDocuments = computed(() => (week.value?.documents || []).filter((document) => {
  if (!filters.showIrrelevant && !document.relevant) return false
  if (filters.source && document.source_name !== filters.source) return false
  if (filters.kind && document.kind !== filters.kind) return false
  if (filters.category && !document.categories.includes(filters.category)) return false
  return true
}))

// Les references de la synthese sont resolues contre les documents de la semaine :
// un document supprime depuis (source retiree) disparait simplement de la liste.
const topDocuments = computed(() => (week.value?.digest?.top_documents || [])
  .map((entry) => ({ why: entry.why, document: week.value.documents.find((d) => d.id === entry.document_id) }))
  .filter((entry) => entry.document))

const showErrors = (e) => {
  const errors = e.response?.data?.errors
  alert(Array.isArray(errors) ? errors.join('\n') : 'Une erreur est survenue')
}

const runWeek = async () => {
  launching.value = true
  try {
    const state = await post(`${weekPath}/run`)
    // La reponse ne porte que l'etat : on garde la synthese et les documents
    // affiches pendant que la nouvelle veille tourne.
    week.value = { ...week.value, ...state, counts: week.value.counts }
    schedulePoll()
  } catch (e) {
    showErrors(e)
  } finally {
    launching.value = false
  }
}

const destroyWeek = async () => {
  if (!confirm('Supprimer cette semaine, ses documents et sa synthèse ? La prochaine veille repartira de zéro.')) return
  try {
    await del(weekPath)
    router.push(`/sentinelle/${props.domainKey}`)
  } catch (e) {
    showErrors(e)
  }
}

const openDocument = (document) => {
  openedDocument.value = document
}

onMounted(async () => {
  try {
    await Promise.all([fetchDomains(), refresh()])
  } catch (e) {
    showErrors(e)
  }
})
</script>

<style scoped>
.section-title {
  @apply text-xs font-semibold uppercase tracking-wide text-gray-400 mb-2;
}
.filter-select {
  @apply text-sm border border-gray-200 rounded-lg px-3 py-1.5 bg-white text-gray-700;
}
</style>
