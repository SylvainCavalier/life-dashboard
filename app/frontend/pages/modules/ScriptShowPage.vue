<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <div class="flex items-center justify-between gap-3 mb-4">
        <router-link :to="backLink" class="text-sm text-gray-400 hover:text-gray-600">&larr; {{ form.script_folder_id ? folderName : 'Mes scripts' }}</router-link>
        <div class="flex items-center gap-3">
          <span class="text-xs" :class="saveLabel.class">{{ saveLabel.text }}</span>
          <button v-if="loaded" @click="deleteScript" class="text-red-400 hover:text-red-600" title="Supprimer le script">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>

      <div v-if="notFound" class="text-center text-gray-400 py-12">Ce script n'existe plus.</div>

      <template v-else-if="loaded">
        <ul v-if="errors.length" class="mb-4 text-sm text-red-600 list-disc list-inside">
          <li v-for="error in errors" :key="error">{{ error }}</li>
        </ul>

        <input
          ref="titleInput"
          v-model="form.title"
          type="text"
          maxlength="250"
          class="w-full bg-transparent text-2xl font-bold text-gray-900 border-0 border-b border-transparent focus:border-gray-300 focus:ring-0 px-0 mb-4"
          placeholder="Titre du script"
        />

        <!-- Classement et suivi -->
        <div class="bg-white rounded-xl shadow-sm p-4 mb-4 grid grid-cols-2 md:grid-cols-4 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-500 mb-1">Chaîne / compte</label>
            <select v-model="form.script_folder_id" class="w-full border rounded-lg px-2 py-1.5 text-sm">
              <option :value="null">Non classé</option>
              <option v-for="folder in folders" :key="folder.id" :value="folder.id">{{ platformOf(folder.platform).icon }} {{ folder.name }}</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-500 mb-1">Format</label>
            <select v-model="form.kind" class="w-full border rounded-lg px-2 py-1.5 text-sm">
              <option v-for="k in kinds" :key="k.value" :value="k.value">{{ k.icon }} {{ k.label }}</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-500 mb-1">Statut</label>
            <select v-model="form.status" class="w-full border rounded-lg px-2 py-1.5 text-sm">
              <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-500 mb-1">Publication prévue</label>
            <input v-model="form.planned_on" type="date" class="w-full border rounded-lg px-2 py-1.5 text-sm" />
          </div>
          <template v-if="form.status === 'published' || form.published_on || form.published_url">
            <div>
              <label class="block text-xs font-medium text-gray-500 mb-1">Publié le</label>
              <input v-model="form.published_on" type="date" class="w-full border rounded-lg px-2 py-1.5 text-sm" />
            </div>
            <div class="col-span-2 md:col-span-3">
              <label class="block text-xs font-medium text-gray-500 mb-1">Lien de la publication</label>
              <div class="flex gap-2">
                <input v-model="form.published_url" type="url" class="flex-1 min-w-0 border rounded-lg px-2 py-1.5 text-sm" placeholder="https://..." />
                <a v-if="form.published_url" :href="form.published_url" target="_blank" rel="noopener" class="text-sm text-indigo-600 hover:underline self-center">Ouvrir</a>
              </div>
            </div>
          </template>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-4">
          <!-- Texte -->
          <div class="bg-white rounded-xl shadow-sm p-5">
            <div class="flex flex-wrap items-center justify-between gap-2 mb-3">
              <p class="text-xs text-gray-400">
                <template v-if="isThread">Une ligne <code class="bg-gray-100 px-1 rounded">---</code> sépare deux messages du thread.</template>
                <template v-else>Enregistrement automatique (⌘S pour forcer).</template>
              </p>
              <div class="flex items-center gap-2">
                <button v-if="isThread" type="button" @click="insertSeparator" class="text-xs px-2.5 py-1 rounded-lg border border-gray-200 text-gray-600 hover:border-gray-400">
                  + Message suivant
                </button>
                <VoiceInputButton size="sm" @transcribed="insertDictation" />
              </div>
            </div>
            <textarea
              ref="bodyInput"
              v-model="form.body"
              @input="autoResize"
              class="w-full min-h-[60vh] border-0 focus:ring-0 p-0 text-base leading-relaxed text-gray-800 resize-none"
              :placeholder="isThread ? 'Premier message du thread...\n\n---\n\nDeuxième message...' : 'Écrivez votre script...'"
            ></textarea>
          </div>

          <aside class="space-y-4">
            <!-- Compteurs -->
            <div class="bg-white rounded-xl shadow-sm p-4 grid grid-cols-2 gap-3">
              <div>
                <p class="text-xs text-gray-500">Mots</p>
                <p class="text-xl font-semibold text-gray-900">{{ words.toLocaleString('fr-FR') }}</p>
              </div>
              <div>
                <p class="text-xs text-gray-500">Caractères</p>
                <p class="text-xl font-semibold text-gray-900">{{ chars.toLocaleString('fr-FR') }}</p>
              </div>
              <div v-if="isThread">
                <p class="text-xs text-gray-500">Messages</p>
                <p class="text-xl font-semibold text-gray-900">{{ posts.length }}</p>
              </div>
              <div v-else>
                <p class="text-xs text-gray-500">Durée lue</p>
                <p class="text-xl font-semibold text-gray-900">≈ {{ formatDuration(estimatedSeconds(words)) }}</p>
              </div>
              <div v-if="isThread && tooLong.length" class="col-span-2 text-xs text-red-600">
                {{ tooLong.length }} message{{ tooLong.length > 1 ? 's dépassent' : ' dépasse' }} {{ POST_MAX_CHARS }} caractères
              </div>
              <p v-if="!isThread" class="col-span-2 text-xs text-gray-400">Estimation à {{ WORDS_PER_MINUTE }} mots par minute, face caméra.</p>
            </div>

            <!-- Notes -->
            <div class="bg-white rounded-xl shadow-sm p-4">
              <label class="block text-xs font-medium text-gray-500 mb-1">Notes, sources, idées</label>
              <textarea v-model="form.notes" rows="8" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Liens, références, plans de coupe, idées de miniature..."></textarea>
            </div>

            <!-- Apercu du thread -->
            <div v-if="isThread && posts.length" class="space-y-2">
              <p class="text-xs font-medium uppercase tracking-wide text-gray-400">Aperçu du thread</p>
              <div v-for="(post, i) in posts" :key="i" class="bg-white rounded-xl shadow-sm p-3">
                <div class="flex justify-between text-xs mb-1">
                  <span class="text-gray-400">{{ i + 1 }}/{{ posts.length }}</span>
                  <span :class="charCount(post) > POST_MAX_CHARS ? 'text-red-600 font-medium' : 'text-gray-400'">{{ charCount(post) }}/{{ POST_MAX_CHARS }}</span>
                </div>
                <p class="text-sm text-gray-800 whitespace-pre-line break-words">{{ post }}</p>
              </div>
            </div>

            <p class="text-xs text-gray-400">Créé le {{ formatTimestamp(meta.created_at) }} · modifié le {{ formatTimestamp(meta.updated_at) }}</p>
          </aside>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, nextTick, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router'
