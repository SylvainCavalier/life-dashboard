<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Langues</h1>
        <div class="flex items-center gap-2">
          <button
            @click="syncLangochat"
            :disabled="syncing"
            class="text-sm px-4 py-2 rounded-lg border border-indigo-200 text-indigo-600 hover:bg-indigo-50 transition disabled:opacity-50"
          >
            <span v-if="syncing">Sync en cours...</span>
            <span v-else>Sync Langochat</span>
          </button>
          <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
            + Nouvelle langue
          </button>
        </div>
      </div>

      <!-- Sync result -->
      <div v-if="syncResult" class="mb-4 p-3 rounded-lg text-sm" :class="syncResult.errors?.length ? 'bg-amber-50 text-amber-700' : 'bg-green-50 text-green-700'">
        {{ syncResult.synced }} session(s) synchronisee(s) depuis Langochat
        <span v-if="syncResult.errors?.length"> — {{ syncResult.errors.join(', ') }}</span>
        <button @click="syncResult = null" class="ml-2 text-xs underline">Fermer</button>
      </div>

      <!-- Form -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold mb-4">{{ editingId ? 'Modifier la langue' : 'Nouvelle langue' }}</h2>
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Langue *</label>
            <select v-model="form.name" class="w-full border rounded-lg px-3 py-2 text-sm" :disabled="!!editingId">
              <option value="" disabled>Choisir une langue</option>
              <option v-if="editingId" :value="form.name">{{ form.name }}</option>
              <option v-for="name in availableNames" :key="name" :value="name">{{ name }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Niveau *</label>
            <select v-model="form.level" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option v-for="l in levels" :key="l" :value="l">{{ l }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Emoji drapeau</label>
            <input v-model="form.flag_emoji" type="text" placeholder="🇬🇧" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Couleur</label>
            <input v-model="form.color" type="color" class="w-full border rounded-lg h-[38px] px-1 py-1" />
          </div>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
          <textarea v-model="form.notes" rows="2" placeholder="Objectifs, ressources..." class="w-full border rounded-lg px-3 py-2 text-sm"></textarea>
        </div>
        <div class="flex justify-end gap-2">
          <button @click="showForm = false" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
          <button @click="saveLanguage" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
            {{ editingId ? 'Modifier' : 'Ajouter' }}
          </button>
        </div>
      </div>

      <!-- Empty state -->
      <div v-if="languages.length === 0 && !showForm" class="bg-white rounded-xl shadow-sm p-12 text-center">
        <div class="text-4xl mb-4">🌍</div>
        <p class="text-gray-500 mb-4">Aucune langue ajoutee</p>
        <button @click="openForm()" class="text-sm text-indigo-600 hover:text-indigo-800">Ajouter ma premiere langue</button>
      </div>

      <!-- Languages list -->
      <div v-else class="space-y-4">
        <div
          v-for="lang in languages"
          :key="lang.id"
          class="bg-white rounded-xl shadow-sm p-5 transition-all"
        >
          <div class="flex items-center justify-between">
            <!-- Left: info -->
            <div class="flex items-center gap-4">
              <div class="text-3xl">{{ lang.flag_emoji || '🌐' }}</div>
              <div>
                <div class="flex items-center gap-2">
                  <h3 class="font-semibold text-gray-900 text-lg">{{ lang.name }}</h3>
                  <span
                    class="text-xs font-bold px-2 py-0.5 rounded-full text-white"
                    :style="{ backgroundColor: levelColor(lang.level) }"
                  >{{ lang.level }}</span>
                </div>
                <div class="flex items-center gap-3 text-sm text-gray-500 mt-1">
                  <span v-if="lang.streak > 0" class="flex items-center gap-1">
                    <span class="text-orange-500">🔥</span> {{ lang.streak }} jour{{ lang.streak > 1 ? 's' : '' }}
                  </span>
                  <span>{{ lang.sessions_this_week }} session{{ lang.sessions_this_week > 1 ? 's' : '' }} cette semaine</span>
                  <span>{{ lang.total_sessions }} au total</span>
                </div>
              </div>
            </div>

            <!-- Right: actions -->
            <div class="flex items-center gap-3">
              <button
                @click="toggleSession(lang)"
                :class="[
                  'px-4 py-2 rounded-lg text-sm font-medium transition-all',
                  lang.practiced_today
                    ? 'bg-green-100 text-green-700 hover:bg-green-200'
                    : 'bg-indigo-600 text-white hover:bg-indigo-700'
                ]"
              >
                <span v-if="lang.practiced_today">✓ Travaille aujourd'hui</span>
                <span v-else>Marquer aujourd'hui</span>
              </button>
              <button
                @click="showStats(lang)"
                class="text-gray-400 hover:text-indigo-600 transition"
                title="Statistiques"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
              </button>
              <button @click="openForm(lang)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteLanguage(lang.id)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>

          <!-- Stats panel (expandable) -->
          <div v-if="statsLanguageId === lang.id && statsData" class="mt-5 pt-5 border-t">
            <h4 class="text-sm font-semibold text-gray-700 mb-3">Historique de pratique</h4>

            <!-- Monthly bar chart -->
            <div class="mb-4">
              <div class="flex items-end gap-1 h-32">
                <div
                  v-for="m in statsData.monthly"
                  :key="m.month"
                  class="flex-1 flex flex-col items-center justify-end"
                >
                  <span class="text-xs text-gray-500 mb-1">{{ m.count }}</span>
                  <div
                    class="w-full rounded-t transition-all"
                    :style="{
                      height: maxMonthly > 0 ? (m.count / maxMonthly * 100) + 'px' : '2px',
                      backgroundColor: lang.color || '#6366f1'
                    }"
                  ></div>
                  <span class="text-[10px] text-gray-400 mt-1">{{ formatMonth(m.month) }}</span>
                </div>
              </div>
            </div>

            <!-- Heatmap (last 90 days) -->
            <div class="mb-2">
              <h5 class="text-xs font-medium text-gray-500 mb-2">90 derniers jours</h5>
              <div class="flex flex-wrap gap-[3px]">
                <div
                  v-for="day in heatmapDays"
                  :key="day.date"
                  class="w-3 h-3 rounded-sm transition-colors"
                  :style="{ backgroundColor: heatmapColor(day, lang.color || '#6366f1') }"
                  :title="heatmapTooltip(day)"
                ></div>
              </div>
              <div class="flex items-center gap-4 mt-2 text-[10px] text-gray-400">
                <span class="flex items-center gap-1">
                  <span class="w-3 h-3 rounded-sm inline-block" :style="{ backgroundColor: lang.color || '#6366f1' }"></span>
                  Manuel
                </span>
                <span class="flex items-center gap-1">
                  <span class="w-3 h-3 rounded-sm inline-block" :style="{ backgroundColor: lang.color || '#6366f1', opacity: 0.5 }"></span>
                  Langochat
                </span>
                <span class="flex items-center gap-1">
                  <span class="w-3 h-3 rounded-sm inline-block bg-gray-100"></span>
                  Aucune pratique
                </span>
              </div>
            </div>

            <div class="flex gap-4 text-sm text-gray-500 mt-3">
              <span>Total : <strong>{{ statsData.total_sessions }}</strong> sessions</span>
              <span v-if="statsData.manual_sessions">Manuel : <strong>{{ statsData.manual_sessions }}</strong></span>
              <span v-if="statsData.langochat_sessions">Langochat : <strong>{{ statsData.langochat_sessions }}</strong></span>
              <span>Streak : <strong>{{ statsData.streak }}</strong> jour{{ statsData.streak > 1 ? 's' : '' }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- Langochat integration info -->
      <div v-if="languages.length > 0" class="mt-8 bg-gradient-to-r from-indigo-50 to-purple-50 rounded-xl p-6 border border-indigo-100">
        <div class="flex items-center gap-3 mb-2">
          <span class="text-2xl">🔗</span>
          <h3 class="font-semibold text-gray-900">Integration Langochat</h3>
          <span class="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-medium">Active</span>
        </div>
        <p class="text-sm text-gray-600">
          Les sessions completees sur Langochat sont synchronisees automatiquement chaque soir.
          Tu peux aussi lancer une synchronisation manuelle avec le bouton "Sync Langochat" ci-dessus.
          Les sessions Langochat apparaissent dans le heatmap avec une opacite reduite.
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud, post, del, get } = useApi()
const { list, create, update, destroy } = useCrud('languages')

