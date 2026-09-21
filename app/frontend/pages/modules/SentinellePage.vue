<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">← Retour au dashboard</router-link>

      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <span class="text-3xl">🛰️</span>
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Sentinelle</h1>
            <p class="text-sm text-gray-400">Veille hebdomadaire, un domaine par onglet</p>
          </div>
        </div>
        <button
          v-if="domain"
          @click="showSources = true"
          class="text-sm px-4 py-2 rounded-lg border border-gray-200 bg-white text-gray-700 hover:bg-gray-50 transition"
        >
          Sources ({{ domain.sources_count }})
        </button>
      </div>

      <!-- Un onglet par domaine : les domaines viennent du registre cote serveur -->
      <div class="flex border-b border-gray-200 mb-6 overflow-x-auto">
        <router-link
          v-for="d in domains"
          :key="d.key"
          :to="`/sentinelle/${d.key}`"
          class="px-5 py-3 text-sm font-medium whitespace-nowrap transition-colors"
          :class="d.key === domainKey
            ? 'text-indigo-600 border-b-2 border-indigo-600'
            : 'text-gray-500 hover:text-gray-700'"
        >
          <span class="mr-1">{{ d.icon }}</span>{{ d.label }}
        </router-link>
      </div>

      <template v-if="domain">
        <p class="text-sm text-gray-500 mb-4">{{ domain.description }}</p>

        <div v-for="message in configurationWarnings" :key="message" class="bg-amber-50 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
          {{ message }}
        </div>

        <div v-if="loading && !weeks" class="text-center text-gray-400 py-12">Chargement...</div>

        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <router-link
            v-for="week in weeks || []"
            :key="week.monday"
            :to="`/sentinelle/${domainKey}/${week.monday}`"
            class="rounded-xl p-5 transition-all hover:-translate-y-0.5"
            :class="week.status
              ? 'bg-white shadow-sm hover:shadow-md'
              : 'border-2 border-dashed border-gray-200 hover:border-indigo-300'"
          >
            <div class="flex items-start justify-between gap-2 mb-3">
              <div>
                <p class="text-xs uppercase tracking-wide text-gray-400">Semaine</p>
                <p class="font-semibold text-gray-900">{{ weekLabel(week) }}</p>
              </div>
              <span v-if="week.status" class="text-xs px-2 py-0.5 rounded-full font-medium shrink-0" :class="statusBadge(week.status)">
                {{ statusLabel(week.status) }}
              </span>
              <span v-else-if="!week.complete" class="text-xs px-2 py-0.5 rounded-full font-medium shrink-0 bg-indigo-50 text-indigo-600">
                En cours
              </span>
            </div>

            <template v-if="week.status">
              <div v-if="isRunning(week)" class="text-sm text-blue-700">
                {{ stepLabel(week.step) }}
                <span v-if="week.progress_total"> · {{ week.progress_done }}/{{ week.progress_total }}</span>
              </div>
              <p v-else-if="week.digest_headline" class="text-sm text-gray-600 line-clamp-4">{{ week.digest_headline }}</p>
              <p v-else-if="week.status === 'failed'" class="text-sm text-red-600 line-clamp-3">{{ week.error }}</p>
              <p v-else class="text-sm text-gray-400">Pas de synthèse pour cette semaine</p>

              <div class="flex gap-4 mt-4 text-xs text-gray-400">
                <span><strong class="text-gray-700">{{ week.counts.relevant }}</strong> retenu{{ week.counts.relevant > 1 ? 's' : '' }}</span>
                <span><strong class="text-gray-700">{{ week.counts.total }}</strong> collecté{{ week.counts.total > 1 ? 's' : '' }}</span>
                <span v-if="week.warnings.length" class="text-amber-600">{{ week.warnings.length }} avertissement{{ week.warnings.length > 1 ? 's' : '' }}</span>
              </div>
            </template>
            <p v-else class="text-sm text-gray-400">Veille jamais lancée : cliquer pour l'ouvrir</p>
          </router-link>
        </div>
      </template>

      <div v-else-if="domainsLoaded" class="text-center text-gray-400 py-12">Domaine de veille inconnu</div>
    </div>

    <SentinelSourcesModal
      v-if="showSources && domain"
      :domain="domain"
      @close="showSources = false"
      @changed="fetchDomains"
    />
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import {
  useSentinelDomains, usePolledResource, isRunning, weekLabel, statusLabel, statusBadge, stepLabel,
} from '../../composables/useSentinel'
import SentinelSourcesModal from '../../components/sentinel/SentinelSourcesModal.vue'

const props = defineProps({
  domainKey: { type: String, default: null },
})

const router = useRouter()
const { get } = useApi()
const { domains, configuration, fetchDomains } = useSentinelDomains()

const domainsLoaded = ref(false)
const showSources = ref(false)
const domain = computed(() => domains.value.find((d) => d.key === props.domainKey) || null)

const { data: weeks, loading, refresh } = usePolledResource(
  () => get(`/sentinel_domains/${props.domainKey}/weeks`),
  (list) => (list || []).some(isRunning),
)

// Cles API manquantes : signalees ici plutot que par un echec au premier lancement.
const configurationWarnings = computed(() => {
  const messages = []
  if (!configuration.value.openai) {
    messages.push('OPENAI_API_KEY est absente : la collecte fonctionnera, mais ni les résumés ni la synthèse.')
  }
  if (props.domainKey === 'droit_travail' && !configuration.value.piste) {
    messages.push('PISTE_CLIENT_ID / PISTE_CLIENT_SECRET sont absents : Judilibre et Légifrance seront ignorés.')
  }
  if (props.domainKey === 'desinformation' && !configuration.value.tavily) {
    messages.push('TAVILY_API_KEY est absente : seuls les flux RSS seront collectés, pas la recherche web.')
  }
  return messages
})

watch(() => props.domainKey, (key) => {
  weeks.value = null
  if (key && domain.value) refresh()
})

onMounted(async () => {
  await fetchDomains()
  domainsLoaded.value = true

  // /sentinelle sans domaine : on ouvre le premier onglet.
  if (!props.domainKey && domains.value.length) {
    router.replace(`/sentinelle/${domains.value[0].key}`)
  } else if (domain.value) {
    refresh()
  }
})
</script>
