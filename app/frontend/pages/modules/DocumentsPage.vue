<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
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

      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">📁</span>
            <h1 class="text-2xl font-bold text-gray-900">Documents</h1>
            <span class="text-sm text-gray-400">({{ documents.length }})</span>
          </div>
          <button
            @click="openForm()"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showForm ? 'Annuler' : '+ Ajouter' }}
          </button>
        </div>

        <!-- Filtre par categorie -->
        <div v-if="documents.length > 0" class="flex flex-wrap gap-2 mb-6">
          <button
            @click="filterDomain = ''"
            :class="filterDomain === '' ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            Tous
          </button>
          <button
            v-for="d in usedDomains"
            :key="d"
            @click="filterDomain = d"
            :class="filterDomain === d ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            {{ domainLabel(d) }}
            <span class="ml-1 opacity-70">({{ domainCount(d) }})</span>
          </button>
        </div>

        <!-- Formulaire d'ajout / edition -->
        <form v-if="showForm" @submit.prevent="saveDocument" class="mb-6 p-5 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <input
              v-model="form.name"
              type="text"
              placeholder="Nom du document *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <select
              v-model="form.domain"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Categorie *</option>
              <option v-for="d in domains" :key="d.value" :value="d.value">{{ d.label }}</option>
            </select>
            <select
              v-model="form.category"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              :disabled="!form.domain"
            >
              <option value="">Sous-categorie (optionnelle)</option>
              <option v-for="c in subcategories(form.domain)" :key="c.value" :value="c.value">{{ c.label }}</option>
            </select>
            <input
              v-model="form.document_date"
              type="date"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <div v-if="!editingId" class="sm:col-span-2">
              <label class="block text-xs text-gray-600 mb-1">Fichier *</label>
              <input
                ref="fileInput"
                type="file"
                @change="onFileChange"
                required
                class="w-full text-sm text-gray-700 file:mr-3 file:py-2 file:px-3 file:rounded-lg file:border-0 file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
              />
            </div>
            <textarea
              v-model="form.notes"
              placeholder="Notes (optionnelles)"
              rows="2"
              class="sm:col-span-2 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>
          <div class="mt-3 flex gap-2">
            <button
              type="submit"
              :disabled="uploading"
              class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50"
            >
              {{ uploading ? 'Envoi...' : (editingId ? 'Modifier' : 'Enregistrer') }}
            </button>
            <button
              v-if="editingId"
              type="button"
              @click="cancelEdit"
              class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors text-sm font-medium"
            >
              Annuler
            </button>
          </div>
        </form>

        <!-- Liste vide -->
        <div v-if="documents.length === 0" class="text-center text-gray-400 py-12">
          Aucun document enregistre
        </div>

        <!-- Documents par categorie -->
        <div v-else>
          <div v-for="d in displayedDomains" :key="d" class="mb-8 last:mb-0">
            <h2 class="text-lg font-semibold text-gray-800 mb-3 flex items-center gap-2">
              <span
                class="inline-block w-3 h-3 rounded-full"
                :class="domainDotClass(d)"
              ></span>
              {{ domainLabel(d) }}
              <span class="text-sm font-normal text-gray-400">({{ docsForDomain(d).length }})</span>
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div
                v-for="doc in docsForDomain(d)"
                :key="doc.id"
                class="border border-gray-200 rounded-lg p-4 hover:border-indigo-300 hover:shadow-sm transition-all group"
              >
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <a
                      v-if="doc.download_url"
                      :href="doc.download_url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm font-medium text-indigo-600 hover:text-indigo-800 hover:underline break-words"
                    >
                      {{ doc.name }}
                    </a>
                    <span v-else class="text-sm font-medium text-gray-700">{{ doc.name }}</span>
                    <div class="text-xs text-gray-400 mt-0.5 flex items-center gap-2 flex-wrap">
                      <span v-if="doc.category" class="inline-block px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">
                        {{ subcategoryLabel(doc.domain, doc.category) }}
                      </span>
                      <span v-if="doc.document_date">{{ formatDate(doc.document_date) }}</span>
                      <span v-if="doc.file_size">{{ formatSize(doc.file_size) }}</span>
                    </div>
                    <p v-if="doc.notes" class="text-sm text-gray-600 mt-1.5 line-clamp-2">{{ doc.notes }}</p>
                  </div>
                  <div class="flex gap-1 ml-3 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      @click="editDocument(doc)"
                      class="text-gray-400 hover:text-indigo-600"
                      title="Modifier"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                      </svg>
                    </button>
                    <button
                      @click="deleteDocument(doc.id)"
                      class="text-gray-400 hover:text-red-600"
                      title="Supprimer"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>
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