import apiClient from '../../plugins/axios'
import {
  kinds, statuses, platformOf, wordCount, charCount, estimatedSeconds, formatDuration, splitThread,
  THREAD_SEPARATOR, WORDS_PER_MINUTE, POST_MAX_CHARS,
} from '../../composables/useScripts'
import { insertAtCursor } from '../../composables/useVoiceRecorder'
import VoiceInputButton from '../../components/VoiceInputButton.vue'

const FIELDS = ['title', 'script_folder_id', 'kind', 'status', 'body', 'notes', 'planned_on', 'published_on', 'published_url']
const AUTOSAVE_DELAY = 1200

const route = useRoute()
const router = useRouter()

const form = reactive(Object.fromEntries(FIELDS.map(field => [field, null])))
const meta = ref({})
const folders = ref([])
const loaded = ref(false)
const notFound = ref(false)
const errors = ref([])
const titleInput = ref(null)
const bodyInput = ref(null)

// saved | dirty | saving | error. `revision` compte les modifications : une reponse
// du serveur ne marque « enregistre » que si rien n'a change pendant l'envoi.
const saveState = ref('saved')
let revision = 0
let timer = null
let inFlight = null
let applyingServer = false

const isThread = computed(() => form.kind === 'thread')
const words = computed(() => wordCount(form.body || ''))
const chars = computed(() => charCount(form.body || ''))
const posts = computed(() => (isThread.value ? splitThread(form.body || '') : []))
const tooLong = computed(() => posts.value.filter(post => charCount(post) > POST_MAX_CHARS))

const folderName = computed(() => folders.value.find(f => f.id === form.script_folder_id)?.name || 'Mes scripts')
const backLink = computed(() => (form.script_folder_id ? { path: '/scripts', query: { folder: String(form.script_folder_id) } } : '/scripts'))

