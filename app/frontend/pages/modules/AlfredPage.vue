<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <!-- Retour -->
      <router-link
        to="/"
        class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6"
      >
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour au dashboard
      </router-link>

      <div v-if="loading && !overview" class="text-center py-12 text-gray-400">Chargement...</div>

      <template v-else-if="overview">
        <!-- En-tete -->
        <div class="bg-white rounded-xl shadow-sm p-8 mb-6">
          <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="flex items-center gap-4">
              <img :src="avatar" alt="Alfred" class="h-16 w-16 rounded-full object-cover ring-4 ring-gray-100 shadow-sm" />
              <div>
                <h1 class="text-2xl font-bold text-gray-900">Alfred</h1>
                <p class="text-sm text-gray-500">Votre intendant : ce qu'il sait, ce qu'il peut faire, comment il se comporte.</p>
              </div>
            </div>
            <span
              class="text-xs font-medium px-3 py-1 rounded-full"
              :class="overview.available ? 'bg-green-50 text-green-700' : 'bg-amber-50 text-amber-800'"
            >
              {{ overview.available ? 'Operationnel' : `Non configure : ${overview.missing_keys.join(', ')}` }}
            </span>
          </div>

          <dl class="mt-6 grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <dt class="text-xs text-gray-400">Modele</dt>
              <dd class="text-gray-800 font-mono text-xs mt-0.5">{{ overview.model }}</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-400">Effort de reflexion</dt>
              <dd class="text-gray-800 mt-0.5">{{ overview.effort }}</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-400">Historique rejoue</dt>
              <dd class="text-gray-800 mt-0.5">{{ overview.history_messages }} derniers messages</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-400">Memoire documentaire</dt>
              <dd class="text-gray-800 mt-0.5">{{ overview.corpus.records }} fiches, {{ overview.corpus.chunks }} passages</dd>
            </div>
          </dl>
          <p class="mt-3 text-xs text-gray-400">
            Modele et effort se reglent par les variables d'environnement (<code>ALFRED_MODEL</code>, <code>ALFRED_EFFORT</code>, <code>ALFRED_HISTORY_MESSAGES</code>).
          </p>
        </div>

        <!-- Onglets -->
        <div class="flex gap-1 mb-4 border-b border-gray-200">
          <button
            v-for="t in tabs"
            :key="t.key"
            type="button"
            class="px-4 py-2 text-sm font-medium border-b-2 -mb-px transition-colors"
            :class="tab === t.key ? 'border-gray-900 text-gray-900' : 'border-transparent text-gray-500 hover:text-gray-800'"
            @click="tab = t.key"
          >
            {{ t.label }}
          </button>
        </div>

        <!-- Instructions -->
        <div v-if="tab === 'instructions'" class="space-y-4">
          <div class="bg-white rounded-xl shadow-sm p-6">
            <p class="text-sm text-gray-600">
              Le prompt d'Alfred est decoupe en sections. Chacune a un texte par defaut ecrit dans le code ; vous pouvez le
              remplacer ici, et revenir au texte d'origine a tout moment. Les listes deduites du code (outils, modeles lisibles,
              boites mail) sont ajoutees automatiquement et n'apparaissent pas dans les zones ci-dessous.
            </p>
            <div class="mt-3 flex flex-wrap items-center gap-3">
              <button type="button" class="btn-secondary" @click="togglePreview">
                {{ preview === null ? 'Voir le prompt complet' : 'Masquer le prompt complet' }}
              </button>
              <span v-if="overriddenCount" class="text-xs text-indigo-700 bg-indigo-50 px-2 py-1 rounded-full">
                {{ overriddenCount }} section{{ overriddenCount > 1 ? 's' : '' }} modifiee{{ overriddenCount > 1 ? 's' : '' }}
              </span>
            </div>
            <pre v-if="preview !== null" class="mt-4 max-h-[32rem] overflow-auto whitespace-pre-wrap rounded-lg bg-gray-900 text-gray-100 text-xs p-4 leading-relaxed">{{ preview }}</pre>
          </div>

          <div
            v-for="section in overview.prompt_sections"
            :key="section.key"
            class="bg-white rounded-xl shadow-sm p-6"
          >
            <div class="flex flex-wrap items-center justify-between gap-2 mb-1">
              <h2 class="font-semibold text-gray-900">
                {{ section.title }}
                <span v-if="section.override" class="ml-2 text-[11px] font-medium text-indigo-700 bg-indigo-50 px-2 py-0.5 rounded-full align-middle">modifiee</span>
              </h2>
              <span v-if="saved === section.key" class="text-xs text-green-700">Enregistre</span>
            </div>
            <p class="text-xs text-gray-500 mb-3">{{ section.help }}</p>
            <textarea
              v-model="drafts[section.key]"
              :rows="rowsFor(drafts[section.key])"
              class="w-full rounded-lg border px-3 py-2 text-sm font-mono leading-relaxed focus:outline-none focus:ring-2 focus:ring-gray-900/20"
              :class="drafts[section.key] !== currentText(section) ? 'border-amber-300 bg-amber-50/30' : 'border-gray-300'"
            />
            <div class="mt-2 flex flex-wrap gap-2">
              <button
                type="button"
                class="btn-primary"
                :disabled="saving === section.key || drafts[section.key] === currentText(section)"
                @click="saveSection(section)"
              >
                Enregistrer
              </button>
              <button
                v-if="section.override || drafts[section.key] !== section.default"
                type="button"
                class="btn-secondary"
                :disabled="saving === section.key"
                @click="resetSection(section)"
              >
                Retablir le texte par defaut
              </button>
            </div>
          </div>

          <div class="bg-white rounded-xl shadow-sm p-6">
            <div class="flex flex-wrap items-center justify-between gap-2 mb-1">
              <h2 class="font-semibold text-gray-900">Consignes particulieres</h2>
              <span v-if="saved === 'custom'" class="text-xs text-green-700">Enregistre</span>
            </div>
            <p class="text-xs text-gray-500 mb-3">
              Ajoutees a la fin du prompt, apres la date : preferences, habitudes, choses a savoir en ce moment.
              Hors du cache : les modifier ne coute rien.
            </p>
            <textarea
              v-model="customInstructions"
              rows="6"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm leading-relaxed focus:outline-none focus:ring-2 focus:ring-gray-900/20"
              placeholder="Ex. : Quand je parle de « la fac », il s'agit de l'ICP."
            />
            <button type="button" class="mt-2 btn-primary" :disabled="saving === 'custom'" @click="saveCustom">Enregistrer</button>
          </div>

          <div class="bg-white rounded-xl shadow-sm p-6">
            <div class="flex flex-wrap items-center justify-between gap-2 mb-1">
              <h2 class="font-semibold text-gray-900">
                Suggestions d'accueil
                <span v-if="overview.suggestions_customized" class="ml-2 text-[11px] font-medium text-indigo-700 bg-indigo-50 px-2 py-0.5 rounded-full align-middle">modifiees</span>
              </h2>
              <span v-if="saved === 'suggestions'" class="text-xs text-green-700">Enregistre</span>
            </div>
            <p class="text-xs text-gray-500 mb-3">
              Phrases proposees dans le widget a l'ouverture d'une nouvelle conversation ; un clic les envoie telles quelles.
              {{ overview.max_suggestions }} au maximum, les lignes vides sont ignorees.
            </p>
            <div class="space-y-2">
              <div v-for="(_, index) in suggestionDrafts" :key="index" class="flex items-center gap-2">
                <input
                  v-model="suggestionDrafts[index]"
                  type="text"
                  maxlength="200"
                  class="flex-1 min-w-0 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900/20"
                  placeholder="Ex. : Quelles factures sont encore impayees ?"
                />
                <button type="button" class="p-1.5 text-gray-400 hover:text-gray-700 disabled:opacity-30" title="Monter" :disabled="index === 0" @click="moveSuggestion(index, -1)">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 15l7-7 7 7" /></svg>
                </button>
                <button type="button" class="p-1.5 text-gray-400 hover:text-gray-700 disabled:opacity-30" title="Descendre" :disabled="index === suggestionDrafts.length - 1" @click="moveSuggestion(index, 1)">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7" /></svg>
                </button>
                <button type="button" class="p-1.5 text-gray-400 hover:text-red-600" title="Supprimer" @click="suggestionDrafts.splice(index, 1)">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" d="M6 6l12 12M18 6L6 18" /></svg>
                </button>
              </div>
            </div>
            <button
              v-if="suggestionDrafts.length < overview.max_suggestions"
              type="button"
              class="mt-2 text-sm text-gray-600 hover:text-gray-900"
              @click="suggestionDrafts.push('')"
            >
              + Ajouter une suggestion
            </button>
            <div class="mt-3 flex flex-wrap gap-2">
              <button type="button" class="btn-primary" :disabled="saving === 'suggestions' || !suggestionsChanged" @click="saveSuggestionList">Enregistrer</button>
              <button
                v-if="overview.suggestions_customized"
                type="button"
                class="btn-secondary"
                :disabled="saving === 'suggestions'"
                @click="resetSuggestions"
              >
                Retablir les suggestions par defaut
              </button>
            </div>
          </div>
        </div>

        <!-- Outils -->
        <div v-else-if="tab === 'tools'" class="space-y-4">
          <div class="bg-white rounded-xl shadow-sm p-6">
            <h2 class="font-semibold text-gray-900 mb-3">Connexions</h2>
            <ul class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
              <li v-for="item in integrations" :key="item.label" class="flex items-start gap-3 rounded-lg border border-gray-100 px-3 py-2">
                <span class="mt-1.5 h-2 w-2 rounded-full flex-shrink-0" :class="item.on ? 'bg-green-500' : 'bg-gray-300'" />
                <div class="min-w-0">
                  <p class="text-gray-800">{{ item.label }} <span class="text-xs text-gray-400">· {{ item.on ? 'connecte' : 'inactif' }}</span></p>
                  <p class="text-xs text-gray-500">{{ item.detail }}</p>
                </div>
              </li>
            </ul>
          </div>

          <div class="bg-white rounded-xl shadow-sm p-6">
            <h2 class="font-semibold text-gray-900 mb-1">Outils</h2>
            <p class="text-xs text-gray-500 mb-4">
              Ce qu'Alfred peut appeler pendant une reponse. Les outils « proposition » ne font rien seuls : ils creent une
              carte que vous confirmez dans le chat. La liste vient du code (<code>Alfred::Tools::ALL</code>).
            </p>
            <ul class="divide-y divide-gray-100">
              <li v-for="tool in overview.tools" :key="tool.name" class="py-3 flex items-start gap-3">
                <span class="mt-1.5 h-2 w-2 rounded-full flex-shrink-0" :class="tool.available ? 'bg-green-500' : 'bg-gray-300'" :title="tool.available ? 'Disponible' : 'Indisponible'" />
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-2">
                    <code class="text-sm text-gray-900">{{ tool.name }}</code>
                    <span class="text-[11px] px-2 py-0.5 rounded-full" :class="tool.kind === 'proposal' ? 'bg-indigo-50 text-indigo-700' : 'bg-gray-100 text-gray-600'">
                      {{ tool.kind === 'proposal' ? 'proposition' : 'lecture' }}
                    </span>
                    <span class="text-[11px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">{{ tool.integration === 'gmail' ? 'Gmail' : 'dashboard' }}</span>
                  </div>
                  <p class="text-xs text-gray-500 mt-1 leading-relaxed">{{ tool.description }}</p>
                </div>
              </li>
            </ul>
          </div>

          <div class="bg-white rounded-xl shadow-sm p-6">
            <h2 class="font-semibold text-gray-900 mb-1">Perimetre des donnees</h2>
            <p class="text-xs text-gray-500 mb-4">
              Listes blanches du code (<code>Alfred::DataAccess</code>). Jamais lisibles : mots de passe, identifiants des comptes mail, utilisateur.
            </p>
            <p class="text-xs font-medium text-gray-700 mb-2">Lecture ({{ overview.readable_models.length }})</p>
            <div class="flex flex-wrap gap-1.5 mb-4">
              <span v-for="m in overview.readable_models" :key="`r-${m}`" class="text-xs bg-gray-100 text-gray-700 px-2 py-0.5 rounded-full">{{ m }}</span>
            </div>
            <p class="text-xs font-medium text-gray-700 mb-2">Ecriture sur confirmation ({{ overview.writable_models.length }})</p>
            <div class="flex flex-wrap gap-1.5">
              <span v-for="m in overview.writable_models" :key="`w-${m}`" class="text-xs bg-indigo-50 text-indigo-700 px-2 py-0.5 rounded-full">{{ m }}</span>
            </div>
          </div>
        </div>

        <!-- Memoire -->
        <div v-else class="space-y-4">
          <div class="bg-white rounded-xl shadow-sm p-6">
            <h2 class="font-semibold text-gray-900 mb-1">Memoire documentaire</h2>
            <p class="text-xs text-gray-500 mb-4">
              Le corpus d'Alfred, c'est le dashboard lui-meme : chaque fiche et le texte de chaque document (OCR compris) sont
              indexes automatiquement a chaque modification. Rien a configurer ; la reindexation complete sert en cas de doute.
            </p>
            <dl class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
              <div>
                <dt class="text-xs text-gray-400">Fiches indexees</dt>
                <dd class="text-gray-800 text-lg font-semibold">{{ overview.corpus.records }}</dd>
              </div>
              <div>
                <dt class="text-xs text-gray-400">Passages</dt>
                <dd class="text-gray-800 text-lg font-semibold">{{ overview.corpus.chunks }}</dd>
              </div>
              <div>
                <dt class="text-xs text-gray-400">En echec</dt>
                <dd class="text-lg font-semibold" :class="overview.corpus.failed ? 'text-red-600' : 'text-gray-800'">{{ overview.corpus.failed }}</dd>
              </div>
              <div>
                <dt class="text-xs text-gray-400">Derniere indexation</dt>
                <dd class="text-gray-800 mt-1">{{ overview.corpus.last_indexed_at ? formatDateTime(overview.corpus.last_indexed_at) : 'jamais' }}</dd>
              </div>
            </dl>
            <button type="button" class="mt-4 btn-secondary" :disabled="reindexing || !overview.integrations.mistral" @click="launchReindex">
              {{ reindexing ? 'Reindexation lancee' : 'Tout reindexer' }}
            </button>
          </div>
        </div>
      </template>

      <p v-if="pageError" class="mt-4 text-sm text-red-700 bg-red-50 border border-red-100 rounded-lg px-4 py-2">{{ pageError }}</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, reactive } from 'vue'
