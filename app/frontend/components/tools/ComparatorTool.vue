<template>
  <div>
    <!-- Comme l'onglet Videos, cet outil passe par le serveur : Mistral ne tourne pas dans le navigateur -->
    <div v-if="loaded && !enabled" class="bg-amber-50 border border-amber-100 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
      Comparateur indisponible : la clé <code>MISTRAL_API_KEY</code> n'est pas configurée sur ce serveur.
    </div>

    <!-- Choix des deux documents -->
    <div v-if="!current" class="bg-white rounded-xl shadow-sm p-5 mb-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div v-for="slot in SLOTS" :key="slot.key">
          <p class="text-sm font-medium text-gray-700 mb-2">{{ slot.label }}</p>
          <FileDropZone
            v-if="!files[slot.key]"
            accept="application/pdf"
            icon="📄"
            label="Cliquez ou glissez un PDF ici"
            :hint="`PDF, ${maxSizeLabel} maximum. Les scans sont lus par OCR.`"
            note="Envoyé au serveur pour être lu par Mistral, puis supprimé : seul le résultat est gardé."
            @file="pick(slot.key, $event)"
          />
          <div v-else class="border rounded-xl p-4 flex items-center gap-3">
            <span class="text-2xl">📄</span>
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-gray-800 truncate">{{ files[slot.key].name }}</p>
              <p class="text-xs text-gray-400">{{ humanSize(files[slot.key].size) }}</p>
              <div v-if="progress[slot.key] !== null" class="h-1.5 bg-gray-100 rounded-full overflow-hidden mt-2">
                <div class="h-full bg-gray-900 transition-all" :style="{ width: `${progress[slot.key]}%` }"></div>
              </div>
            </div>
            <button v-if="!submitting" class="text-xs text-gray-500 hover:text-gray-700" @click="files[slot.key] = null">Changer</button>
          </div>
        </div>
      </div>

      <label class="block text-sm font-medium text-gray-700 mt-5 mb-1">Points à examiner en priorité <span class="text-gray-400 font-normal">(facultatif)</span></label>
      <textarea
        v-model="focus"
        rows="2"
        maxlength="1000"
        placeholder="Ex. : clauses de non-concurrence et de mobilité, rémunération variable"
        class="w-full border rounded-lg px-3 py-2 text-sm"
      ></textarea>

      <p v-if="formError" class="text-sm text-red-600 mt-3">{{ formError }}</p>

      <div class="flex justify-end mt-4">
        <button
          class="bg-gray-900 text-white text-sm px-5 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
          :disabled="!files.a || !files.b || submitting || !enabled"
          @click="submit"
        >
          {{ submitting ? 'Envoi...' : 'Comparer' }}
        </button>
      </div>
    </div>

    <!-- Comparaison en cours, en echec ou terminee -->
    <div v-else class="bg-white rounded-xl shadow-sm p-5 mb-6">
      <div class="flex items-start justify-between gap-4 mb-4">
        <div class="min-w-0">
          <p class="text-xs text-gray-400">Comparaison du {{ formatDate(current.created_at) }}</p>
          <h2 class="text-lg font-semibold text-gray-900 break-words">
            <span class="text-indigo-600">A</span> {{ current.name_a }} <span class="text-gray-300 mx-1">/</span>
            <span class="text-emerald-600">B</span> {{ current.name_b }}
          </h2>
          <p v-if="current.focus" class="text-xs text-gray-500 mt-1">Consigne : {{ current.focus }}</p>
        </div>
        <div class="flex gap-2 flex-shrink-0">
          <button v-if="result" class="text-sm text-gray-600 bg-gray-100 hover:bg-gray-200 px-3 py-1.5 rounded-lg" @click="copy">
            {{ copied ? 'Copié' : 'Copier' }}
          </button>
          <button class="text-sm text-white bg-gray-900 hover:bg-gray-800 px-3 py-1.5 rounded-lg" @click="reset">Nouvelle comparaison</button>
        </div>
      </div>

      <div v-if="current.in_progress" class="py-8 text-center">
        <div class="w-6 h-6 border-2 border-gray-900 border-t-transparent rounded-full animate-spin mx-auto"></div>
        <p class="text-sm text-gray-500 mt-3">Lecture et comparaison par Mistral (jusqu'à une minute ou deux pour de longs documents ou des scans)...</p>
      </div>

      <p v-else-if="current.status === 'failed'" class="text-sm text-red-600 py-4">{{ current.error || 'La comparaison a échoué' }}</p>

      <div v-else-if="result" class="space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
          <p class="bg-indigo-50 text-indigo-900 rounded-lg px-3 py-2"><strong>A</strong> · {{ result.title_a || current.name_a }}</p>
          <p class="bg-emerald-50 text-emerald-900 rounded-lg px-3 py-2"><strong>B</strong> · {{ result.title_b || current.name_b }}</p>
        </div>

        <div>
          <span class="inline-block text-xs font-medium bg-gray-100 text-gray-700 rounded-full px-2.5 py-0.5 mb-2">{{ RELATIONSHIPS[result.relationship] }}</span>
          <p class="text-base font-medium text-gray-900">{{ result.verdict }}</p>
          <p v-for="(paragraph, index) in paragraphs(result.summary)" :key="index" class="text-sm text-gray-700 mt-2 leading-relaxed">{{ paragraph }}</p>
        </div>

        <p v-if="result.truncated" class="text-xs text-amber-700 bg-amber-50 rounded-lg px-3 py-2">
          Document très long : seule sa première partie (environ 100 000 caractères) a été comparée.
        </p>

        <div v-if="result.attention_points?.length" class="bg-amber-50 border border-amber-100 rounded-lg px-4 py-3">
          <h3 class="text-sm font-semibold text-amber-900 mb-1">Points d'attention</h3>
          <ul class="list-disc pl-5 text-sm text-amber-900 space-y-1">
            <li v-for="(point, index) in result.attention_points" :key="index">{{ point }}</li>
          </ul>
        </div>

        <div v-if="result.differences?.length">
          <h3 class="text-sm font-semibold text-gray-900 mb-2">Différences ({{ result.differences.length }})</h3>
          <div class="border rounded-lg divide-y">
            <div v-for="(difference, index) in result.differences" :key="index" class="p-3">
              <div class="flex items-center gap-2 mb-2">
                <span class="text-xs font-medium rounded-full px-2 py-0.5" :class="IMPORTANCES[difference.importance].class">{{ IMPORTANCES[difference.importance].label }}</span>
                <span class="text-sm font-medium text-gray-900">{{ difference.topic }}</span>
              </div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
                <p class="text-gray-700"><span class="text-indigo-600 font-semibold mr-1">A</span>{{ difference.document_a }}</p>
                <p class="text-gray-700"><span class="text-emerald-600 font-semibold mr-1">B</span>{{ difference.document_b }}</p>
              </div>
            </div>
          </div>
        </div>

        <div v-if="result.only_in_a?.length || result.only_in_b?.length" class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <h3 class="text-sm font-semibold text-indigo-700 mb-1">Seulement dans A</h3>
            <ul v-if="result.only_in_a.length" class="list-disc pl-5 text-sm text-gray-700 space-y-1">
              <li v-for="(item, index) in result.only_in_a" :key="index">{{ item }}</li>
            </ul>
            <p v-else class="text-sm text-gray-400">Rien</p>
          </div>
          <div>
            <h3 class="text-sm font-semibold text-emerald-700 mb-1">Seulement dans B</h3>
            <ul v-if="result.only_in_b.length" class="list-disc pl-5 text-sm text-gray-700 space-y-1">
              <li v-for="(item, index) in result.only_in_b" :key="index">{{ item }}</li>
            </ul>
            <p v-else class="text-sm text-gray-400">Rien</p>
          </div>
        </div>

        <div v-if="result.similarities?.length">
          <h3 class="text-sm font-semibold text-gray-900 mb-2">Points communs</h3>
          <ul class="space-y-1 text-sm text-gray-700">
            <li v-for="(similarity, index) in result.similarities" :key="index">
              <span class="font-medium text-gray-900">{{ similarity.topic }}</span> : {{ similarity.detail }}
            </li>
          </ul>
        </div>
      </div>
    </div>

    <!-- Historique -->
    <div v-if="history.length" class="bg-white rounded-xl shadow-sm p-5">
      <h3 class="text-sm font-semibold text-gray-900 mb-3">Comparaisons récentes</h3>
      <ul class="divide-y">
        <li v-for="item in history" :key="item.id" class="py-2 flex items-center gap-3">
          <button class="flex-1 min-w-0 text-left" @click="show(item)">
            <p class="text-sm truncate" :class="current?.id === item.id ? 'text-indigo-600 font-medium' : 'text-gray-800'">
              {{ item.name_a }} / {{ item.name_b }}
            </p>
            <p class="text-xs text-gray-400 truncate">
              {{ formatDate(item.created_at) }}
              <template v-if="item.in_progress"> · en cours</template>
              <template v-else-if="item.status === 'failed'"> · en échec</template>
              <template v-else-if="item.result?.verdict"> · {{ item.result.verdict }}</template>
            </p>
          </button>
          <button class="text-xs text-gray-400 hover:text-red-600" title="Supprimer" @click="remove(item)">Supprimer</button>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { useApi } from '../../composables/useApi'
import { useDirectUpload } from '../../composables/useDirectUpload'
import FileDropZone from './FileDropZone.vue'
import { humanSize } from './files'

const { get, post, delete: del } = useApi()
const { uploadFile } = useDirectUpload()

const SLOTS = [
  { key: 'a', label: 'Document A' },
  { key: 'b', label: 'Document B' },
]
const RELATIONSHIPS = {
  identical: 'Documents identiques',
  versions: "Deux versions d'un même document",
  same_kind: 'Documents de même nature',
  different: 'Documents distincts',
}
const IMPORTANCES = {
  high: { label: 'Importante', class: 'bg-red-50 text-red-700' },
  medium: { label: 'Notable', class: 'bg-amber-50 text-amber-700' },
  low: { label: 'Mineure', class: 'bg-gray-100 text-gray-600' },
}
const POLL_MS = 2000

const loaded = ref(false)
const enabled = ref(true)
const maxBytes = ref(45 * 1024 * 1024)
const history = ref([])
const files = reactive({ a: null, b: null })
const progress = reactive({ a: null, b: null })
const focus = ref('')
const submitting = ref(false)
const formError = ref('')
const current = ref(null)
const copied = ref(false)
let pollTimer = null

const result = computed(() => current.value?.result)
const maxSizeLabel = computed(() => humanSize(maxBytes.value))

const formatDate = (value) => new Date(value).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })
const paragraphs = (text) => (text || '').split(/\n+/).map(p => p.trim()).filter(Boolean)

