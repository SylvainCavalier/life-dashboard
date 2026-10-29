<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/vehicles" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour aux véhicules
      </router-link>

      <div v-if="vehicle" class="space-y-6">
        <!-- En-tete -->
        <div v-if="!editing" class="bg-white rounded-xl shadow-sm p-6">
          <div class="flex items-start justify-between gap-4 mb-4">
            <div class="min-w-0">
              <div class="flex flex-wrap items-center gap-2 mb-1">
                <h1 class="text-2xl font-bold text-gray-900">{{ typeIcon(vehicle.vehicle_type) }} {{ vehicle.name }}</h1>
                <span :class="typeBadge(vehicle.vehicle_type)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ typeLabel(vehicle.vehicle_type) }}</span>
                <span :class="statusBadge(vehicle.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(vehicle.status) }}</span>
                <span v-if="vehicle.registration_number" class="text-xs font-mono border border-gray-300 rounded px-1.5 py-0.5 text-gray-700">{{ vehicle.registration_number }}</span>
              </div>
              <p class="text-sm text-gray-600">{{ [vehicle.brand, vehicle.model, vehicle.version].filter(Boolean).join(' ') }}<template v-if="vehicle.year"> · {{ vehicle.year }}</template></p>
            </div>
            <div class="flex items-center gap-3 flex-shrink-0">
              <button @click="editing = true" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteVehicle" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>

          <!-- Echeances et kilometrage -->
          <dl class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm">
            <div class="bg-gray-50 rounded-lg p-3">
              <dt class="text-xs text-gray-500">Kilométrage</dt>
              <dd v-if="!editingMileage" class="text-gray-900">
                {{ vehicle.mileage ? formatKm(vehicle.mileage) : '-' }}
                <button @click="startMileage" class="ml-2 text-xs text-blue-500 hover:text-blue-700">Mettre à jour</button>
              </dd>
              <dd v-else class="flex gap-2 mt-1">
                <input v-model="newMileage" type="number" min="0" class="w-28 border rounded-lg px-2 py-1 text-sm" @keyup.enter="saveMileage" />
                <button @click="saveMileage" :disabled="saving" class="text-xs bg-blue-600 text-white rounded-lg px-2 py-1 disabled:opacity-50">OK</button>
                <button @click="editingMileage = false" class="text-xs text-gray-500">Annuler</button>
              </dd>
              <dd v-if="vehicle.mileage_on && !editingMileage" class="text-xs text-gray-400">relevé le {{ formatDate(vehicle.mileage_on) }}</dd>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <dt class="text-xs text-gray-500">Prochain contrôle technique</dt>
              <dd :class="dueClass(vehicle.inspection_status)">{{ vehicle.next_inspection_on ? formatDate(vehicle.next_inspection_on) : '-' }}</dd>
              <dd v-if="vehicle.inspection_status === 'overdue'" class="text-xs text-red-500">Dépassé : à passer sans tarder</dd>
              <dd v-else-if="vehicle.inspection_status === 'due_soon'" class="text-xs text-orange-500">Prendre rendez-vous</dd>
              <dd v-if="vehicle.first_inspection_computed" class="text-xs text-gray-400">Premier contrôle, déduit de la mise en circulation</dd>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <dt class="text-xs text-gray-500">Prochaine révision</dt>
              <dd v-if="vehicle.next_service_on || vehicle.next_service_mileage" :class="dueClass(vehicle.service_status)">
                {{ [vehicle.next_service_on && formatDate(vehicle.next_service_on), vehicle.next_service_mileage && formatKm(vehicle.next_service_mileage)].filter(Boolean).join(' ou ') }}
              </dd>
              <dd v-else class="text-gray-400 text-xs mt-0.5">{{ serviceHint }}</dd>
              <dd v-if="vehicle.service_mileage_left !== null && vehicle.service_mileage_left !== undefined" class="text-xs text-gray-400">
                {{ vehicle.service_mileage_left >= 0 ? `encore ${formatKm(vehicle.service_mileage_left)}` : `${formatKm(-vehicle.service_mileage_left)} de dépassement` }}
              </dd>
              <dd v-if="vehicle.last_service_on" class="text-xs text-gray-400">dernière le {{ formatDate(vehicle.last_service_on) }}</dd>
            </div>
          </dl>

          <!-- Caracteristiques -->
          <dl v-if="specs.length" class="grid grid-cols-2 md:grid-cols-4 gap-x-4 gap-y-3 mt-4 pt-4 border-t border-gray-100 text-sm">
            <div v-for="spec in specs" :key="spec.label" :class="spec.wide ? 'col-span-2' : ''">
              <dt class="text-xs text-gray-500">{{ spec.label }}</dt>
              <dd class="text-gray-900" :class="spec.mono ? 'font-mono text-xs break-all' : ''">{{ spec.value }}</dd>
            </div>
          </dl>

          <div v-if="vehicle.notes" class="mt-4 pt-4 border-t border-gray-100">
            <h2 class="text-xs text-gray-500 mb-1">Notes</h2>
            <p class="text-sm text-gray-600 whitespace-pre-line">{{ vehicle.notes }}</p>
          </div>
        </div>
        <VehicleForm v-else :initial="vehicle" :saving="saving" :errors="formErrors" @submit="saveVehicle" @cancel="editing = false" />

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
          <VehicleInterventions
            :key="vehicle.id"
            :vehicle-id="vehicle.id"
            :mileage="vehicle.mileage"
            :initial="vehicle.interventions"
            @vehicle-updated="onVehicleUpdated"
          />

          <div class="space-y-6">
            <!-- Assurances -->
            <div class="bg-white rounded-xl shadow-sm p-5">
              <div class="flex items-center justify-between mb-3">
                <h2 class="text-lg font-semibold text-gray-900">Assurance</h2>
                <router-link to="/insurances" class="text-blue-600 hover:text-blue-800 text-sm font-medium">Page Assurances</router-link>
              </div>
              <ul v-if="vehicle.insurances.length" class="space-y-2">
                <li v-for="insurance in vehicle.insurances" :key="insurance.id" class="p-3 rounded-lg bg-gray-50">
                  <router-link :to="`/insurances/${insurance.id}`" class="text-sm font-medium text-gray-900 hover:text-blue-600">{{ insurance.name }}</router-link>
                  <span v-if="insurance.status !== 'active'" class="ml-2 text-xs bg-gray-200 text-gray-600 px-2 py-0.5 rounded-full">{{ insurance.status === 'resiliee' ? 'Résiliée' : 'Suspendue' }}</span>
                  <p class="text-xs text-gray-500 mt-0.5">
                    {{ insurance.insurer }}<template v-if="insurance.policy_number"> · contrat n° {{ insurance.policy_number }}</template>
                  </p>
                  <p v-if="insurance.claims_phone" class="text-xs mt-0.5">
                    Sinistre / assistance : <a :href="`tel:${insurance.claims_phone}`" class="text-blue-600 hover:text-blue-800 font-medium">{{ insurance.claims_phone }}</a>
                  </p>
                </li>
              </ul>
              <p v-else class="text-sm text-gray-400">
                Aucun contrat lié. Sur la page du contrat, ajoutez ce véhicule dans « Ce qui est assuré ».
              </p>
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
                    <option v-for="c in vehicleDocCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
                  </select>
                </div>
                <p class="text-xs text-gray-400">Les PDF et photos sont lus par Alfred : carte grise, procès-verbaux de contrôle technique, factures du garage.</p>
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

      <div v-else-if="notFound" class="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">Véhicule introuvable</div>
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
  vehicleDocCategories, typeLabel, typeIcon, typeBadge, statusLabel, statusBadge, fuelLabel,
  docCategoryLabel, dueClass, formatEuros, formatDate, formatKm,
} from '../../composables/useVehicles'
import VehicleForm from '../../components/vehicles/VehicleForm.vue'
import VehicleInterventions from '../../components/vehicles/VehicleInterventions.vue'

