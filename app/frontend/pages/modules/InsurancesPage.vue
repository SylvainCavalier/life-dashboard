<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes assurances</h1>
        <div class="flex flex-wrap justify-end gap-2">
          <button @click="openImport" class="bg-white border border-gray-300 text-gray-800 text-sm px-4 py-2 rounded-lg hover:border-gray-500 transition">
            Importer un contrat (IA)
          </button>
          <button @click="openForm" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
            + Nouvelle assurance
          </button>
        </div>
      </div>

      <InsuranceImport
        v-if="showImport"
        class="mb-6"
        @created="insurance => router.push(`/insurances/${insurance.id}`)"
        @cancel="showImport = false"
      />

      <InsuranceForm
        v-else-if="showForm"
        class="mb-6"
        :default-type="filterType || 'habitation'"
        :saving="saving"
        :errors="formErrors"
        @submit="createInsurance"
        @cancel="showForm = false"
      />

      <!-- Synthese -->
      <div v-if="activeInsurances.length" class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">Contrats en cours</p>
          <p class="text-2xl font-semibold text-gray-900">{{ activeInsurances.length }}</p>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">Cotisations annuelles</p>
          <p class="text-2xl font-semibold text-gray-900">{{ formatEuros(totalAnnual) }}</p>
          <p class="text-xs text-gray-400">soit {{ formatEuros(totalAnnual / 12) }} par mois</p>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">Prochaine échéance</p>
          <template v-if="nextRenewal">
            <p class="text-base font-semibold text-gray-900">{{ formatDate(nextRenewal.next_renewal_on) }}</p>
            <p class="text-xs text-gray-400 truncate">{{ nextRenewal.name }}</p>
          </template>
          <p v-else class="text-sm text-gray-400 mt-1">Aucune date d'échéance saisie</p>
        </div>
      </div>

      <!-- Types -->
      <div class="flex flex-wrap gap-2 mb-4">
        <button
          @click="filterType = ''"
          class="text-sm px-3 py-1.5 rounded-full border transition"
          :class="filterType === '' ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
        >
          Toutes <span class="opacity-60">{{ searched.length }}</span>
        </button>
        <button
          v-for="t in visibleTypes"
          :key="t.value"
          @click="filterType = t.value"
          class="text-sm px-3 py-1.5 rounded-full border transition"
          :class="filterType === t.value ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
        >
          {{ t.icon }} {{ t.label }} <span class="opacity-60">{{ countByType[t.value] || 0 }}</span>
        </button>
      </div>

      <div class="flex flex-wrap gap-3 mb-4">
        <input v-model="search" type="text" placeholder="Rechercher (contrat, assureur, bien assuré...)" class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
        <label class="flex items-center gap-2 text-sm text-gray-600">
          <input v-model="showTerminated" type="checkbox" class="rounded" />
          Afficher les contrats résiliés
        </label>
      </div>

      <div v-if="loaded && filtered.length === 0" class="text-center text-gray-400 py-12">
        Aucune assurance
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <router-link
          v-for="insurance in filtered"
          :key="insurance.id"
          :to="`/insurances/${insurance.id}`"
          class="bg-white rounded-xl shadow-sm p-5 transition-all hover:shadow-md block"
          :class="{ 'opacity-60': insurance.status === 'resiliee' }"
        >
          <div class="flex items-start justify-between gap-3 mb-2">
            <h3 class="font-semibold text-gray-900 text-lg leading-tight">{{ typeIcon(insurance.insurance_type) }} {{ insurance.name }}</h3>
            <span v-if="insurance.annual_premium" class="text-sm font-medium text-gray-700 flex-shrink-0">{{ formatEuros(insurance.annual_premium) }}/an</span>
          </div>
          <div class="flex flex-wrap items-center gap-2 mb-2">
            <span :class="typeBadge(insurance.insurance_type)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ typeLabel(insurance.insurance_type) }}</span>
            <span :class="statusBadge(insurance.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(insurance.status) }}</span>
            <span v-if="insurance.insurer" class="text-xs text-gray-500">{{ insurance.insurer }}</span>
          </div>
          <p v-if="insurance.item_names.length" class="text-sm text-gray-600 mb-2 line-clamp-2">
            Couvre : {{ insurance.item_names.join(', ') }}
          </p>
          <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500 pt-2 border-t border-gray-100">
            <span v-if="insurance.next_renewal_on" :class="renewalClass(insurance)">Échéance : {{ formatDate(insurance.next_renewal_on) }}</span>
            <span v-if="insurance.coverages_count">{{ insurance.coverages_count }} garantie{{ insurance.coverages_count > 1 ? 's' : '' }}</span>
            <span v-if="insurance.documents_count">{{ insurance.documents_count }} document{{ insurance.documents_count > 1 ? 's' : '' }}</span>
            <span v-if="!insurance.coverages_count && !insurance.documents_count" class="text-gray-400">Ouvrir pour ajouter garanties et documents...</span>
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
  insuranceTypes, typeLabel, typeIcon, typeBadge, statusLabel, statusBadge,
  formatEuros, formatDate, daysUntil,
} from '../../composables/useInsurances'
import InsuranceForm from '../../components/insurances/InsuranceForm.vue'
import InsuranceImport from '../../components/insurances/InsuranceImport.vue'

const router = useRouter()
const { useCrud } = useApi()
const { list, create } = useCrud('insurances')

const insurances = ref([])
const loaded = ref(false)
const showForm = ref(false)
const showImport = ref(false)
const saving = ref(false)
const formErrors = ref([])
const search = ref('')
const filterType = ref('')
const showTerminated = ref(false)

const activeInsurances = computed(() => insurances.value.filter(i => i.status === 'active'))
const totalAnnual = computed(() => activeInsurances.value.reduce((sum, i) => sum + Number(i.annual_premium || 0), 0))
const nextRenewal = computed(() =>
  activeInsurances.value.filter(i => i.next_renewal_on).sort((a, b) => a.next_renewal_on.localeCompare(b.next_renewal_on))[0]
)

// Recherche + statut, avant le filtre de type : sert aussi aux compteurs des pastilles.
const searched = computed(() => {
  let result = insurances.value
  if (!showTerminated.value) result = result.filter(i => i.status !== 'resiliee')
  const q = search.value.toLowerCase()
  if (q) {
    result = result.filter(i =>
      [i.name, i.insurer, i.policy_number, ...i.item_names].some(text => text && text.toLowerCase().includes(q))
    )
  }
  return result
})

const countByType = computed(() => {
  const counts = {}
  searched.value.forEach(i => { counts[i.insurance_type] = (counts[i.insurance_type] || 0) + 1 })
  return counts
})

const visibleTypes = computed(() =>
  insuranceTypes.filter(t => insurances.value.some(i => i.insurance_type === t.value) || filterType.value === t.value)
)

const filtered = computed(() =>
  filterType.value ? searched.value.filter(i => i.insurance_type === filterType.value) : searched.value
)

// Deux mois avant l'echeance principale : le delai de resiliation le plus courant.
const renewalClass = (insurance) => {
  const days = daysUntil(insurance.next_renewal_on)
  return days !== null && days <= 60 ? 'text-orange-600 font-medium' : ''
}

// Saisie manuelle et import par l'IA s'excluent : un seul panneau ouvert.
const openForm = () => {
  showImport.value = false
  showForm.value = !showForm.value
}

const openImport = () => {
  showForm.value = false
  showImport.value = true
}

const createInsurance = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    const insurance = await create({ insurance: attributes })
    router.push(`/insurances/${insurance.id}`)
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

onMounted(async () => {
  insurances.value = await list() || []
  loaded.value = true
})
</script>
