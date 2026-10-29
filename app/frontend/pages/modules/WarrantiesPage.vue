<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes garanties</h1>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouvelle garantie
        </button>
      </div>

      <WarrantyForm
        v-if="showForm"
        :key="editing?.id || 'new'"
        class="mb-6"
        :initial="editing"
        :saving="saving"
        :errors="formErrors"
        @submit="saveWarranty"
        @cancel="closeForm"
      />

      <!-- Synthese -->
      <div v-if="warranties.length" class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">Objets sous garantie</p>
          <p class="text-2xl font-semibold text-gray-900">{{ underWarranty.length }}</p>
          <p class="text-xs text-gray-400">sur {{ warranties.length }} enregistré{{ warranties.length > 1 ? 's' : '' }}</p>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">Valeur couverte</p>
          <p class="text-2xl font-semibold text-gray-900">{{ formatEuros(coveredValue) || '—' }}</p>
          <p class="text-xs text-gray-400">prix d'achat des objets encore garantis</p>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">Prochaine fin de garantie</p>
          <template v-if="nextEnding">
            <p class="text-base font-semibold" :class="nextEnding.status === 'expiring' ? 'text-orange-600' : 'text-gray-900'">
              {{ formatDate(nextEnding.ends_on) }}
            </p>
            <p class="text-xs text-gray-400 truncate">{{ nextEnding.name }}</p>
          </template>
          <p v-else class="text-sm text-gray-400 mt-1">Plus aucun objet sous garantie</p>
        </div>
      </div>

      <!-- Filtres -->
      <div v-if="warranties.length" class="flex flex-wrap gap-2 mb-4">
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

      <div v-if="warranties.length" class="flex flex-wrap gap-3 mb-4">
        <input v-model="search" type="text" placeholder="Rechercher (objet, marque, vendeur, n° de série...)" class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
        <select v-model="filterCategory" class="border rounded-lg px-3 py-2 text-sm">
          <option value="">Toutes catégories</option>
          <option v-for="c in usedCategories" :key="c.value" :value="c.value">{{ c.icon }} {{ c.label }}</option>
        </select>
      </div>

      <div v-if="loaded && filtered.length === 0" class="text-center text-gray-400 py-12">
        {{ warranties.length ? 'Aucune garantie ne correspond' : 'Aucune garantie enregistrée' }}
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          v-for="warranty in filtered"
          :key="warranty.id"
          class="bg-white rounded-xl shadow-sm p-5"
          :class="{ 'opacity-60': warranty.status === 'expired' }"
        >
          <div class="flex items-start justify-between gap-3 mb-2">
            <div class="min-w-0">
              <h3 class="font-semibold text-gray-900 text-lg leading-tight">{{ categoryIcon(warranty.category) }} {{ warranty.name }}</h3>
              <p v-if="warranty.brand || warranty.model_reference" class="text-sm text-gray-500 truncate">
                {{ [warranty.brand, warranty.model_reference].filter(Boolean).join(' · ') }}
              </p>
            </div>
            <div class="flex gap-2 flex-shrink-0">
              <button @click="openForm(warranty)" class="text-gray-400 hover:text-indigo-600" title="Modifier">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>
              <button @click="deleteWarranty(warranty)" class="text-red-400 hover:text-red-600" title="Supprimer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2 mb-3">
            <span :class="statusBadge(warranty.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(warranty.status) }}</span>
            <span class="text-xs px-2 py-0.5 rounded-full font-medium bg-gray-100 text-gray-600">{{ categoryLabel(warranty.category) }}</span>
            <span v-if="warranty.price" class="text-xs text-gray-500">{{ formatEuros(warranty.price) }}</span>
          </div>

          <!-- Temps de garantie ecoule -->
          <div class="mb-1 h-1.5 bg-gray-100 rounded-full overflow-hidden">
            <div class="h-full rounded-full" :class="barClass(warranty.status)" :style="{ width: `${elapsedPercent(warranty)}%` }"></div>
          </div>
          <div class="flex justify-between text-xs text-gray-500 mb-3">
            <span>Achat : {{ formatDate(warranty.purchased_on) }}</span>
            <span :class="warranty.status === 'expiring' ? 'text-orange-600 font-medium' : ''">
              Fin : {{ formatDate(warranty.ends_on) }} ({{ remainingLabel(warranty.days_left) }})
            </span>
          </div>

          <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500 pt-2 border-t border-gray-100">
            <span v-if="warranty.duration_months">Garantie {{ durationLabel(warranty.duration_months) }}</span>
            <span v-if="warranty.store">Chez {{ warranty.store }}</span>
            <span v-if="warranty.order_number">Commande {{ warranty.order_number }}</span>
            <span v-if="warranty.serial_number">S/N {{ warranty.serial_number }}</span>
            <span v-if="warranty.support_contact">SAV : {{ warranty.support_contact }}</span>
            <a v-if="warranty.receipt" :href="warranty.receipt.url" target="_blank" rel="noopener" class="text-indigo-600 hover:underline">Facture</a>
            <span v-else class="text-gray-400">Pas de facture jointe</span>
          </div>
          <p v-if="warranty.notes" class="text-sm text-gray-600 mt-2 whitespace-pre-line line-clamp-3">{{ warranty.notes }}</p>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import apiClient from '../../plugins/axios'