const { useCrud } = useApi()
const { list, update, destroy } = useCrud('documents')

const documents = ref([])
const showForm = ref(false)
const editingId = ref(null)
const filterDomain = ref('')
const uploading = ref(false)
const fileInput = ref(null)
const selectedFile = ref(null)

const domains = [
  { value: 'civil_status', label: 'Etat civil' },
  { value: 'education', label: 'Formations' },
  { value: 'work', label: 'Travail' },
  { value: 'taxes', label: 'Impots' },
  { value: 'banking', label: 'Banques' },
  { value: 'invoices', label: 'Factures' },
  { value: 'health', label: 'Sante' },
  { value: 'real_estate', label: 'Immobilier' },
  { value: 'companies', label: 'Entreprises' },
  { value: 'leisure', label: 'Loisirs' },
  { value: 'projects', label: 'Projets' },
  { value: 'general', label: 'General' },
]

const subcategoriesByDomain = {
  health: [
    { value: 'analysis', label: 'Analyse' },
    { value: 'prescription', label: 'Ordonnance' },
    { value: 'report', label: 'Compte-rendu' },
    { value: 'certificate', label: 'Certificat' },
    { value: 'imaging', label: 'Imagerie' },
    { value: 'vaccination', label: 'Vaccination' },
    { value: 'other', label: 'Autre' },
  ],
  real_estate: [
    { value: 'lease', label: 'Bail' },
    { value: 'deed', label: 'Acte' },
    { value: 'diagnostic', label: 'Diagnostic' },
    { value: 'insurance', label: 'Assurance' },
    { value: 'invoice', label: 'Facture' },
    { value: 'tax_notice', label: 'Avis d\'imposition' },
    { value: 'other', label: 'Autre' },
  ],
  taxes: [
    { value: 'income_tax', label: 'Impot sur le revenu' },
    { value: 'property_tax', label: 'Taxe fonciere' },
    { value: 'notice', label: 'Avis' },
    { value: 'declaration', label: 'Declaration' },
    { value: 'receipt', label: 'Recu' },
    { value: 'other', label: 'Autre' },
  ],
  companies: [
    { value: 'invoice', label: 'Facture' },
    { value: 'quote', label: 'Devis' },
    { value: 'contract', label: 'Contrat' },
    { value: 'kbis', label: 'Kbis' },
    { value: 'statutes', label: 'Statuts' },
    { value: 'other', label: 'Autre' },
  ],
  general: [
    { value: 'identity', label: 'Identite' },
    { value: 'administrative', label: 'Administratif' },
    { value: 'insurance', label: 'Assurance' },
    { value: 'other', label: 'Autre' },
  ],
  education: [
    { value: 'diploma', label: 'Diplome' },
    { value: 'certificate', label: 'Attestation' },
    { value: 'transcript', label: 'Releve de notes' },
    { value: 'course_material', label: 'Support de cours' },
    { value: 'other', label: 'Autre' },
  ],
  invoices: [
    { value: 'utility', label: 'Energie / eau' },
    { value: 'telecom', label: 'Telecom' },
    { value: 'subscription', label: 'Abonnement' },
    { value: 'service', label: 'Service' },
    { value: 'purchase', label: 'Achat' },
    { value: 'other', label: 'Autre' },
  ],
  banking: [
    { value: 'statement', label: 'Releve' },
    { value: 'contract', label: 'Contrat' },
    { value: 'card_info', label: 'Carte' },
    { value: 'loan', label: 'Pret' },
    { value: 'other', label: 'Autre' },
  ],
  civil_status: [
    { value: 'id_card', label: 'Carte d\'identite' },
    { value: 'passport', label: 'Passeport' },
    { value: 'birth_certificate', label: 'Acte de naissance' },
    { value: 'family_book', label: 'Livret de famille' },
    { value: 'marriage_certificate', label: 'Acte de mariage' },
    { value: 'other', label: 'Autre' },
  ],
  work: [
    { value: 'contract', label: 'Contrat' },
    { value: 'payslip', label: 'Fiche de paie' },
    { value: 'certificate', label: 'Attestation' },
    { value: 'evaluation', label: 'Evaluation' },
    { value: 'other', label: 'Autre' },
  ],
  leisure: [
    { value: 'ticket', label: 'Billet' },
    { value: 'booking', label: 'Reservation' },
    { value: 'membership', label: 'Adhesion' },
    { value: 'manual', label: 'Notice' },
    { value: 'other', label: 'Autre' },
  ],
  projects: [
    { value: 'reference', label: 'Reference' },
    { value: 'brief', label: 'Cahier des charges' },
    { value: 'asset', label: 'Ressource' },
    { value: 'tutorial', label: 'Tutoriel' },
    { value: 'contract', label: 'Contrat' },
    { value: 'other', label: 'Autre' },
  ],
}

