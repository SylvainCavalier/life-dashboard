<template>
  <div class="bg-white rounded-xl shadow-sm p-5">
    <div class="flex items-center justify-between mb-1">
      <h2 class="text-lg font-semibold text-gray-900">Journal de bord</h2>
      <button @click="toggleForm" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
        {{ showForm ? 'Fermer' : '+ Consigner' }}
      </button>
    </div>
    <p class="text-xs text-gray-400 mb-4">
      Ce qui a été fait, décidé ou appris, et quand. Alfred peut le tenir pour vous : racontez-lui votre journée.
    </p>

    <form v-if="showForm" @submit.prevent="save" class="bg-gray-50 rounded-lg p-4 mb-5 space-y-3">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div>
          <label class="block text-xs text-gray-500 mb-1">Date *</label>
          <input v-model="form.occurred_on" type="date" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Type</label>
          <select v-model="form.kind" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
            <option v-for="k in projectEntryKinds" :key="k.value" :value="k.value">{{ k.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Contact</label>
          <select v-model="form.contact_id" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
            <option :value="null">— Aucun —</option>
            <option v-for="c in contacts" :key="c.id" :value="c.id">{{ contactFullName(c) }}</option>
          </select>
        </div>
      </div>
      <div>
        <label class="block text-xs text-gray-500 mb-1">Titre *</label>
        <input v-model="form.title" type="text" required maxlength="200" placeholder="Rendez-vous avec le pôle de compétitivité..." class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
      </div>
      <div>
        <div class="flex items-center justify-between mb-1">
          <label class="block text-xs text-gray-500">Détails</label>
          <VoiceInputButton size="sm" @transcribed="insertDictation" />
        </div>
        <textarea ref="bodyInput" v-model="form.body" rows="4" placeholder="Ce qui s'est passé, ce qui a été dit, ce qu'il en ressort... (ou dictez avec le micro)" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white"></textarea>
      </div>
      <p v-if="error" class="text-xs text-red-600">{{ error }}</p>
      <div class="flex gap-2">
        <button type="submit" :disabled="saving" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium disabled:opacity-50">
          {{ editingId ? 'Enregistrer' : 'Ajouter au journal' }}
        </button>
        <button v-if="editingId" type="button" @click="resetForm" class="bg-gray-200 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">
          Annuler
        </button>
      </div>
    </form>

    <div v-if="groups.length" class="space-y-5">
      <div v-for="group in groups" :key="group.key">
        <h3 class="text-xs font-semibold uppercase tracking-wide text-gray-400 mb-2">{{ group.label }}</h3>
        <ol class="relative border-l border-gray-200 ml-1.5 space-y-4">
          <li v-for="entry in group.entries" :key="entry.id" class="ml-4 group">
            <span class="absolute -left-[5px] mt-1.5 h-2.5 w-2.5 rounded-full ring-2 ring-white" :class="entryKindDot(entry.kind)"></span>
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2 text-xs">
                  <time class="text-gray-500 font-medium">{{ formatDay(entry.occurred_on) }}</time>
                  <span :class="entryKindBadge(entry.kind)" class="px-2 py-0.5 rounded-full font-medium">{{ entryKindLabel(entry.kind) }}</span>
                  <span v-if="entry.contact_name" class="text-gray-500">avec {{ entry.contact_name }}</span>
                </div>
                <p class="text-sm font-medium text-gray-900 mt-1">{{ entry.title }}</p>
                <p v-if="entry.body" class="text-sm text-gray-600 mt-1 whitespace-pre-line break-words">{{ entry.body }}</p>
              </div>
              <div class="flex gap-1 flex-shrink-0 md:opacity-0 md:group-hover:opacity-100 transition-opacity">
                <button @click="edit(entry)" class="text-gray-400 hover:text-blue-600 p-1" title="Modifier">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                </button>
                <button @click="remove(entry)" class="text-gray-400 hover:text-red-500 p-1" title="Supprimer">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                </button>
              </div>
            </div>
          </li>
        </ol>
      </div>
    </div>
    <p v-else-if="!showForm" class="text-sm text-gray-400 text-center py-2">Rien de consigné pour l'instant</p>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { useProjects, projectEntryKinds } from '../../composables/useProjects'
import { contactFullName } from '../../composables/useCrm'
import { insertAtCursor } from '../../composables/useVoiceRecorder'
import VoiceInputButton from '../VoiceInputButton.vue'

// contacts : contacts lies au projet, proposes comme interlocuteur d'une entree.
const props = defineProps({
  projectId: { type: [Number, String], required: true },
  contacts: { type: Array, default: () => [] },
})

const emit = defineEmits(['changed'])

const { get, post, patch, delete: del } = useApi()
const { entryKindLabel, entryKindBadge, entryKindDot } = useProjects()

const entries = ref([])
const showForm = ref(false)
const editingId = ref(null)
const saving = ref(false)
const error = ref('')
const bodyInput = ref(null)

// Date locale (et non UTC) : une entree saisie a 0 h 30 reste du jour.
const today = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const blankForm = () => ({ occurred_on: today(), kind: 'travail', title: '', body: '', contact_id: null })
const form = reactive(blankForm())

const base = computed(() => `/projects/${props.projectId}/project_entries`)

const groups = computed(() => {
  const byMonth = new Map()
  entries.value.forEach((entry) => {
    const key = entry.occurred_on.slice(0, 7)
    if (!byMonth.has(key)) byMonth.set(key, [])
    byMonth.get(key).push(entry)
  })
  return [...byMonth.entries()].map(([key, list]) => {
    const [year, month] = key.split('-').map(Number)
    const label = new Date(year, month - 1, 1).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })
    return { key, label, entries: list }
  })
})

const formatDay = (date) => {
  const [year, month, day] = date.split('-').map(Number)
  return new Date(year, month - 1, day).toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' })
}

const fetchEntries = async () => {
  entries.value = await get(base.value) || []
  emit('changed', entries.value)
}

const resetForm = () => {
  Object.assign(form, blankForm())
  editingId.value = null
  error.value = ''
}

const toggleForm = () => {
  if (showForm.value) resetForm()
  showForm.value = !showForm.value
}

const edit = (entry) => {
  Object.assign(form, {
    occurred_on: entry.occurred_on,
    kind: entry.kind,
    title: entry.title,
    body: entry.body || '',
    contact_id: entry.contact_id,
  })
  editingId.value = entry.id
  error.value = ''
  showForm.value = true
}

const save = async () => {
  saving.value = true
  error.value = ''
  const payload = { project_entry: { ...form, body: form.body || null } }
  try {
    if (editingId.value) {
      await patch(`${base.value}/${editingId.value}`, payload)
    } else {
      await post(base.value, payload)
    }
    resetForm()
    showForm.value = false
    await fetchEntries()
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Enregistrement impossible'
  } finally {
    saving.value = false
  }
}

const remove = async (entry) => {
  if (!confirm('Supprimer cette entrée du journal ?')) return
  try {
    await del(`${base.value}/${entry.id}`)
    await fetchEntries()
  } catch (e) {
    alert('Suppression impossible')
  }
}

const insertDictation = (text) => {
  form.body = insertAtCursor(bodyInput.value, form.body, text)
}

onMounted(fetchEntries)

defineExpose({ refresh: fetchEntries })
</script>
