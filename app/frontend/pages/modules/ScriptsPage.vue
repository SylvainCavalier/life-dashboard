<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <div class="flex flex-wrap items-center justify-between gap-3 mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes scripts</h1>
        <button @click="createScript" :disabled="creating" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50">
          + Nouveau script
        </button>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-[260px_1fr] gap-6">
        <!-- Dossiers : une chaine ou un compte chacun -->
        <aside class="space-y-4">
          <nav class="bg-white rounded-xl shadow-sm p-2 space-y-0.5">
            <button
              v-for="entry in fixedEntries"
              :key="entry.key"
              @click="selectFolder(entry.key)"
              class="w-full flex items-center justify-between px-3 py-2 rounded-lg text-sm transition"
              :class="selected === entry.key ? 'bg-gray-900 text-white' : 'text-gray-700 hover:bg-gray-100'"
            >
              <span>{{ entry.label }}</span>
              <span class="text-xs opacity-60">{{ entry.count }}</span>
            </button>

            <p class="px-3 pt-3 pb-1 text-xs font-medium uppercase tracking-wide text-gray-400">Chaînes et comptes</p>
            <div
              v-for="folder in folders"
              :key="folder.id"
              class="group flex items-center rounded-lg transition"
              :class="selected === String(folder.id) ? 'bg-gray-900 text-white' : 'text-gray-700 hover:bg-gray-100'"
            >
              <button @click="selectFolder(String(folder.id))" class="flex-1 min-w-0 flex items-center gap-2 px-3 py-2 text-sm text-left">
                <span class="flex-shrink-0 w-6 h-6 rounded-md flex items-center justify-center text-xs" :class="platformOf(folder.platform).badge">
                  {{ platformOf(folder.platform).icon }}
                </span>
                <span class="truncate">{{ folder.name }}</span>
              </button>
              <!-- Actions au survol, et toujours visibles sur le dossier ouvert (ecrans tactiles) -->
              <span v-if="selected !== String(folder.id)" class="text-xs opacity-60 pr-3 group-hover:hidden">{{ folder.scripts_count }}</span>
              <div class="items-center gap-1 pr-2" :class="selected === String(folder.id) ? 'flex' : 'hidden group-hover:flex'">
                <button @click="openFolderForm(folder)" class="p-1 opacity-60 hover:opacity-100" title="Modifier le dossier">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
                <button @click="deleteFolder(folder)" class="p-1 opacity-60 hover:opacity-100 hover:text-red-500" title="Supprimer le dossier">
                  <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </div>
            <p v-if="loaded && !folders.length" class="px-3 py-2 text-xs text-gray-400">Créez un dossier par chaîne YouTube ou compte de réseau social.</p>

            <button @click="openFolderForm()" class="w-full text-left px-3 py-2 rounded-lg text-sm text-indigo-600 hover:bg-indigo-50">
              + Nouveau dossier
            </button>
          </nav>

          <ScriptFolderForm
            v-if="showFolderForm"
            :key="editingFolder?.id || 'new'"
            :initial="editingFolder"
            :saving="savingFolder"
            :errors="folderErrors"
            @submit="saveFolder"
            @cancel="closeFolderForm"
          />
        </aside>

        <main class="min-w-0">
          <!-- En-tete du dossier ouvert -->
          <div v-if="currentFolder" class="bg-white rounded-xl shadow-sm p-5 mb-4">
            <div class="flex items-start gap-3">
              <span class="flex-shrink-0 w-10 h-10 rounded-lg flex items-center justify-center text-lg" :class="platformOf(currentFolder.platform).badge">
                {{ platformOf(currentFolder.platform).icon }}
              </span>
              <div class="min-w-0">
                <h2 class="text-lg font-semibold text-gray-900">{{ currentFolder.name }}</h2>
                <p class="text-sm text-gray-500">
                  {{ platformOf(currentFolder.platform).label }}
                  <template v-if="currentFolder.handle"> · {{ currentFolder.handle }}</template>
                  <template v-if="currentFolder.url"> · <a :href="currentFolder.url" target="_blank" rel="noopener" class="text-indigo-600 hover:underline">voir la page</a></template>
                </p>
                <p v-if="currentFolder.description" class="text-sm text-gray-600 mt-2 whitespace-pre-line">{{ currentFolder.description }}</p>
              </div>
            </div>
          </div>

          <!-- Filtres -->
          <div class="flex flex-wrap gap-2 mb-3">
            <button
              v-for="f in statusFilters"
              :key="f.value"
              @click="filterStatus = f.value"
              class="text-sm px-3 py-1.5 rounded-full border transition"
              :class="filterStatus === f.value ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
            >
              {{ f.label }} <span class="opacity-60">{{ countByStatus(f.value) }}</span>
            </button>
          </div>
          <div class="flex flex-wrap gap-3 mb-4">
            <input v-model="search" type="text" placeholder="Rechercher (titre, texte, notes...)" class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
            <select v-model="filterKind" class="border rounded-lg px-3 py-2 text-sm">
              <option value="">Tous formats</option>
              <option v-for="k in kinds" :key="k.value" :value="k.value">{{ k.icon }} {{ k.label }}</option>
            </select>
          </div>

          <div v-if="loaded && filtered.length === 0" class="text-center text-gray-400 py-12">
            {{ inFolder.length ? 'Aucun script ne correspond' : 'Aucun script ici pour le moment' }}
          </div>

          <div class="space-y-3">
            <router-link
              v-for="script in filtered"
              :key="script.id"
              :to="`/scripts/${script.id}`"
              class="block bg-white rounded-xl shadow-sm p-4 hover:shadow-md transition"
              :class="{ 'opacity-60': script.status === 'abandoned' }"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <h3 class="font-semibold text-gray-900 truncate">{{ kindOf(script.kind).icon }} {{ script.title }}</h3>
                  <p v-if="selected === '' && script.folder_name" class="text-xs text-gray-400">{{ script.folder_name }}</p>
                </div>
                <span class="flex-shrink-0 text-xs px-2 py-0.5 rounded-full font-medium" :class="statusOf(script.status).badge">{{ statusOf(script.status).label }}</span>
              </div>
              <p v-if="script.excerpt" class="text-sm text-gray-600 mt-2 line-clamp-2">{{ script.excerpt }}</p>
              <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-400 mt-3">
                <span>{{ kindOf(script.kind).label }}</span>
                <span>{{ script.word_count }} mot{{ script.word_count > 1 ? 's' : '' }}</span>
                <span v-if="script.kind === 'video' || script.kind === 'short'">≈ {{ formatDuration(script.estimated_duration) }}</span>
                <span v-if="script.posts_count">{{ script.posts_count }} message{{ script.posts_count > 1 ? 's' : '' }}</span>
                <span v-if="script.planned_on && script.status !== 'published'">Prévu le {{ formatDate(script.planned_on) }}</span>
                <span v-if="script.published_on">Publié le {{ formatDate(script.published_on) }}</span>
                <span>Modifié le {{ formatTimestamp(script.updated_at) }}</span>
              </div>
            </router-link>
          </div>
        </main>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import apiClient from '../../plugins/axios'