const domainLabels = Object.fromEntries(domains.map(d => [d.value, d.label]))

const domainColors = {
  civil_status: 'bg-rose-500',
  education: 'bg-indigo-500',
  work: 'bg-blue-500',
  taxes: 'bg-yellow-500',
  banking: 'bg-emerald-500',
  invoices: 'bg-orange-500',
  health: 'bg-red-500',
  real_estate: 'bg-amber-600',
  companies: 'bg-purple-500',
  leisure: 'bg-pink-500',
  projects: 'bg-indigo-500',
  general: 'bg-gray-500',
}

const defaultForm = {
  name: '',
  domain: '',
  category: '',
  document_date: '',
  notes: '',
}

const form = reactive({ ...defaultForm })

const domainLabel = (v) => domainLabels[v] || v
const domainDotClass = (v) => domainColors[v] || 'bg-gray-500'
const subcategories = (domain) => subcategoriesByDomain[domain] || []
const subcategoryLabel = (domain, value) => {
  const list = subcategoriesByDomain[domain] || []
  const item = list.find(c => c.value === value)
  return item ? item.label : value
}

const usedDomains = computed(() => {
  const set = new Set(documents.value.map(d => d.domain).filter(Boolean))
  return domains.map(d => d.value).filter(v => set.has(v))
})

const displayedDomains = computed(() => {
  if (filterDomain.value) return [filterDomain.value]
  return usedDomains.value
})

const domainCount = (d) => documents.value.filter(doc => doc.domain === d).length

const docsForDomain = (d) => {
  return documents.value
    .filter(doc => doc.domain === d)
    .sort((a, b) => {
      const da = a.document_date || a.created_at
      const db = b.document_date || b.created_at
      return new Date(db) - new Date(da)
    })
}

const formatDate = (iso) => {
  if (!iso) return ''
  try {
    return new Date(iso).toLocaleDateString('fr-FR')
  } catch {
    return iso
  }
}

const formatSize = (bytes) => {
  if (!bytes) return ''
  if (bytes < 1024) return `${bytes} o`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} Ko`
  return `${(bytes / (1024 * 1024)).toFixed(1)} Mo`
}

const onFileChange = (e) => {
  const file = e.target.files[0]
  selectedFile.value = file
  if (file && !form.name.trim()) {
    form.name = file.name.replace(/\.[^.]+$/, '')
  }
}

const fetchDocuments = async () => {
  documents.value = await list()
}

const openForm = () => {
  if (showForm.value && !editingId.value) {
    showForm.value = false
    return
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  selectedFile.value = null
  if (fileInput.value) fileInput.value.value = ''
  showForm.value = true
}

const saveDocument = async () => {
  if (editingId.value) {
    await update(editingId.value, {
      name: form.name,
      domain: form.domain,
      category: form.category,
      document_date: form.document_date || null,
      notes: form.notes,
    })
  } else {
    if (!selectedFile.value) return
    uploading.value = true
    try {
      const data = new FormData()
      data.append('name', form.name)
      data.append('domain', form.domain)
      data.append('file', selectedFile.value)
      if (form.category) data.append('category', form.category)
      if (form.document_date) data.append('document_date', form.document_date)
      if (form.notes) data.append('notes', form.notes)
      await apiClient.post('/documents', data, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
    } catch (e) {
      console.error('Erreur upload:', e)
      uploading.value = false
      return
    }
    uploading.value = false
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  selectedFile.value = null
  if (fileInput.value) fileInput.value.value = ''
  showForm.value = false
  await fetchDocuments()
}

const editDocument = (doc) => {
  editingId.value = doc.id
  Object.assign(form, {
    name: doc.name,
    domain: doc.domain,
    category: doc.category || '',
    document_date: doc.document_date || '',
    notes: doc.notes || '',
  })
  showForm.value = true
}

const cancelEdit = () => {
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  selectedFile.value = null
  if (fileInput.value) fileInput.value.value = ''
  showForm.value = false
}

const deleteDocument = async (id) => {
  if (!confirm('Supprimer ce document ?')) return
  await destroy(id)
  await fetchDocuments()
}

onMounted(fetchDocuments)
</script>