import {
  warrantyCategories, categoryLabel, categoryIcon, statusLabel, statusBadge, durationLabel,
  remainingLabel, elapsedPercent, formatEuros, formatDate,
} from '../../composables/useWarranties'
import WarrantyForm from '../../components/warranties/WarrantyForm.vue'

const warranties = ref([])
const loaded = ref(false)
const showForm = ref(false)
const editing = ref(null)
const saving = ref(false)
const formErrors = ref([])
const search = ref('')
const filterStatus = ref('current')
const filterCategory = ref('')

const statusFilters = [
  { value: 'current', label: 'Sous garantie' },
  { value: 'expiring', label: 'Expirent bientôt' },
  { value: 'expired', label: 'Expirées' },
  { value: '', label: 'Toutes' },
]

const matchesStatus = (warranty, status) => {
  if (status === 'current') return warranty.status !== 'expired'
  return !status || warranty.status === status
}

const underWarranty = computed(() => warranties.value.filter(w => w.status !== 'expired'))
const coveredValue = computed(() => underWarranty.value.reduce((sum, w) => sum + Number(w.price || 0), 0))
// La liste arrive triee par date de fin.
const nextEnding = computed(() => underWarranty.value[0])

const usedCategories = computed(() => warrantyCategories.filter(c => warranties.value.some(w => w.category === c.value)))

// Recherche + categorie, avant le filtre de statut : sert aussi aux compteurs des pastilles.
const searched = computed(() => {
  let result = warranties.value
  if (filterCategory.value) result = result.filter(w => w.category === filterCategory.value)
  const q = search.value.toLowerCase()
  if (q) {
    result = result.filter(w =>
      [w.name, w.brand, w.model_reference, w.store, w.serial_number, w.order_number, w.notes]
        .some(text => text && text.toLowerCase().includes(q))
    )
  }
  return result
})

const countByStatus = (status) => searched.value.filter(w => matchesStatus(w, status)).length

const filtered = computed(() => {
  const result = searched.value.filter(w => matchesStatus(w, filterStatus.value))
  // Expirees : la plus recente d'abord.
  return filterStatus.value === 'expired' ? [...result].reverse() : result
})

const barClass = (status) => ({ active: 'bg-emerald-500', expiring: 'bg-orange-500', expired: 'bg-gray-400' }[status])

const fetchWarranties = async () => {
  warranties.value = (await apiClient.get('/warranties')).data || []
  loaded.value = true
}

const openForm = (warranty = null) => {
  formErrors.value = []
  if (showForm.value && !warranty && !editing.value) {
    showForm.value = false
    return
  }
  editing.value = warranty
  showForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

const closeForm = () => {
  showForm.value = false
  editing.value = null
}

// Multipart : la facture voyage avec les champs. Les champs vides partent vides
// pour qu'un effacement soit bien enregistre.
const toFormData = ({ attributes, receipt, removeReceipt }) => {
  const data = new FormData()
  Object.entries(attributes).forEach(([key, value]) => data.append(`warranty[${key}]`, value ?? ''))
  if (receipt) data.append('warranty[receipt]', receipt)
  if (removeReceipt) data.append('warranty[remove_receipt]', '1')
  return data
}

const saveWarranty = async (payload) => {
  saving.value = true
  formErrors.value = []
  const config = { headers: { 'Content-Type': 'multipart/form-data' } }
  try {
    if (editing.value) {
      await apiClient.patch(`/warranties/${editing.value.id}`, toFormData(payload), config)
    } else {
      await apiClient.post('/warranties', toFormData(payload), config)
    }
    closeForm()
    await fetchWarranties()
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const deleteWarranty = async (warranty) => {
  if (!confirm(`Supprimer la garantie « ${warranty.name} »${warranty.receipt ? ' et sa facture' : ''} ?`)) return
  await apiClient.delete(`/warranties/${warranty.id}`)
  if (editing.value?.id === warranty.id) closeForm()
  await fetchWarranties()
}

onMounted(fetchWarranties)
</script>
