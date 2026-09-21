<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/projects" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour aux projets
      </router-link>

      <div v-if="project" class="space-y-6">
        <!-- En-tête -->
        <div v-if="!editing" class="bg-white rounded-xl shadow-sm p-6">
          <div class="flex items-start justify-between gap-4 mb-4">
            <div>
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <h1 class="text-2xl font-bold text-gray-900">{{ project.name }}</h1>
                <span :class="categoryBadge(project.category)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ categoryLabel(project.category) }}</span>
                <span :class="statusBadge(project.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(project.status) }}</span>
              </div>
              <p v-if="project.priority > 0" class="text-sm text-yellow-400">
                {{ '★'.repeat(project.priority) }}<span class="text-gray-200">{{ '★'.repeat(5 - project.priority) }}</span>
              </p>
              <p v-if="project.description" class="text-sm text-gray-600 mt-2 whitespace-pre-line">{{ project.description }}</p>
              <div v-if="project.github_url || project.site_url" class="flex gap-4 mt-2 text-sm">
                <a v-if="project.github_url" :href="project.github_url" target="_blank" rel="noopener" class="text-gray-500 hover:text-gray-800 underline">GitHub</a>
                <a v-if="project.site_url" :href="project.site_url" target="_blank" rel="noopener" class="text-blue-500 hover:text-blue-700 underline">Lien principal</a>
              </div>
            </div>
            <div class="flex items-center gap-3 flex-shrink-0">
              <button @click="editing = true" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteProject" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>

          <!-- Jauge : modifiable directement, enregistree au relachement -->
          <div>
            <div class="flex items-center justify-between text-xs text-gray-500 mb-1">
              <span>Avancement</span>
              <span>{{ progressDraft }}%</span>
            </div>
            <div class="w-full bg-gray-100 rounded-full h-2.5 mb-2">
              <div :class="progressColor(progressDraft)" class="h-2.5 rounded-full transition-all" :style="{ width: progressDraft + '%' }"></div>
            </div>
            <input v-model.number="progressDraft" @change="saveProgress" type="range" min="0" max="100" step="5" class="w-full" />
            <p v-if="taskStats.total" class="text-xs text-gray-400 mt-1">
              {{ taskStats.done }}/{{ taskStats.total }} tâches terminées ({{ taskStats.percent }}%)
              <button v-if="taskStats.percent !== progressDraft" @click="alignProgressOnTasks" class="text-blue-500 hover:text-blue-700 ml-1">Aligner la jauge</button>
            </p>
          </div>
        </div>
        <ProjectForm v-else :initial="project" :saving="saving" :errors="formErrors" @submit="saveProject" @cancel="editing = false" />

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          <!-- Colonne gauche : to-do list + notes -->
          <div class="space-y-6">
            <TodoList :project-id="project.id" title="To-do list du projet" @changed="onTasksChanged" />

            <div class="bg-white rounded-xl shadow-sm p-5">
              <div class="flex items-center justify-between mb-3">
                <h2 class="text-lg font-semibold text-gray-900">Notes personnelles</h2>
                <span class="text-xs" :class="notesDirty ? 'text-orange-500' : 'text-gray-400'">
                  {{ notesSaving ? 'Enregistrement...' : notesDirty ? 'Non enregistré' : notesSavedOnce ? 'Enregistré' : '' }}
                </span>
              </div>
              <textarea
                v-model="notesDraft"
                @blur="saveNotes"
                rows="10"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="Idées, réflexions, journal de bord..."
              ></textarea>
              <div class="flex justify-end mt-2">
                <button @click="saveNotes" :disabled="!notesDirty || notesSaving" class="text-xs font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg px-3 py-1.5 transition-colors disabled:opacity-40">
                  Enregistrer
                </button>
              </div>
            </div>
          </div>

          <!-- Colonne droite : competences, liens, documents -->
          <div class="space-y-6">
            <!-- Competences -->
            <div class="bg-white rounded-xl shadow-sm p-5">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-semibold text-gray-900">Compétences à apprendre</h2>
                <span v-if="project.skills.length" class="text-xs text-gray-400">{{ acquiredSkills }}/{{ project.skills.length }} acquises</span>
              </div>
              <form @submit.prevent="addSkill" class="flex gap-2 mb-4">
                <input v-model="newSkill" type="text" required placeholder="Blender, Unreal Engine, solfège..." class="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                <button type="submit" class="bg-blue-600 text-white rounded-lg px-3 py-2 text-sm font-medium hover:bg-blue-700 transition-colors">Ajouter</button>
              </form>
              <ul v-if="project.skills.length" class="space-y-2">
                <li v-for="skill in project.skills" :key="skill.id" class="flex items-center gap-2 p-2 rounded-lg hover:bg-gray-50 group">
                  <span class="flex-1 min-w-0 text-sm truncate" :class="skill.status === 'acquise' ? 'text-gray-400 line-through' : 'text-gray-900'">{{ skill.name }}</span>
                  <!-- Un clic fait passer au statut suivant -->
                  <button @click="cycleSkill(skill)" :class="skillStatusBadge(skill.status)" class="text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0" title="Changer le statut">
                    {{ skillStatusLabel(skill.status) }}
                  </button>
                  <button @click="deleteSkill(skill)" class="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100 p-1" title="Supprimer">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </li>
              </ul>
              <p v-else class="text-sm text-gray-400 text-center py-2">Aucune compétence listée</p>
            </div>

            <!-- Liens -->
            <div class="bg-white rounded-xl shadow-sm p-5">
              <h2 class="text-lg font-semibold text-gray-900 mb-4">Liens</h2>
              <form @submit.prevent="addLink" class="space-y-2 mb-4">
                <input v-model="newLink.url" type="url" required placeholder="https://..." class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                <div class="flex gap-2">
                  <input v-model="newLink.title" type="text" placeholder="Titre (facultatif)" class="flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                  <button type="submit" class="bg-blue-600 text-white rounded-lg px-3 py-2 text-sm font-medium hover:bg-blue-700 transition-colors">Ajouter</button>
                </div>
              </form>
              <ul v-if="project.links.length" class="space-y-1">
                <li v-for="link in project.links" :key="link.id" class="flex items-center gap-2 p-2 rounded-lg hover:bg-gray-50 group">
                  <a :href="link.url" target="_blank" rel="noopener" class="flex-1 min-w-0">
                    <span class="block text-sm text-blue-600 hover:text-blue-800 truncate">{{ link.title }}</span>
                    <span class="block text-xs text-gray-400 truncate">{{ link.url }}</span>
                  </a>
                  <button @click="deleteLink(link)" class="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100 p-1" title="Supprimer">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </li>
              </ul>
              <p v-else class="text-sm text-gray-400 text-center py-2">Aucun lien</p>
            </div>

            <!-- Documents -->
            <div class="bg-white rounded-xl shadow-sm p-5">
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-lg font-semibold text-gray-900">Documents</h2>
                <button @click="showDocForm = !showDocForm" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
                  {{ showDocForm ? 'Fermer' : '+ Ajouter' }}
                </button>
              </div>

              <form v-if="showDocForm" @submit.prevent="uploadDocument" class="bg-gray-50 rounded-lg p-4 mb-4 space-y-3">
                <div>
                  <label class="block text-xs text-gray-500 mb-1">Fichier *</label>
                  <input ref="docFileInput" type="file" required @change="onDocFileSelected" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Nom *</label>
                    <input v-model="docForm.name" type="text" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm" />
                  </div>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Catégorie</label>
                    <select v-model="docForm.category" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
                      <option value="">-- Choisir --</option>
                      <option v-for="c in projectDocCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
                    </select>
                  </div>
                </div>
                <p v-if="docError" class="text-xs text-red-600">{{ docError }}</p>
                <button type="submit" :disabled="docUploading" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium disabled:opacity-50">
                  {{ docUploading ? 'Envoi en cours...' : 'Envoyer' }}
                </button>
              </form>

              <ul v-if="documents.length" class="space-y-1">
                <li v-for="doc in documents" :key="doc.id" class="flex items-center gap-2 p-2 rounded-lg hover:bg-gray-50 group">
                  <a :href="doc.download_url" class="flex-1 min-w-0">
                    <span class="flex items-center gap-2">
                      <span class="text-sm text-gray-900 truncate">{{ doc.name }}</span>
                      <span v-if="doc.category" class="text-xs bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full flex-shrink-0">{{ docCategoryLabel(doc.category) }}</span>
                    </span>
                    <span class="block text-xs text-gray-400 truncate">{{ doc.file_name }} · {{ formatSize(doc.file_size) }}</span>
                  </a>
                  <button @click="deleteDocument(doc)" class="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100 p-1" title="Supprimer">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </li>
              </ul>
              <p v-else-if="!showDocForm" class="text-sm text-gray-400 text-center py-2">Aucun document</p>
            </div>
          </div>
        </div>
      </div>

      <div v-else-if="notFound" class="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">Projet introuvable</div>
      <div v-else class="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">Chargement...</div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import apiClient from '../../plugins/axios'