import { useAlfred } from '../../composables/useAlfred'
import avatar from '../../images/alfred-avatar.png'

const { overview, loadOverview, saveInstructions, savePromptOverrides, saveSuggestions, loadPrompt, reindex } = useAlfred()

const tabs = [
  { key: 'instructions', label: 'Instructions' },
  { key: 'tools', label: 'Outils et connexions' },
  { key: 'memory', label: 'Memoire' },
]

const tab = ref('instructions')
const loading = ref(true)
const pageError = ref(null)
const drafts = reactive({})
const customInstructions = ref('')
const suggestionDrafts = ref([])
const saving = ref(null)
const saved = ref(null)
const preview = ref(null)
const reindexing = ref(false)

const currentText = (section) => section.override || section.default

const overriddenCount = computed(() => (overview.value?.prompt_sections || []).filter((s) => s.override).length)

const integrations = computed(() => {
  const i = overview.value?.integrations || {}
  return [
    { label: 'Claude (agent)', on: i.anthropic, detail: 'ANTHROPIC_API_KEY : le modele qui repond et appelle les outils.' },
    { label: 'Mistral (memoire)', on: i.mistral, detail: 'MISTRAL_API_KEY : embeddings de la recherche et OCR des scans.' },
    { label: 'Gmail', on: i.gmail, detail: i.gmail ? `Boite ${i.gmail_user}, lue en direct (rien n'est copie).` : 'GMAIL_USER absent : les outils mail repondent une erreur.' },
    { label: 'Google Agenda', on: i.google_calendar, detail: 'Par ricochet : l\'agenda du dashboard est le miroir de Google Agenda.' },
  ]
})

