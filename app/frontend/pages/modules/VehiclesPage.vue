<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes véhicules</h1>
        <button @click="showForm = !showForm" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouveau véhicule
        </button>
      </div>

      <VehicleForm
        v-if="showForm"
        class="mb-6"
        :saving="saving"
        :errors="formErrors"
        @submit="createVehicle"
        @cancel="showForm = false"
      />

      <!-- Echeances a venir, tous vehicules confondus -->
      <div v-if="upcoming.length" class="bg-white rounded-xl shadow-sm p-4 mb-6">
        <h2 class="text-sm font-semibold text-gray-900 mb-2">Prochaines échéances</h2>
        <ul class="divide-y divide-gray-100">
          <li v-for="due in upcoming" :key="due.key" class="flex items-center justify-between gap-3 py-2 text-sm">
            <router-link :to="`/vehicles/${due.vehicle.id}`" class="min-w-0 truncate text-gray-900 hover:text-blue-600">
              {{ typeIcon(due.vehicle.vehicle_type) }} {{ due.vehicle.name }} · {{ due.label }}
            </router-link>
            <span :class="dueClass(due.status)" class="flex-shrink-0">{{ due.text }}</span>
          </li>
        </ul>
      </div>

      <div class="flex flex-wrap gap-3 mb-4">
        <input v-model="search" type="text" placeholder="Rechercher (nom, marque, modèle, immatriculation...)" class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
        <label class="flex items-center gap-2 text-sm text-gray-600">
          <input v-model="showSold" type="checkbox" class="rounded" />
          Afficher les véhicules vendus
        </label>
      </div>

      <div v-if="loaded && filtered.length === 0" class="text-center text-gray-400 py-12">
        Aucun véhicule
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <router-link
          v-for="vehicle in filtered"
          :key="vehicle.id"
          :to="`/vehicles/${vehicle.id}`"
          class="bg-white rounded-xl shadow-sm p-5 transition-all hover:shadow-md block"
          :class="{ 'opacity-60': vehicle.status === 'vendu' }"
        >
          <div class="flex items-start justify-between gap-3 mb-2">
            <h3 class="font-semibold text-gray-900 text-lg leading-tight">{{ typeIcon(vehicle.vehicle_type) }} {{ vehicle.name }}</h3>
            <span v-if="vehicle.registration_number" class="text-xs font-mono border border-gray-300 rounded px-1.5 py-0.5 text-gray-700 flex-shrink-0">{{ vehicle.registration_number }}</span>
          </div>
          <div class="flex flex-wrap items-center gap-2 mb-2">
            <span :class="typeBadge(vehicle.vehicle_type)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ typeLabel(vehicle.vehicle_type) }}</span>
            <span v-if="vehicle.status !== 'active'" :class="statusBadge(vehicle.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(vehicle.status) }}</span>
            <span v-if="description(vehicle)" class="text-xs text-gray-500">{{ description(vehicle) }}</span>
          </div>
          <p v-if="vehicle.mileage" class="text-sm text-gray-600 mb-2">{{ formatKm(vehicle.mileage) }}<span v-if="vehicle.mileage_on" class="text-gray-400"> au {{ formatDate(vehicle.mileage_on) }}</span></p>
          <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500 pt-2 border-t border-gray-100">
            <span v-if="vehicle.next_inspection_on" :class="dueClass(vehicle.inspection_status)">CT : {{ formatDate(vehicle.next_inspection_on) }}</span>
            <span v-if="vehicle.next_service_on || vehicle.next_service_mileage" :class="dueClass(vehicle.service_status)">
              Révision : {{ serviceText(vehicle) }}
            </span>
            <span v-if="vehicle.interventions_count">{{ vehicle.interventions_count }} intervention{{ vehicle.interventions_count > 1 ? 's' : '' }}</span>
            <span v-if="vehicle.documents_count">{{ vehicle.documents_count }} document{{ vehicle.documents_count > 1 ? 's' : '' }}</span>
            <span v-if="!vehicle.interventions_count && !vehicle.documents_count" class="text-gray-400">Ouvrir pour remplir le carnet et ajouter la carte grise...</span>
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
import {
  typeLabel, typeIcon, typeBadge, statusLabel, statusBadge, dueClass,
  formatDate, formatKm, daysUntil,
} from '../../composables/useVehicles'
import VehicleForm from '../../components/vehicles/VehicleForm.vue'

const router = useRouter()
const { useCrud } = useApi()
const { list, create } = useCrud('vehicles')

const vehicles = ref([])
const loaded = ref(false)
const showForm = ref(false)
const saving = ref(false)
const formErrors = ref([])
const search = ref('')
const showSold = ref(false)

const description = (vehicle) => [vehicle.brand, vehicle.model, vehicle.year].filter(Boolean).join(' ')

const serviceText = (vehicle) => [
  vehicle.next_service_on && formatDate(vehicle.next_service_on),
  vehicle.next_service_mileage && `${formatKm(vehicle.next_service_mileage)}`,
].filter(Boolean).join(' ou ')

const inDays = (iso) => {
  const days = daysUntil(iso)
  if (days < 0) return `en retard de ${-days} j`
  if (days === 0) return "aujourd'hui"
  return `dans ${days} j`
}

// Controles techniques et revisions des vehicules en service, du plus proche au plus lointain.
const upcoming = computed(() => {
  const dues = []
  vehicles.value.filter(v => v.status === 'active').forEach((vehicle) => {
    if (vehicle.next_inspection_on) {
      dues.push({ key: `ct-${vehicle.id}`, vehicle, label: 'Contrôle technique', date: vehicle.next_inspection_on,
                  status: vehicle.inspection_status, text: `${formatDate(vehicle.next_inspection_on)} (${inDays(vehicle.next_inspection_on)})` })
    }
    if (vehicle.next_service_on || vehicle.next_service_mileage) {
      const left = vehicle.service_mileage_left
      const km = left !== null && left !== undefined ? (left < 0 ? `${formatKm(-left)} de dépassement` : `encore ${formatKm(left)}`) : ''
      dues.push({ key: `rev-${vehicle.id}`, vehicle, label: 'Révision', date: vehicle.next_service_on || '9999-12-31',
                  status: vehicle.service_status,
                  text: [vehicle.next_service_on && `${formatDate(vehicle.next_service_on)} (${inDays(vehicle.next_service_on)})`, km].filter(Boolean).join(' · ') })
    }
  })
  return dues.sort((a, b) => a.date.localeCompare(b.date))
})

const filtered = computed(() => {
  let result = vehicles.value
  if (!showSold.value) result = result.filter(v => v.status !== 'vendu')
  const q = search.value.toLowerCase()
  if (q) {
    result = result.filter(v =>
      [v.name, v.brand, v.model, v.version, v.registration_number].some(text => text && text.toLowerCase().includes(q))
    )
  }
  return result
})

const createVehicle = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    const vehicle = await create({ vehicle: attributes })
    router.push(`/vehicles/${vehicle.id}`)
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  vehicles.value = await list() || []
  loaded.value = true
})
</script>