import { useProjects, skillStatuses, projectDocCategories } from '../../composables/useProjects'
import ProjectForm from '../../components/projects/ProjectForm.vue'
import TodoList from '../../components/TodoList.vue'

const route = useRoute()
const router = useRouter()
const projectId = route.params.id

const { get, post, patch, delete: del } = useApi()
const {
  categoryLabel, categoryBadge, statusLabel, statusBadge,
  skillStatusLabel, skillStatusBadge, docCategoryLabel, progressColor,
} = useProjects()

const project = ref(null)
const notFound = ref(false)
const editing = ref(false)
const saving = ref(false)
const formErrors = ref([])

const progressDraft = ref(0)
const notesDraft = ref('')
const notesSaving = ref(false)
const notesSavedOnce = ref(false)
const tasks = ref([])

const newSkill = ref('')
const newLink = reactive({ title: '', url: '' })

const documents = ref([])
const showDocForm = ref(false)
const docUploading = ref(false)
const docError = ref('')
const docFileInput = ref(null)
const selectedDocFile = ref(null)
const docForm = reactive({ name: '', category: '' })

const notesDirty = computed(() => notesDraft.value !== (project.value?.notes || ''))
const acquiredSkills = computed(() => project.value.skills.filter(s => s.status === 'acquise').length)