import { kinds, statuses, platformOf, kindOf, statusOf, formatDuration, formatDate } from '../../composables/useScripts'
import ScriptFolderForm from '../../components/scripts/ScriptFolderForm.vue'

const route = useRoute()
const router = useRouter()

const folders = ref([])
const unfiledCount = ref(0)
const scripts = ref([])
const loaded = ref(false)
const creating = ref(false)
const search = ref('')
const filterStatus = ref('')
const filterKind = ref('')

const showFolderForm = ref(false)
const editingFolder = ref(null)
const savingFolder = ref(false)
const folderErrors = ref([])

// '' = tous les scripts, 'none' = non classes, sinon l'identifiant du dossier.
const selected = computed(() => String(route.query.folder || ''))
const currentFolder = computed(() => folders.value.find(f => String(f.id) === selected.value) || null)

const fixedEntries = computed(() => [
  { key: '', label: 'Tous les scripts', count: scripts.value.length },
  { key: 'none', label: 'Non classés', count: unfiledCount.value },
])

const selectFolder = (key) => {
  router.replace({ query: key ? { folder: key } : {} })
}

const statusFilters = [
  { value: '', label: 'Tous' },
  { value: 'in_progress', label: 'En cours' },
  ...statuses.filter(s => s.value !== 'abandoned'),
  { value: 'abandoned', label: 'Abandonnés' },
]