const syncDrafts = () => {
  for (const section of overview.value.prompt_sections) drafts[section.key] = currentText(section)
  customInstructions.value = overview.value.custom_instructions || ''
  suggestionDrafts.value = [...overview.value.suggestions]
}

const flash = (key) => {
  saved.value = key
  setTimeout(() => { if (saved.value === key) saved.value = null }, 2000)
}

const withSaving = async (key, fn) => {
  saving.value = key
  pageError.value = null
  try {
    await fn()
    syncDrafts()
    if (preview.value !== null) preview.value = await loadPrompt()
    flash(key)
  } catch (err) {
    pageError.value = err.response?.data?.error || 'Enregistrement impossible.'
  } finally {
    saving.value = null
  }
}

// Un texte identique au defaut n'est pas stocke comme surcharge.
const saveSection = (section) => withSaving(section.key, async () => {
  const text = drafts[section.key].trim()
  await savePromptOverrides({ [section.key]: text === section.default ? null : text })
})

const resetSection = (section) => withSaving(section.key, async () => {
  await savePromptOverrides({ [section.key]: null })
})

const saveCustom = () => withSaving('custom', () => saveInstructions(customInstructions.value))

const cleanSuggestions = () => suggestionDrafts.value.map((text) => text.trim()).filter(Boolean)

