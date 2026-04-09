<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes projets</h1>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouveau projet
        </button>
      </div>

      <!-- Formulaire -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold mb-4">{{ editingId ? 'Modifier le projet' : 'Nouveau projet' }}</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Nom du projet *</label>
            <input v-model="form.name" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Mon super projet" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Statut</label>
            <select v-model="form.status" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="en_cours">En cours</option>
              <option value="en_attente">En attente</option>
              <option value="termine">Termine</option>
              <option value="abandonne">Abandonne</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Priorite (0-5)</label>
            <input v-model.number="form.priority" type="number" min="0" max="5" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Avancement (%)</label>
            <div class="flex items-center gap-3">
              <input v-model.number="form.progress" type="range" min="0" max="100" step="5" class="flex-1" />
              <span class="text-sm font-medium text-gray-700 w-10 text-right">{{ form.progress }}%</span>
            </div>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Lien GitHub</label>
            <input v-model="form.github_url" type="url" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="https://github.com/..." />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Lien du site</label>
            <input v-model="form.site_url" type="url" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="https://..." />
          </div>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <textarea v-model="form.description" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Description du projet..."></textarea>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
          <textarea v-model="form.notes" rows="3" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Notes, idees, todo..."></textarea>
        </div>
        <div class="flex justify-end gap-2">
          <button @click="showForm = false" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
          <button @click="saveProject" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
            {{ editingId ? 'Modifier' : 'Ajouter' }}
          </button>
        </div>
      </div>

      <!-- Filtres -->
      <div class="flex flex-wrap gap-3 mb-4">
        <input v-model="search" type="text" placeholder="Rechercher un projet..." class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
        <select v-model="filterStatus" class="border rounded-lg px-3 py-2 text-sm">
          <option value="">Tous les statuts</option>
          <option value="en_cours">En cours</option>
          <option value="en_attente">En attente</option>
          <option value="termine">Termine</option>
          <option value="abandonne">Abandonne</option>
        </select>
      </div>

      <!-- Liste vide -->
      <div v-if="filteredProjects.length === 0" class="text-center text-gray-400 py-12">
        Aucun projet
      </div>

      <!-- Liste des projets -->
      <div class="grid grid-cols-1 gap-4">
        <div
          v-for="project in filteredProjects"
          :key="project.id"
          class="bg-white rounded-xl shadow-sm p-5 transition-all hover:shadow-md"
        >
          <div class="flex items-start justify-between mb-3">
            <div class="flex-1">
              <div class="flex items-center gap-3 mb-1">
                <h3 class="font-semibold text-gray-900 text-lg">{{ project.name }}</h3>
                <span :class="statusClass(project.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">
                  {{ statusLabel(project.status) }}
                </span>
                <span v-if="project.priority > 0" class="text-xs text-gray-500">
                  {{ '★'.repeat(project.priority) }}{{ '☆'.repeat(5 - project.priority) }}
                </span>
              </div>
              <p v-if="project.description" class="text-sm text-gray-500">{{ project.description }}</p>
            </div>
            <div class="flex gap-2 ml-4 flex-shrink-0">
              <a v-if="project.github_url" :href="project.github_url" target="_blank" class="text-gray-400 hover:text-gray-700 text-sm" title="GitHub">
                GitHub
              </a>
              <a v-if="project.site_url" :href="project.site_url" target="_blank" class="text-blue-400 hover:text-blue-600 text-sm" title="Site">
                Site
              </a>
            </div>
          </div>

          <!-- Barre de progression -->
          <div class="mb-3">
            <div class="flex items-center justify-between text-xs text-gray-500 mb-1">
              <span>Avancement</span>
              <span>{{ project.progress }}%</span>
            </div>
            <div class="w-full bg-gray-100 rounded-full h-2.5">
              <div
                :class="progressColor(project.progress)"
                class="h-2.5 rounded-full transition-all"
                :style="{ width: project.progress + '%' }"
              ></div>
            </div>
          </div>

          <!-- Notes -->
          <p v-if="project.notes" class="text-sm text-gray-500 whitespace-pre-line mb-3">{{ project.notes }}</p>

          <!-- Actions -->
          <div class="flex items-center justify-end gap-3 pt-2 border-t border-gray-100">
            <button @click="openForm(project)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
            <button @click="deleteProject(project.id)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
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
const { list, create, update, destroy } = useCrud('projects')

const projects = ref([])
const showForm = ref(false)
const editingId = ref(null)
const search = ref('')
const filterStatus = ref('')

const defaultForm = () => ({
  name: '',
  description: '',
  status: 'en_cours',
  priority: 0,
  progress: 0,
  github_url: '',
  site_url: '',
  notes: '',
})

const form = ref(defaultForm())

const filteredProjects = computed(() => {
  let result = projects.value
  const q = search.value.toLowerCase()
  if (q) {
    result = result.filter(p =>
      p.name.toLowerCase().includes(q) ||
      (p.description && p.description.toLowerCase().includes(q)) ||
      (p.notes && p.notes.toLowerCase().includes(q))
    )
  }
  if (filterStatus.value) {
    result = result.filter(p => p.status === filterStatus.value)
  }
  return result
})

const fetchProjects = async () => {
  projects.value = await list()
}

const openForm = (project = null) => {
  if (project) {
    editingId.value = project.id
    form.value = {
      name: project.name,
      description: project.description || '',
      status: project.status,
      priority: project.priority || 0,
      progress: project.progress || 0,
      github_url: project.github_url || '',
      site_url: project.site_url || '',
      notes: project.notes || '',
    }
  } else {
    editingId.value = null
    form.value = defaultForm()
  }
  showForm.value = true
}

const saveProject = async () => {
  if (!form.value.name.trim()) return
  const payload = { project: form.value }
  if (editingId.value) {
    await update(editingId.value, payload)
  } else {
    await create(payload)
  }
  showForm.value = false
  await fetchProjects()
}

const deleteProject = async (id) => {
  if (!confirm('Supprimer ce projet ?')) return
  await destroy(id)
  await fetchProjects()
}

const statusLabel = (status) => {
  const labels = { en_cours: 'En cours', en_attente: 'En attente', termine: 'Termine', abandonne: 'Abandonne' }
  return labels[status] || status
}

const statusClass = (status) => {
  const classes = {
    en_cours: 'bg-blue-100 text-blue-700',
    en_attente: 'bg-yellow-100 text-yellow-700',
    termine: 'bg-green-100 text-green-700',
    abandonne: 'bg-red-100 text-red-700',
  }
  return classes[status] || 'bg-gray-100 text-gray-700'
}

const progressColor = (progress) => {
  if (progress >= 80) return 'bg-green-500'
  if (progress >= 50) return 'bg-blue-500'
  if (progress >= 25) return 'bg-yellow-500'
  return 'bg-gray-400'
}

onMounted(fetchProjects)
</script>