const pick = (key, file) => {
  formError.value = ''
  if (file.type !== 'application/pdf') {
    formError.value = 'Seuls les PDF sont acceptés.'
    return
  }
  if (file.size > maxBytes.value) {
    formError.value = `« ${file.name} » dépasse ${maxSizeLabel.value}.`
    return
  }
  files[key] = file
}

const loadHistory = async () => {
  const data = await get('/document_comparisons')
  enabled.value = data.enabled
  maxBytes.value = data.max_bytes
  history.value = data.comparisons
  loaded.value = true
}

const submit = async () => {
  submitting.value = true
  formError.value = ''
  try {
    const [blobA, blobB] = await Promise.all(SLOTS.map(({ key }) =>
      uploadFile(files[key], (percent) => { progress[key] = percent })
    ))
    const created = await post('/document_comparisons', { file_a: blobA.signed_id, file_b: blobB.signed_id, focus: focus.value })
    history.value = [created, ...history.value]
    show(created)
    files.a = null
    files.b = null
    focus.value = ''
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || "L'envoi des documents a échoué"
  } finally {
    submitting.value = false
    progress.a = null
    progress.b = null
  }
}

const show = (comparison) => {
  clearTimeout(pollTimer)
  current.value = comparison
  copied.value = false
  if (comparison.in_progress) pollTimer = setTimeout(poll, POLL_MS)
}

