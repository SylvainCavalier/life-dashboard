<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-4xl mx-auto">
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

      <!-- Profil Sante -->
      <div class="bg-white rounded-xl shadow-sm p-8 mb-6">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">🏥</span>
            <h1 class="text-2xl font-bold text-gray-900">Sante</h1>
          </div>
          <button
            v-if="!editing"
            @click="startEditing"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ profileExists ? 'Modifier' : 'Remplir mes infos sante' }}
          </button>
          <div v-else class="flex gap-2">
            <button
              @click="saveProfile"
              class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
            >
              Enregistrer
            </button>
            <button
              @click="cancelEdit"
              class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors text-sm font-medium"
            >
              Annuler
            </button>
          </div>
        </div>

        <!-- Mode lecture -->
        <div v-if="!editing">
          <div v-if="!profileExists" class="text-center text-gray-400 py-12">
            Aucune information de sante enregistree. Cliquez sur "Remplir mes infos sante" pour commencer.
          </div>

          <div v-else class="space-y-8">
            <!-- Informations generales -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Informations generales</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.blood_type" class="flex flex-col">
                  <span class="text-xs text-gray-500">Groupe sanguin</span>
                  <span class="text-sm text-gray-900">{{ profile.blood_type }}</span>
                </div>
                <div v-if="profile.allergies" class="flex flex-col">
                  <span class="text-xs text-gray-500">Allergies</span>
                  <span class="text-sm text-gray-900 whitespace-pre-line">{{ profile.allergies }}</span>
                </div>
                <div v-if="profile.current_medications" class="flex flex-col">
                  <span class="text-xs text-gray-500">Medicaments en cours</span>
                  <span class="text-sm text-gray-900 whitespace-pre-line">{{ profile.current_medications }}</span>
                </div>
                <div v-if="profile.medical_history" class="flex flex-col">
                  <span class="text-xs text-gray-500">Antecedents medicaux</span>
                  <span class="text-sm text-gray-900 whitespace-pre-line">{{ profile.medical_history }}</span>
                </div>
              </div>
            </section>

            <!-- Medecins -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Medecins</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.attending_physician" class="flex flex-col">
                  <span class="text-xs text-gray-500">Medecin traitant</span>
                  <span class="text-sm text-gray-900">{{ profile.attending_physician }}</span>
                </div>
                <div v-if="profile.attending_physician_phone" class="flex flex-col">
                  <span class="text-xs text-gray-500">Telephone medecin</span>
                  <span class="text-sm text-gray-900">{{ profile.attending_physician_phone }}</span>
                </div>
                <div v-if="profile.specialists" class="flex flex-col md:col-span-2">
                  <span class="text-xs text-gray-500">Specialistes</span>
                  <span class="text-sm text-gray-900 whitespace-pre-line">{{ profile.specialists }}</span>
                </div>
              </div>
            </section>

            <!-- Securite sociale & Mutuelle -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Securite sociale & Mutuelle</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.social_security_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">Numero de securite sociale</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.social_security_number ? profile.social_security_number : '•••••••••••••••' }}
                    <button @click="toggleSensitive('social_security_number')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
                <div v-if="profile.health_insurance_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Mutuelle</span>
                  <span class="text-sm text-gray-900">{{ profile.health_insurance_name }}</span>
                </div>
                <div v-if="profile.health_insurance_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° Adherent mutuelle</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.health_insurance_number ? profile.health_insurance_number : '••••••••' }}
                    <button @click="toggleSensitive('health_insurance_number')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
              </div>
            </section>

            <!-- Liens utiles -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Liens utiles</h2>
              <div class="flex flex-wrap gap-3">
                <a
                  :href="profile.ameli_url || 'https://www.ameli.fr'"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 bg-blue-50 text-blue-700 px-4 py-2 rounded-lg hover:bg-blue-100 transition-colors text-sm font-medium"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                  Ameli.fr
                </a>
                <a
                  v-if="profile.health_insurance_website"
                  :href="profile.health_insurance_website"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-2 bg-green-50 text-green-700 px-4 py-2 rounded-lg hover:bg-green-100 transition-colors text-sm font-medium"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" /></svg>
                  Site mutuelle
                </a>
              </div>
            </section>
          </div>
        </div>

        <!-- Mode edition -->
        <form v-else @submit.prevent="saveProfile" class="space-y-8">
          <!-- Informations generales -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Informations generales</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Groupe sanguin</label>
                <select v-model="form.blood_type" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option v-for="opt in bloodTypeOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
              </div>
              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Allergies</label>
                <textarea v-model="form.allergies" rows="3" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
              </div>
              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Medicaments en cours</label>
                <textarea v-model="form.current_medications" rows="3" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
              </div>
              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Antecedents medicaux</label>
                <textarea v-model="form.medical_history" rows="3" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
              </div>
            </div>
          </section>

          <!-- Medecins -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Medecins</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Medecin traitant</label>
                <input v-model="form.attending_physician" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Telephone medecin</label>
                <input v-model="form.attending_physician_phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div class="md:col-span-2">
                <label class="block text-sm font-medium text-gray-700 mb-1">Specialistes (un par ligne : nom - specialite - telephone)</label>
                <textarea v-model="form.specialists" rows="4" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
              </div>
            </div>
          </section>

          <!-- Securite sociale & Mutuelle -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Securite sociale & Mutuelle</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Numero de securite sociale</label>
                <input v-model="form.social_security_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nom de la mutuelle</label>
                <input v-model="form.health_insurance_name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° Adherent mutuelle</label>
                <input v-model="form.health_insurance_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Site web mutuelle</label>
                <input v-model="form.health_insurance_website" type="url" placeholder="https://..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Lien Ameli</label>
                <input v-model="form.ameli_url" type="url" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>
        </form>
      </div>

      <!-- Documents de sante -->
      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-bold text-gray-900">Documents de sante</h2>
          <button
            @click="showDocForm = !showDocForm"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showDocForm ? 'Fermer' : 'Ajouter un document' }}
          </button>
        </div>

        <!-- Formulaire d'upload -->
        <div v-if="showDocForm" class="bg-gray-50 rounded-lg p-4 mb-6">
          <form @submit.prevent="uploadDocument" class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label class="block text-xs text-gray-500 mb-1">Nom du document *</label>
              <input v-model="docForm.name" type="text" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Categorie</label>
              <select v-model="docForm.category" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                <option value="">-- Choisir --</option>
                <option value="analysis">Analyse</option>
                <option value="prescription">Ordonnance</option>
                <option value="report">Compte-rendu</option>
                <option value="certificate">Attestation</option>
                <option value="imaging">Imagerie</option>
                <option value="vaccination">Vaccination</option>
                <option value="other">Autre</option>
              </select>
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Date du document</label>
              <input v-model="docForm.document_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div>
              <label class="block text-xs text-gray-500 mb-1">Fichier *</label>
              <input ref="fileInput" type="file" required @change="onFileSelected" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white" />
            </div>
            <div class="md:col-span-2">
              <label class="block text-xs text-gray-500 mb-1">Notes</label>
              <input v-model="docForm.notes" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
            <div class="md:col-span-2">
              <button
                type="submit"
                :disabled="uploading"
                class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50"
              >
                {{ uploading ? 'Envoi en cours...' : 'Envoyer' }}
              </button>
            </div>
          </form>
        </div>

        <!-- Filtre par categorie -->
        <div v-if="documents.length > 0" class="flex flex-wrap gap-2 mb-4">
          <button
            @click="filterCategory = ''"
            :class="filterCategory === '' ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            Tous ({{ documents.length }})
          </button>
          <button
            v-for="cat in usedCategories"
            :key="cat"
            @click="filterCategory = cat"
            :class="filterCategory === cat ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            {{ categoryLabel(cat) }} ({{ countByCategory(cat) }})
          </button>
        </div>

        <!-- Liste des documents -->
        <div v-if="filteredDocuments.length === 0" class="text-center text-gray-400 py-8">
          {{ documents.length === 0 ? 'Aucun document enregistre.' : 'Aucun document dans cette categorie.' }}
        </div>

        <div v-else class="space-y-3">
          <div
            v-for="doc in filteredDocuments"
            :key="doc.id"
            class="flex items-center justify-between bg-gray-50 rounded-lg p-4"
          >
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-sm font-medium text-gray-900 truncate">{{ doc.name }}</span>
                <span v-if="doc.category" class="text-xs bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full">{{ categoryLabel(doc.category) }}</span>
              </div>
              <div class="flex items-center gap-3 mt-1">
                <span v-if="doc.document_date" class="text-xs text-gray-500">{{ formatDate(doc.document_date) }}</span>
                <span v-if="doc.file_name" class="text-xs text-gray-400">{{ doc.file_name }}</span>
                <span v-if="doc.file_size" class="text-xs text-gray-400">{{ formatSize(doc.file_size) }}</span>
              </div>
              <p v-if="doc.notes" class="text-xs text-gray-500 mt-1">{{ doc.notes }}</p>
            </div>
            <div class="flex items-center gap-2 ml-4">
              <a
                v-if="doc.download_url"
                :href="doc.download_url"
                class="text-indigo-600 hover:text-indigo-800 p-1"
                title="Telecharger"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
              </a>
              <button
                @click="deleteDocument(doc.id)"
                class="text-red-500 hover:text-red-700 p-1"
                title="Supprimer"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import apiClient from '../../plugins/axios'