const route = useRoute()
const router = useRouter()
const vehicleId = route.params.id

const { get, patch, delete: del } = useApi()

const vehicle = ref(null)
const notFound = ref(false)
const editing = ref(false)
const saving = ref(false)
const formErrors = ref([])
const editingMileage = ref(false)
const newMileage = ref('')

const documents = ref([])
const showDocForm = ref(false)
const docUploading = ref(false)
const docError = ref('')
const docFileInput = ref(null)
const selectedDocFile = ref(null)
const docForm = reactive({ name: '', category: '', document_date: '' })

const serviceHint = computed(() => {
  const v = vehicle.value
  if (!v.service_interval_km && !v.service_interval_months) return 'Renseignez la périodicité de révision (Modifier)'
  return 'Consignez la dernière révision dans le carnet'
})

const specs = computed(() => {
  const v = vehicle.value
  return [
    v.first_registration_on && { label: '1re mise en circulation', value: formatDate(v.first_registration_on) },
    v.fuel && { label: 'Énergie', value: fuelLabel(v.fuel) },
    v.fiscal_power && { label: 'Puissance fiscale', value: `${v.fiscal_power} CV` },
    v.power_hp && { label: 'Puissance', value: `${v.power_hp} ch` },
    v.engine_displacement && { label: 'Cylindrée', value: `${v.engine_displacement.toLocaleString('fr-FR')} cm³` },
    v.color && { label: 'Couleur', value: v.color },
    v.tire_size && { label: 'Pneus', value: v.tire_size },
    v.oil_type && { label: 'Huile', value: v.oil_type },
    (v.service_interval_km || v.service_interval_months) && {
      label: 'Révision',
      value: ['tous les', [v.service_interval_km && formatKm(v.service_interval_km), v.service_interval_months && `${v.service_interval_months} mois`].filter(Boolean).join(' ou ')].join(' '),
    },
    v.purchased_on && {
      label: 'Achat',
      value: [formatDate(v.purchased_on), v.purchase_price && formatEuros(v.purchase_price), v.purchase_mileage && formatKm(v.purchase_mileage)].filter(Boolean).join(' · '),
    },
    v.status === 'vendu' && (v.sold_on || v.sale_price) && {
      label: 'Vente',
      value: [v.sold_on && formatDate(v.sold_on), v.sale_price && formatEuros(v.sale_price)].filter(Boolean).join(' · '),
    },
    Number(v.total_cost) > 0 && { label: 'Frais consignés', value: formatEuros(v.total_cost) },
    v.vin && { label: 'N° de série (VIN)', value: v.vin, mono: true, wide: true },
  ].filter(Boolean)
})