const suggestionsChanged = computed(() =>
  JSON.stringify(cleanSuggestions()) !== JSON.stringify(overview.value?.suggestions || []))

const moveSuggestion = (index, offset) => {
  const list = suggestionDrafts.value
  ;[list[index], list[index + offset]] = [list[index + offset], list[index]]
}

// Une liste videe revient aux suggestions par defaut, comme le bouton de retablissement.
const saveSuggestionList = () => withSaving('suggestions', () => saveSuggestions(cleanSuggestions()))

const resetSuggestions = () => withSaving('suggestions', () => saveSuggestions([]))

const togglePreview = async () => {
  preview.value = preview.value === null ? await loadPrompt() : null
}

const launchReindex = async () => {
  reindexing.value = true
  await reindex()
}

const rowsFor = (text) => Math.min(24, Math.max(4, (text || '').split('\n').length + 1))

const formatDateTime = (value) =>
  (value ? new Date(value).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '')

onMounted(async () => {
  try {
    await loadOverview()
    syncDrafts()
  } catch (err) {
    pageError.value = err.response?.data?.error || 'Impossible de charger Alfred.'
  } finally {
    loading.value = false
  }
})
</script>

<style scoped>
.btn-primary {
  @apply px-3 py-1.5 rounded-lg bg-gray-900 text-white text-xs hover:bg-gray-700 disabled:opacity-40 disabled:cursor-not-allowed;
}
.btn-secondary {
  @apply px-3 py-1.5 rounded-lg border border-gray-300 text-xs text-gray-700 hover:bg-gray-50 disabled:opacity-40 disabled:cursor-not-allowed;
}
</style>