const { get, post, patch, delete: del } = useApi()

// Profil sante
const profile = ref({})
const profileExists = ref(false)
const editing = ref(false)

// Documents
const documents = ref([])
const uploading = ref(false)
const showDocForm = ref(false)
const fileInput = ref(null)
const selectedFile = ref(null)
const filterCategory = ref('')

const sensitiveVisible = reactive({
  social_security_number: false,
  health_insurance_number: false,
})

const emptyForm = {
  blood_type: '', allergies: '', current_medications: '', medical_history: '',
  attending_physician: '', attending_physician_phone: '', specialists: '',
  social_security_number: '',
  health_insurance_name: '', health_insurance_number: '', health_insurance_website: '',
  ameli_url: 'https://www.ameli.fr',
}

const form = reactive({ ...emptyForm })

const docForm = reactive({
  name: '',
  category: '',
  document_date: '',
  notes: '',
})

const bloodTypeOptions = [
  { value: '', label: '-- Choisir --' },
  { value: 'A+', label: 'A+' }, { value: 'A-', label: 'A-' },
  { value: 'B+', label: 'B+' }, { value: 'B-', label: 'B-' },
  { value: 'AB+', label: 'AB+' }, { value: 'AB-', label: 'AB-' },
  { value: 'O+', label: 'O+' }, { value: 'O-', label: 'O-' },
]