const taskStats = computed(() => {
  const total = tasks.value.length
  const done = tasks.value.filter(t => t.completed).length
  // Arrondi au pas de 5 de la jauge.
  const percent = total ? Math.round((done / total) * 20) * 5 : 0
  return { total, done, percent }
})

const showError = (e, fallback) => {
  const errors = e.response?.data?.errors
  alert(errors ? errors.join('\n') : fallback)
}

// Ne touche jamais au brouillon des notes : il n'est initialise qu'au chargement.
const applyProject = (data) => {
  project.value = data
  progressDraft.value = data.progress || 0
}

const fetchProject = async () => {
  try {
    const data = await get(`/projects/${projectId}`)
    notesDraft.value = data.notes || ''
    applyProject(data)
  } catch (e) {
    notFound.value = true
  }
}

const fetchDocuments = async () => {
  documents.value = await get('/documents', { params: { project_id: projectId } }) || []
}

// Projet
const updateProject = async (attributes) => {
  const data = await patch(`/projects/${projectId}`, { project: attributes })
  applyProject(data)
}

const saveProject = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    await updateProject(attributes)
    editing.value = false
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const deleteProject = async () => {
  if (!confirm('Supprimer ce projet, ses tâches, compétences, liens et documents ?')) return
  try {
    await del(`/projects/${projectId}`)
    router.push('/projects')
  } catch (e) {
    showError(e, 'Suppression impossible')
  }
}

const saveProgress = async () => {
  try {
    await updateProject({ progress: progressDraft.value })
  } catch (e) {
    progressDraft.value = project.value.progress || 0
    showError(e, 'Mise à jour de la jauge impossible')
  }
}

const alignProgressOnTasks = () => {
  progressDraft.value = taskStats.value.percent
  saveProgress()
}