const matchesStatus = (script, status) => {
  if (status === 'in_progress') return !['published', 'abandoned'].includes(script.status)
  return !status || script.status === status
}

const inFolder = computed(() => {
  if (selected.value === '') return scripts.value
  if (selected.value === 'none') return scripts.value.filter(s => !s.script_folder_id)
  return scripts.value.filter(s => String(s.script_folder_id) === selected.value)
})

// Recherche + format, avant le filtre de statut : sert aussi aux compteurs des pastilles.
const searched = computed(() => {
  let result = inFolder.value
  if (filterKind.value) result = result.filter(s => s.kind === filterKind.value)
  const q = search.value.toLowerCase()
  if (q) result = result.filter(s => [s.title, s.excerpt, s.notes].some(text => text && text.toLowerCase().includes(q)))
  return result
})

const countByStatus = (status) => searched.value.filter(s => matchesStatus(s, status)).length
const filtered = computed(() => searched.value.filter(s => matchesStatus(s, filterStatus.value)))

const formatTimestamp = (iso) => new Date(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' })

const fetchFolders = async () => {
  const data = (await apiClient.get('/script_folders')).data
  folders.value = data.folders || []
  unfiledCount.value = data.unfiled_count || 0
}

const fetchScripts = async () => {
  scripts.value = (await apiClient.get('/scripts')).data || []
}

// Brouillon cree tout de suite dans le dossier ouvert, puis ouvert dans l'editeur.
const createScript = async () => {
  creating.value = true
  try {
    const folder = currentFolder.value
    const { data } = await apiClient.post('/scripts', {
      script: { title: 'Sans titre', status: 'draft', kind: folder?.default_kind || 'video', script_folder_id: folder?.id || null },
    })
    router.push({ path: `/scripts/${data.id}`, query: { new: '1' } })
  } finally {
    creating.value = false
  }
}

const openFolderForm = (folder = null) => {
  folderErrors.value = []
  editingFolder.value = folder
  showFolderForm.value = true
}

const closeFolderForm = () => {
  showFolderForm.value = false
  editingFolder.value = null
}

const saveFolder = async (attributes) => {
  savingFolder.value = true
  folderErrors.value = []
  try {
    if (editingFolder.value) {
      await apiClient.patch(`/script_folders/${editingFolder.value.id}`, { script_folder: attributes })
      closeFolderForm()
    } else {
      const { data } = await apiClient.post('/script_folders', { script_folder: attributes })
      closeFolderForm()
      selectFolder(String(data.id))
    }
    await fetchFolders()
  } catch (e) {
    folderErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    savingFolder.value = false
  }
}

const deleteFolder = async (folder) => {
  const count = folder.scripts_count
  const detail = count ? `\nSes ${count} script${count > 1 ? 's' : ''} ser${count > 1 ? 'ont conservés' : 'a conservé'} dans « Non classés ».` : ''
  if (!confirm(`Supprimer le dossier « ${folder.name} » ?${detail}`)) return
  await apiClient.delete(`/script_folders/${folder.id}`)
  if (selected.value === String(folder.id)) selectFolder('')
  await Promise.all([fetchFolders(), fetchScripts()])
}

onMounted(async () => {
  await Promise.all([fetchFolders(), fetchScripts()])
  loaded.value = true
})
</script>