const languages = ref([])
const availableNames = ref([])
const showForm = ref(false)
const editingId = ref(null)
const statsLanguageId = ref(null)
const statsData = ref(null)
const syncing = ref(false)
const syncResult = ref(null)

const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2']

const defaultForm = () => ({
  name: '',
  level: 'A1',
  color: '#6366f1',
  flag_emoji: '',
  notes: '',
})

const form = ref(defaultForm())

const levelColor = (level) => {
  const colors = {
    A1: '#ef4444', A2: '#f97316',
    B1: '#eab308', B2: '#22c55e',
    C1: '#3b82f6', C2: '#8b5cf6',
  }
  return colors[level] || '#6b7280'
}

const maxMonthly = computed(() => {
  if (!statsData.value?.monthly) return 0
  return Math.max(...statsData.value.monthly.map(m => m.count), 1)
})

const heatmapDays = computed(() => {
  if (!statsData.value) return []
  // Build a map of date -> sources
  const sourceMap = {}
  if (statsData.value.dates_with_source) {
    for (const entry of statsData.value.dates_with_source) {
      if (!sourceMap[entry.date]) sourceMap[entry.date] = new Set()
      sourceMap[entry.date].add(entry.source)
    }
  } else {
    // Fallback: all dates treated as manual
    for (const d of (statsData.value.dates || [])) {
      sourceMap[d] = new Set(['manual'])
    }
  }

  const days = []
  for (let i = 89; i >= 0; i--) {
    const d = new Date()
    d.setDate(d.getDate() - i)
    const dateStr = d.toISOString().slice(0, 10)
    const sources = sourceMap[dateStr] || new Set()
    days.push({
      date: dateStr,
      practiced: sources.size > 0,
      hasManual: sources.has('manual'),
      hasLangochat: sources.has('langochat'),
    })
  }
  return days
})