const poll = async () => {
  const id = current.value?.id
  if (!id) return
  try {
    const data = await get(`/document_comparisons/${id}`)
    history.value = history.value.map(item => (item.id === id ? data : item))
    if (current.value?.id !== id) return
    current.value = data
    if (data.in_progress) pollTimer = setTimeout(poll, POLL_MS)
  } catch {
    pollTimer = setTimeout(poll, POLL_MS * 3)
  }
}

const reset = () => {
  clearTimeout(pollTimer)
  current.value = null
}

const remove = async (comparison) => {
  await del(`/document_comparisons/${comparison.id}`)
  history.value = history.value.filter(item => item.id !== comparison.id)
  if (current.value?.id === comparison.id) reset()
}

// Texte brut, a coller dans un mail ou une note.
const asText = () => {
  const r = result.value
  const c = current.value
  const lines = [
    `Comparaison : A = ${r.title_a || c.name_a} (${c.name_a}) / B = ${r.title_b || c.name_b} (${c.name_b})`,
    '',
    r.verdict,
    '',
    r.summary,
  ]
  const section = (title, items) => {
    if (!items?.length) return
    lines.push('', title, ...items.map(item => `- ${item}`))
  }
  section("Points d'attention", r.attention_points)
  section('Différences', r.differences?.map(d => `${d.topic} [${IMPORTANCES[d.importance].label}]\n  A : ${d.document_a}\n  B : ${d.document_b}`))
  section('Seulement dans A', r.only_in_a)
  section('Seulement dans B', r.only_in_b)
  section('Points communs', r.similarities?.map(s => `${s.topic} : ${s.detail}`))
  return lines.join('\n')
}

const copy = async () => {
  await navigator.clipboard.writeText(asText())
  copied.value = true
  setTimeout(() => { copied.value = false }, 2000)
}

onMounted(async () => {
  try {
    await loadHistory()
    const running = history.value.find(item => item.in_progress)
    if (running) show(running)
  } catch {
    loaded.value = true
  }
})

onBeforeUnmount(() => clearTimeout(pollTimer))
</script>