const saveLabel = computed(() => ({
  saved: { text: 'Enregistré', class: 'text-gray-400' },
  dirty: { text: 'Modifications en attente...', class: 'text-gray-400' },
  saving: { text: 'Enregistrement...', class: 'text-gray-400' },
  error: { text: 'Échec de l\'enregistrement', class: 'text-red-600 font-medium' },
}[saveState.value]))

const formatTimestamp = (iso) => (iso ? new Date(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }) : '')

const save = async () => {
  clearTimeout(timer)
  if (inFlight) {
    await inFlight
    if (saveState.value === 'dirty') return save()
    return
  }
  if (saveState.value === 'saved') return

  const sent = revision
  const payload = Object.fromEntries(FIELDS.map(field => [field, form[field] ?? '']))
  payload.script_folder_id = form.script_folder_id || null
  saveState.value = 'saving'
  inFlight = (async () => {
    try {
      const { data } = await apiClient.patch(`/scripts/${route.params.id}`, { script: payload })
      meta.value = data
      errors.value = []
      // Le serveur date la publication quand le statut passe a « publie ».
      if (!form.published_on && data.published_on) {
        applyingServer = true
        form.published_on = data.published_on
        await nextTick()
        applyingServer = false
      }
      saveState.value = revision === sent ? 'saved' : 'dirty'
    } catch (e) {
      errors.value = e.response?.data?.errors || ['Enregistrement impossible']
      saveState.value = 'error'
    } finally {
      inFlight = null
    }
  })()
  await inFlight
  if (saveState.value === 'dirty') schedule()
}

const schedule = () => {
  clearTimeout(timer)
  timer = setTimeout(save, AUTOSAVE_DELAY)
}

watch(form, () => {
  if (!loaded.value || applyingServer) return
  revision += 1
  if (saveState.value !== 'saving') saveState.value = 'dirty'
  schedule()
}, { deep: true })

const autoResize = () => {
  const el = bodyInput.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
}

const insertSeparator = () => {
  const el = bodyInput.value
  const value = form.body || ''
  const at = el ? el.selectionEnd ?? value.length : value.length
  const before = value.slice(0, at).replace(/\s+$/, '')
  const after = value.slice(at).replace(/^\s+/, '')
  form.body = `${before}${THREAD_SEPARATOR}${after}`
  const caret = before.length + THREAD_SEPARATOR.length
  nextTick(() => {
    autoResize()
    if (!el) return
    el.focus()
    el.setSelectionRange(caret, caret)
  })
}

const insertDictation = (text) => {
  form.body = insertAtCursor(bodyInput.value, form.body, text)
  nextTick(autoResize)
}

const deleteScript = async () => {
  if (!confirm(`Supprimer définitivement le script « ${form.title} » ?`)) return
  clearTimeout(timer)
  await apiClient.delete(`/scripts/${route.params.id}`)
  saveState.value = 'saved'
  router.push(backLink.value)
}

const onKeydown = (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key === 's') {
    event.preventDefault()
    save()
  }
}

const pending = () => ['dirty', 'saving', 'error'].includes(saveState.value)

const beforeUnload = (event) => {
  if (!pending()) return
  save()
  event.preventDefault()
  event.returnValue = ''
}

onBeforeRouteLeave(async () => {
  if (pending()) await save()
  if (saveState.value === 'error') return confirm('Le script n\'a pas pu être enregistré. Quitter quand même ?')
  return true
})

onMounted(async () => {
  window.addEventListener('keydown', onKeydown)
  window.addEventListener('beforeunload', beforeUnload)
  try {
    const [script, folderData] = await Promise.all([
      apiClient.get(`/scripts/${route.params.id}`).then(r => r.data),
      apiClient.get('/script_folders').then(r => r.data),
    ])
    folders.value = folderData.folders || []
    meta.value = script
    FIELDS.forEach(field => { form[field] = script[field] ?? (field === 'script_folder_id' ? null : '') })
    await nextTick()
    loaded.value = true
    await nextTick()
    autoResize()
    // Script tout juste cree depuis la liste : on commence par le titre.
    if (route.query.new) {
      titleInput.value?.select()
      router.replace({ query: {} })
    }
  } catch (e) {
    if (e.response?.status === 404) notFound.value = true
    else throw e
  }
})

onBeforeUnmount(() => {
  clearTimeout(timer)
  window.removeEventListener('keydown', onKeydown)
  window.removeEventListener('beforeunload', beforeUnload)
})
</script>
