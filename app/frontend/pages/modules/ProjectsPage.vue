<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes projets</h1>
        <button @click="showForm = !showForm" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouveau projet
        </button>
      </div>

      <!-- Formulaire -->
      <ProjectForm
        v-if="showForm"
        class="mb-6"
        :default-category="filterCategory || 'developpement'"
        :saving="saving"
        :errors="formErrors"
        @submit="createProject"
        @cancel="showForm = false"
      />

      <!-- Categories -->
      <div class="flex flex-wrap gap-2 mb-4">
        <button
          @click="filterCategory = ''"
          class="text-sm px-3 py-1.5 rounded-full border transition"
          :class="filterCategory === '' ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
        >
          Tous <span class="opacity-60">{{ statusFiltered.length }}</span>
        </button>
        <button
          v-for="c in visibleCategories"
          :key="c.value"
          @click="filterCategory = c.value"
          class="text-sm px-3 py-1.5 rounded-full border transition inline-flex items-center gap-1.5"
          :class="filterCategory === c.value ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
        >
          <span class="w-2 h-2 rounded-full" :class="c.dot"></span>
          {{ c.label }} <span class="opacity-60">{{ countByCategory[c.value] || 0 }}</span>
        </button>
      </div>

      <!-- Filtres -->
      <div class="flex flex-wrap gap-3 mb-4">
        <input v-model="search" type="text" placeholder="Rechercher un projet..." class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
        <select v-model="filterStatus" class="border rounded-lg px-3 py-2 text-sm">
          <option value="">Tous les statuts</option>
          <option v-for="s in projectStatuses" :key="s.value" :value="s.value">{{ s.label }}</option>
        </select>
      </div>

      <!-- Liste vide -->
      <div v-if="loaded && filteredProjects.length === 0" class="text-center text-gray-400 py-12">
        Aucun projet
      </div>

      <!-- Liste des projets -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <router-link
          v-for="project in filteredProjects"
          :key="project.id"
          :to="`/projects/${project.id}`"
          class="bg-white rounded-xl shadow-sm p-5 transition-all hover:shadow-md block"
        >
          <div class="flex items-start justify-between gap-3 mb-2">
            <h3 class="font-semibold text-gray-900 text-lg leading-tight">{{ project.name }}</h3>
            <span v-if="project.priority > 0" class="text-xs text-yellow-400 flex-shrink-0 mt-1">
              {{ '★'.repeat(project.priority) }}<span class="text-gray-200">{{ '★'.repeat(5 - project.priority) }}</span>
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-2 mb-2">
            <span :class="categoryBadge(project.category)" class="text-xs px-2 py-0.5 rounded-full font-medium">
              {{ categoryLabel(project.category) }}
            </span>
            <span :class="statusBadge(project.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">
              {{ statusLabel(project.status) }}
            </span>
          </div>
          <p v-if="project.description" class="text-sm text-gray-500 mb-3 line-clamp-2">{{ project.description }}</p>

          <!-- Barre de progression -->
          <div class="mb-3">
            <div class="flex items-center justify-between text-xs text-gray-500 mb-1">
              <span>Avancement</span>
              <span>{{ project.progress }}%</span>
            </div>
            <div class="w-full bg-gray-100 rounded-full h-2">
              <div :class="progressColor(project.progress)" class="h-2 rounded-full transition-all" :style="{ width: project.progress + '%' }"></div>
            </div>
          </div>

          <!-- Compteurs -->
          <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500 pt-2 border-t border-gray-100">
            <span v-if="project.tasks_count">Tâches {{ project.tasks_completed_count }}/{{ project.tasks_count }}</span>
            <span v-if="project.skills_count">Compétences {{ project.skills_acquired_count }}/{{ project.skills_count }}</span>
            <span v-if="project.links_count">{{ project.links_count }} lien{{ project.links_count > 1 ? 's' : '' }}</span>
            <span v-if="project.documents_count">{{ project.documents_count }} document{{ project.documents_count > 1 ? 's' : '' }}</span>
            <span v-if="!project.tasks_count && !project.skills_count && !project.links_count && !project.documents_count" class="text-gray-400">
              Ouvrir pour ajouter tâches, compétences, liens...
            </span>
          </div>
        </router-link>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import { useProjects, projectCategories, projectStatuses } from '../../composables/useProjects'
import ProjectForm from '../../components/projects/ProjectForm.vue'

const router = useRouter()
const { useCrud } = useApi()
const { list, create } = useCrud('projects')
const { categoryLabel, categoryBadge, statusLabel, statusBadge, progressColor } = useProjects()

const projects = ref([])
const loaded = ref(false)
const showForm = ref(false)
const saving = ref(false)
const formErrors = ref([])
const search = ref('')
const filterStatus = ref('')
const filterCategory = ref('')

// Recherche + statut, avant le filtre de categorie : sert aussi aux compteurs des onglets.
const statusFiltered = computed(() => {
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

const countByCategory = computed(() => {
  const counts = {}
  statusFiltered.value.forEach(p => { counts[p.category] = (counts[p.category] || 0) + 1 })
  return counts
})

// On n'affiche que les categories utilisees (plus celle en cours de filtrage).
const visibleCategories = computed(() =>
  projectCategories.filter(c => projects.value.some(p => p.category === c.value) || filterCategory.value === c.value)
)

const filteredProjects = computed(() => {
  if (!filterCategory.value) return statusFiltered.value
  return statusFiltered.value.filter(p => p.category === filterCategory.value)
})

const fetchProjects = async () => {
  projects.value = await list() || []
  loaded.value = true
}

const createProject = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    const project = await create({ project: attributes })
    router.push(`/projects/${project.id}`)
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

onMounted(fetchProjects)
</script>