const saveNotes = async () => {
  if (!notesDirty.value || notesSaving.value) return
  notesSaving.value = true
  const saved = notesDraft.value
  try {
    const data = await patch(`/projects/${projectId}`, { project: { notes: saved } })
    // On ne touche pas au brouillon : l'utilisateur a pu continuer a taper.
    project.value = { ...project.value, notes: data.notes }
    notesSavedOnce.value = true
  } catch (e) {
    showError(e, 'Enregistrement des notes impossible')
  } finally {
    notesSaving.value = false
  }
}

const onTasksChanged = (list) => { tasks.value = list }

// Competences
const addSkill = async () => {
  const name = newSkill.value.trim()
  if (!name) return
  try {
    const skill = await post(`/projects/${projectId}/project_skills`, { project_skill: { name } })
    project.value.skills.push(skill)
    newSkill.value = ''
  } catch (e) {
    showError(e, 'Ajout de la compétence impossible')
  }
}

const cycleSkill = async (skill) => {
  const index = skillStatuses.findIndex(s => s.value === skill.status)
  const next = skillStatuses[(index + 1) % skillStatuses.length].value
  try {
    const updated = await patch(`/projects/${projectId}/project_skills/${skill.id}`, { project_skill: { status: next } })
    Object.assign(skill, updated)
  } catch (e) {
    showError(e, 'Mise à jour de la compétence impossible')
  }
}

const deleteSkill = async (skill) => {
  try {
    await del(`/projects/${projectId}/project_skills/${skill.id}`)
    project.value.skills = project.value.skills.filter(s => s.id !== skill.id)
  } catch (e) {
    showError(e, 'Suppression impossible')
  }
}

// Liens
const hostnameOf = (url) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '')
  } catch (e) {
    return url
  }
}

const addLink = async () => {
  const url = newLink.url.trim()
  if (!url) return
  try {
    const link = await post(`/projects/${projectId}/project_links`, {
      project_link: { url, title: newLink.title.trim() || hostnameOf(url) },
    })
    project.value.links.push(link)
    Object.assign(newLink, { title: '', url: '' })
  } catch (e) {
    showError(e, 'Ajout du lien impossible')
  }
}

const deleteLink = async (link) => {
  try {
    await del(`/projects/${projectId}/project_links/${link.id}`)
    project.value.links = project.value.links.filter(l => l.id !== link.id)
  } catch (e) {
    showError(e, 'Suppression impossible')
  }
}

// Documents
const onDocFileSelected = (event) => {
  selectedDocFile.value = event.target.files[0]
  if (selectedDocFile.value && !docForm.name) {
    docForm.name = selectedDocFile.value.name.replace(/\.[^.]+$/, '')
  }
}

const uploadDocument = async () => {
  if (!selectedDocFile.value) return
  docUploading.value = true
  docError.value = ''
  const formData = new FormData()
  formData.append('domain', 'projects')
  formData.append('project_id', projectId)
  formData.append('name', docForm.name)
  formData.append('file', selectedDocFile.value)
  if (docForm.category) formData.append('category', docForm.category)
  try {
    const response = await apiClient.post('/documents', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    documents.value.unshift(response.data)
    showDocForm.value = false
    Object.assign(docForm, { name: '', category: '' })
    selectedDocFile.value = null
    if (docFileInput.value) docFileInput.value.value = ''
  } catch (e) {
    docError.value = e.response?.data?.errors?.join(', ') || "Envoi impossible"
  } finally {
    docUploading.value = false
  }
}

const deleteDocument = async (doc) => {
  if (!confirm('Supprimer ce document ?')) return
  try {
    await del(`/documents/${doc.id}`)
    documents.value = documents.value.filter(d => d.id !== doc.id)
  } catch (e) {
    showError(e, 'Suppression impossible')
  }
}

const formatSize = (bytes) => {
  if (!bytes) return ''
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} Ko`
  return `${(bytes / (1024 * 1024)).toFixed(1)} Mo`
}

onMounted(() => {
  fetchProject()
  fetchDocuments()
})
</script>