const fetchVehicle = async () => {
  try {
    vehicle.value = await get(`/vehicles/${vehicleId}`)
  } catch {
    notFound.value = true
  }
}

const fetchDocuments = async () => {
  documents.value = await get('/documents', { params: { vehicle_id: vehicleId } }) || []
}

const saveVehicle = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    vehicle.value = await patch(`/vehicles/${vehicleId}`, { vehicle: attributes })
    editing.value = false
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const startMileage = () => {
  newMileage.value = vehicle.value.mileage ?? ''
  editingMileage.value = true
}

const saveMileage = async () => {
  if (newMileage.value === '') return
  saving.value = true
  try {
    vehicle.value = await patch(`/vehicles/${vehicleId}`, {
      vehicle: { mileage: newMileage.value, mileage_on: new Date().toLocaleDateString('sv-SE') },
    })
    editingMileage.value = false
  } catch (e) {
    alert(e.response?.data?.errors?.join(', ') || 'Enregistrement impossible')
  } finally {
    saving.value = false
  }
}

// Une intervention peut changer le kilometrage et le prochain controle : le carnet
// renvoie la fiche a jour (il garde sa propre liste, d'ou la cle stable du composant).
const onVehicleUpdated = (updated) => {
  vehicle.value = updated
}

const deleteVehicle = async () => {
  if (!confirm('Supprimer ce véhicule et son carnet d\'entretien ? Ses documents restent dans la page Documents.')) return
  try {
    await del(`/vehicles/${vehicleId}`)
    router.push('/vehicles')
  } catch {
    alert('Suppression impossible')
  }
}

// Documents (domaine vehicles, rattaches au vehicule)
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
  formData.append('domain', 'vehicles')
  formData.append('vehicle_id', vehicleId)
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
  fetchVehicle()
  fetchDocuments()
})
</script>
