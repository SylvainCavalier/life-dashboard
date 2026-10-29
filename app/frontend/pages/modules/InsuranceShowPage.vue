<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/insurances" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour aux assurances
      </router-link>

      <div v-if="insurance" class="space-y-6">
        <!-- En-tete -->
        <div v-if="!editing" class="bg-white rounded-xl shadow-sm p-6">
          <div class="flex items-start justify-between gap-4 mb-4">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <h1 class="text-2xl font-bold text-gray-900">{{ typeIcon(insurance.insurance_type) }} {{ insurance.name }}</h1>
                <span :class="typeBadge(insurance.insurance_type)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ typeLabel(insurance.insurance_type) }}</span>
                <span :class="statusBadge(insurance.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(insurance.status) }}</span>
              </div>
              <p class="text-sm text-gray-600">
                <span v-if="insurance.insurer">{{ insurance.insurer }}</span>
                <span v-if="insurance.insurer && insurance.policy_number"> · </span>
                <span v-if="insurance.policy_number">Contrat n° {{ insurance.policy_number }}</span>
              </p>
            </div>
            <div class="flex items-center gap-3 flex-shrink-0">
              <button @click="editing = true" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteInsurance" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>

          <dl class="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
            <div>
              <dt class="text-xs text-gray-500">Cotisation</dt>
              <dd class="text-gray-900">
                <template v-if="insurance.premium">{{ formatEuros(insurance.premium) }} {{ frequencyLabel(insurance.premium_frequency) }}</template>
                <span v-else class="text-gray-400">-</span>
              </dd>
              <dd v-if="insurance.premium && insurance.premium_frequency !== 'yearly'" class="text-xs text-gray-400">{{ formatEuros(insurance.annual_premium) }} par an</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-500">Prochaine échéance</dt>
              <dd :class="renewalSoon ? 'text-orange-600 font-medium' : 'text-gray-900'">
                {{ insurance.next_renewal_on ? formatDate(insurance.next_renewal_on) : '-' }}
              </dd>
              <dd v-if="renewalSoon" class="text-xs text-orange-500">Dernier moment pour résilier ou renégocier</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-500">Début</dt>
              <dd class="text-gray-900">{{ insurance.start_date ? formatDate(insurance.start_date) : '-' }}</dd>
            </div>
            <div>
              <dt class="text-xs text-gray-500">Fin</dt>
              <dd class="text-gray-900">{{ insurance.end_date ? formatDate(insurance.end_date) : 'Tacite reconduction' }}</dd>
            </div>
          </dl>

          <div v-if="hasContacts" class="flex flex-wrap gap-x-6 gap-y-2 mt-4 pt-4 border-t border-gray-100 text-sm">
            <p v-if="insurance.claims_phone">
              <span class="text-xs text-gray-500 block">Sinistre / assistance</span>
              <a :href="`tel:${insurance.claims_phone}`" class="text-blue-600 hover:text-blue-800 font-medium">{{ insurance.claims_phone }}</a>
            </p>
            <p v-if="insurance.advisor_name || insurance.advisor_phone || insurance.advisor_email">
              <span class="text-xs text-gray-500 block">Conseiller</span>
              <span class="text-gray-900">{{ insurance.advisor_name }}</span>
              <a v-if="insurance.advisor_phone" :href="`tel:${insurance.advisor_phone}`" class="text-blue-600 hover:text-blue-800 ml-2">{{ insurance.advisor_phone }}</a>
              <a v-if="insurance.advisor_email" :href="`mailto:${insurance.advisor_email}`" class="text-blue-600 hover:text-blue-800 ml-2">{{ insurance.advisor_email }}</a>
            </p>
            <p v-if="insurance.website_url">
              <span class="text-xs text-gray-500 block">Espace client</span>
              <a :href="insurance.website_url" target="_blank" rel="noopener" class="text-blue-600 hover:text-blue-800 underline">{{ hostnameOf(insurance.website_url) }}</a>
            </p>
          </div>

          <div v-if="insurance.conditions" class="mt-4 pt-4 border-t border-gray-100">
            <h2 class="text-xs text-gray-500 mb-1">Conditions importantes</h2>
            <p class="text-sm text-gray-800 whitespace-pre-line">{{ insurance.conditions }}</p>
          </div>
          <div v-if="insurance.notes" class="mt-4 pt-4 border-t border-gray-100">
            <h2 class="text-xs text-gray-500 mb-1">Notes</h2>
            <p class="text-sm text-gray-600 whitespace-pre-line">{{ insurance.notes }}</p>
          </div>
        </div>
        <InsuranceForm v-else :initial="insurance" :saving="saving" :errors="formErrors" @submit="saveInsurance" @cancel="editing = false" />

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          <InsuranceCoverages :insurance-id="insurance.id" :insurance-type="insurance.insurance_type" :initial="insurance.coverages" />

          <div class="space-y-6">
            <InsuredItems :insurance-id="insurance.id" :insurance-type="insurance.insurance_type" :initial="insurance.items" />

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
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div class="sm:col-span-2">
                    <label class="block text-xs text-gray-500 mb-1">Nom *</label>
                    <input v-model="docForm.name" type="text" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm" />
                  </div>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Date</label>
                    <input v-model="docForm.document_date" type="date" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm" />
                  </div>
                </div>
                <div>
                  <label class="block text-xs text-gray-500 mb-1">Catégorie</label>
                  <select v-model="docForm.category" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
                    <option value="">-- Choisir --</option>
                    <option v-for="c in insuranceDocCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
                  </select>
                </div>
                <p class="text-xs text-gray-400">Les PDF et scans sont lus par Alfred : déposez les conditions générales et particulières pour qu'il puisse répondre sur ce qui est couvert.</p>
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
                    <span class="block text-xs text-gray-400 truncate">
                      <template v-if="doc.document_date">{{ formatDate(doc.document_date) }} · </template>{{ doc.file_name }} · {{ formatSize(doc.file_size) }}
                    </span>
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

      <div v-else-if="notFound" class="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">Assurance introuvable</div>
      <div v-else class="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">Chargement...</div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import apiClient from '../../plugins/axios'