const categoryLabels = {
  analysis: 'Analyse',
  prescription: 'Ordonnance',
  report: 'Compte-rendu',
  certificate: 'Attestation',
  imaging: 'Imagerie',
  vaccination: 'Vaccination',
  other: 'Autre',
}

const categoryLabel = (val) => categoryLabels[val] || val

const usedCategories = computed(() => {
  const cats = [...new Set(documents.value.map(d => d.category).filter(Boolean))]
  return cats.sort()
})

const countByCategory = (cat) => documents.value.filter(d => d.category === cat).length

const filteredDocuments = computed(() => {
  if (!filterCategory.value) return documents.value
  return documents.value.filter(d => d.category === filterCategory.value)
})

const formatDate = (val) => {
  if (!val) return null
  return new Date(val).toLocaleDateString('fr-FR')
}

const formatSize = (bytes) => {
  if (bytes < 1024) return bytes + ' o'
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' Ko'
  return (bytes / (1024 * 1024)).toFixed(1) + ' Mo'
}

const toggleSensitive = (field) => {
  sensitiveVisible[field] = !sensitiveVisible[field]
}

// Profil
const fetchProfile = async () => {
  const data = await get('/health_profile')
  if (data) {
    profile.value = data
    profileExists.value = true
  }
}

const fillForm = () => {
  Object.keys(emptyForm).forEach(key => {
    form[key] = profile.value[key] || emptyForm[key]
  })
}

const startEditing = () => {
  if (profileExists.value) fillForm()
  editing.value = true
}

const cancelEdit = () => {
  editing.value = false
  if (profileExists.value) fillForm()
  else Object.assign(form, emptyForm)
}

const saveProfile = async () => {
  const payload = { health_profile: { ...form } }
  if (profileExists.value) {
    const data = await patch('/health_profile', payload)
    if (data && !data.errors) {
      profile.value = data
      editing.value = false
    }
  } else {
    const data = await post('/health_profile', payload)
    if (data && !data.errors) {
      profile.value = data
      profileExists.value = true
      editing.value = false
    }
  }
}

// Documents
const fetchDocuments = async () => {
  const data = await get('/documents', { params: { domain: 'health' } })
  if (data) documents.value = data
}

const onFileSelected = (event) => {
  selectedFile.value = event.target.files[0]
}

const uploadDocument = async () => {
  if (!selectedFile.value) return
  uploading.value = true

  const formData = new FormData()
  formData.append('domain', 'health')
  formData.append('name', docForm.name)
  formData.append('file', selectedFile.value)
  if (docForm.category) formData.append('category', docForm.category)
  if (docForm.document_date) formData.append('document_date', docForm.document_date)
  if (docForm.notes) formData.append('notes', docForm.notes)

  try {
    const response = await apiClient.post('/documents', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    documents.value.unshift(response.data)
    docForm.name = ''
    docForm.category = ''
    docForm.document_date = ''
    docForm.notes = ''
    selectedFile.value = null
    if (fileInput.value) fileInput.value.value = ''
    showDocForm.value = false
  } catch (e) {
    console.error('Erreur upload:', e)
  } finally {
    uploading.value = false
  }
}

const deleteDocument = async (id) => {
  if (!confirm('Supprimer ce document ?')) return
  await del(`/documents/${id}`)
  documents.value = documents.value.filter(d => d.id !== id)
}

onMounted(async () => {
  await fetchProfile()
  await fetchDocuments()
})
</script>