const heatmapColor = (day, color) => {
  if (!day.practiced) return '#f3f4f6'
  if (day.hasManual && day.hasLangochat) return color // Both: full color
  if (day.hasManual) return color
  // Langochat only: lighter version
  return color + '80' // 50% opacity via hex alpha
}

const heatmapTooltip = (day) => {
  if (!day.practiced) return day.date
  const sources = []
  if (day.hasManual) sources.push('Manuel')
  if (day.hasLangochat) sources.push('Langochat')
  return `${day.date} - ${sources.join(' + ')}`
}

const formatMonth = (monthStr) => {
  const [, month] = monthStr.split('-')
  const names = ['Jan', 'Fev', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aout', 'Sep', 'Oct', 'Nov', 'Dec']
  return names[parseInt(month) - 1]
}

const fetchLanguages = async () => {
  const data = await list()
  languages.value = data.languages
  availableNames.value = data.available_names
}

const openForm = (lang = null) => {
  if (lang) {
    editingId.value = lang.id
    form.value = {
      name: lang.name,
      level: lang.level,
      color: lang.color || '#6366f1',
      flag_emoji: lang.flag_emoji || '',
      notes: lang.notes || '',
    }
  } else {
    editingId.value = null
    form.value = defaultForm()
  }
  showForm.value = true
}

const saveLanguage = async () => {
  if (!form.value.name) return
  const payload = { language: { ...form.value } }
  if (!payload.language.flag_emoji) payload.language.flag_emoji = null
  if (!payload.language.notes) payload.language.notes = null

  if (editingId.value) {
    await update(editingId.value, payload)
  } else {
    await create(payload)
  }
  showForm.value = false
  await fetchLanguages()
}

const deleteLanguage = async (id) => {
  if (!confirm('Supprimer cette langue et tout son historique ?')) return
  await destroy(id)
  if (statsLanguageId.value === id) {
    statsLanguageId.value = null
    statsData.value = null
  }
  await fetchLanguages()
}

const toggleSession = async (lang) => {
  if (lang.practiced_today) {
    await del(`/languages/${lang.id}/unlog_session`)
  } else {
    await post(`/languages/${lang.id}/log_session`)
  }
  await fetchLanguages()
  if (statsLanguageId.value === lang.id) {
    await loadStats(lang.id)
  }
}

const showStats = async (lang) => {
  if (statsLanguageId.value === lang.id) {
    statsLanguageId.value = null
    statsData.value = null
    return
  }
  await loadStats(lang.id)
}

const loadStats = async (langId) => {
  statsLanguageId.value = langId
  statsData.value = await get(`/languages/${langId}/stats`)
}

const syncLangochat = async () => {
  syncing.value = true
  syncResult.value = null
  try {
    syncResult.value = await post('/languages/sync_langochat')
    await fetchLanguages()
    if (statsLanguageId.value) {
      await loadStats(statsLanguageId.value)
    }
  } catch (e) {
    syncResult.value = { synced: 0, errors: ['Erreur de connexion a Langochat'] }
  } finally {
    syncing.value = false
  }
}

onMounted(() => {
  fetchLanguages()
})
</script>