import {
  insuranceDocCategories, typeLabel, typeIcon, typeBadge, statusLabel, statusBadge,
  frequencyLabel, docCategoryLabel, formatEuros, formatDate, daysUntil,
} from '../../composables/useInsurances'
import InsuranceForm from '../../components/insurances/InsuranceForm.vue'
import InsuranceCoverages from '../../components/insurances/InsuranceCoverages.vue'
import InsuredItems from '../../components/insurances/InsuredItems.vue'

const route = useRoute()
const router = useRouter()
const insuranceId = route.params.id

const { get, patch, delete: del } = useApi()

const insurance = ref(null)
const notFound = ref(false)
const editing = ref(false)
const saving = ref(false)
const formErrors = ref([])

const documents = ref([])
const showDocForm = ref(false)
const docUploading = ref(false)
const docError = ref('')
const docFileInput = ref(null)
const selectedDocFile = ref(null)
const docForm = reactive({ name: '', category: '', document_date: '' })

const hasContacts = computed(() => {
  const i = insurance.value
  return i.claims_phone || i.advisor_name || i.advisor_phone || i.advisor_email || i.website_url
})

// Deux mois avant l'echeance principale : le delai de resiliation le plus courant.
const renewalSoon = computed(() => {
  const days = daysUntil(insurance.value?.next_renewal_on)
  return days !== null && days <= 60
})

const hostnameOf = (url) => {
  try {
    return new URL(url).hostname.replace(/^www\./, '')
  } catch {
    return url
  }
}

const fetchInsurance = async () => {
  try {
    insurance.value = await get(`/insurances/${insuranceId}`)
  } catch {
    notFound.value = true
  }
}

const fetchDocuments = async () => {
  documents.value = await get('/documents', { params: { insurance_id: insuranceId } }) || []
}

const saveInsurance = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    insurance.value = await patch(`/insurances/${insuranceId}`, { insurance: attributes })
    editing.value = false
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const deleteInsurance = async () => {
  if (!confirm('Supprimer ce contrat, ses garanties et ses biens assurés ? Ses documents restent dans la page Documents.')) return
  try {
    await del(`/insurances/${insuranceId}`)
    router.push('/insurances')
  } catch {
    alert('Suppression impossible')
  }
}

// Documents (domaine insurance, rattaches au contrat)
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
  formData.append('domain', 'insurance')
  formData.append('insurance_id', insuranceId)
  formData.append('name', docForm.name)
  formData.append('file', selectedDocFile.value)
  if (docForm.category) formData.append('category', docForm.category)
  if (docForm.document_date) formData.append('document_date', docForm.document_date)
  try {
    const response = await apiClient.post('/documents', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    documents.value.unshift(response.data)
    showDocForm.value = false
    Object.assign(docForm, { name: '', category: '', document_date: '' })
    selectedDocFile.value = null
    if (docFileInput.value) docFileInput.value.value = ''
  } catch (e) {
    docError.value = e.response?.data?.errors?.join(', ') || 'Envoi impossible'
  } finally {
    docUploading.value = false
  }
}

const deleteDocument = async (doc) => {
  if (!confirm('Supprimer ce document ?')) return
  try {
    await del(`/documents/${doc.id}`)
    documents.value = documents.value.filter(d => d.id !== doc.id)
  } catch {
    alert('Suppression impossible')
  }
}

const formatSize = (bytes) => {
  if (!bytes) return ''
  if (bytes < 1024 * 1024) return `${Math.max(1, Math.round(bytes / 1024))} Ko`
  return `${(bytes / (1024 * 1024)).toFixed(1)} Mo`
}

onMounted(() => {
  fetchInsurance()
  fetchDocuments()
})
</script>
