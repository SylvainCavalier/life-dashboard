<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Notes</h1>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouvelle note
        </button>
      </div>

      <!-- Formulaire -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold mb-4">{{ editingId ? 'Modifier la note' : 'Nouvelle note' }}</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Titre *</label>
            <input v-model="form.title" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Titre de la note" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
            <input v-model="form.note_date" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Contenu</label>
          <textarea v-model="form.content" rows="5" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Contenu de la note..."></textarea>
        </div>
        <div class="flex items-center justify-between">
          <label class="flex items-center gap-2 cursor-pointer select-none">
            <input v-model="form.important" type="checkbox" class="rounded" />
            <span class="text-sm text-gray-700">Marquer comme importante</span>
          </label>
          <div class="flex gap-2">
            <button @click="showForm = false" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
            <button @click="saveNote" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
              {{ editingId ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Recherche -->
      <div class="mb-4">
        <input v-model="search" type="text" placeholder="Rechercher une note..." class="w-full border rounded-lg px-3 py-2 text-sm" />
      </div>

      <!-- Liste des notes -->
      <div v-if="filteredNotes.length === 0" class="text-center text-gray-400 py-12">
        Aucune note
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          v-for="note in filteredNotes"
          :key="note.id"
          :class="[
            'rounded-xl shadow-sm p-5 transition-all',
            note.important ? 'bg-amber-50 border-2 border-amber-300' : 'bg-white'
          ]"
        >
          <div class="flex items-start justify-between mb-2">
            <h3 class="font-semibold text-gray-900">{{ note.title }}</h3>
            <button
              @click="toggleImportant(note)"
              :title="note.important ? 'Retirer important' : 'Marquer important'"
              class="text-xl ml-2 flex-shrink-0 transition-transform hover:scale-110"
            >
              <span v-if="note.important" class="text-amber-500">&#9888;</span>
              <span v-else class="text-gray-300 hover:text-amber-400">&#9888;</span>
            </button>
          </div>
          <p class="text-sm text-gray-600 whitespace-pre-line mb-3">{{ note.content }}</p>
          <div class="flex items-center justify-between">
            <span class="text-xs text-gray-400">{{ formatDate(note.note_date) }}</span>
            <div class="flex gap-2">
              <button @click="openForm(note)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteNote(note.id)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud } = useApi()
const { list, create, update, destroy } = useCrud('notes')

const notes = ref([])
const showForm = ref(false)
const editingId = ref(null)
const search = ref('')

const today = new Date().toISOString().slice(0, 10)

const defaultForm = () => ({
  title: '',
  content: '',
  note_date: today,
  important: false,
})

const form = ref(defaultForm())

const filteredNotes = computed(() => {
  const q = search.value.toLowerCase()
  if (!q) return notes.value
  return notes.value.filter(n =>
    n.title.toLowerCase().includes(q) || (n.content && n.content.toLowerCase().includes(q))
  )
})

const fetchNotes = async () => {
  notes.value = await list()
}

const openForm = (note = null) => {
  if (note) {
    editingId.value = note.id
    form.value = { title: note.title, content: note.content || '', note_date: note.note_date, important: note.important }
  } else {
    editingId.value = null
    form.value = defaultForm()
  }
  showForm.value = true
}

const saveNote = async () => {
  if (!form.value.title.trim()) return
  const payload = { note: form.value }
  if (editingId.value) {
    await update(editingId.value, payload)
  } else {
    await create(payload)
  }
  showForm.value = false
  await fetchNotes()
}

const deleteNote = async (id) => {
  if (!confirm('Supprimer cette note ?')) return
  await destroy(id)
  await fetchNotes()
}

const toggleImportant = async (note) => {
  await update(note.id, { note: { important: !note.important } })
  await fetchNotes()
}

const formatDate = (dateStr) => {
  if (!dateStr) return ''
  return new Date(dateStr).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
}

onMounted(fetchNotes)
</script>
