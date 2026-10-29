<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Mes prêts</h1>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouveau prêt
        </button>
      </div>

      <LoanForm
        v-if="showForm"
        :key="editing?.id || 'new'"
        class="mb-6"
        :initial="editing"
        :defaults="newDefaults"
        :contacts="contacts"
        :saving="saving"
        :errors="formErrors"
        @submit="saveLoan"
        @cancel="closeForm"
      />

      <!-- Synthese -->
      <div v-if="loans.length" class="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-6">
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">J'ai prêté</p>
          <p class="text-2xl font-semibold text-gray-900">{{ summary.lent.count }}</p>
          <p class="text-xs text-gray-400">
            prêt{{ summary.lent.count > 1 ? 's' : '' }} en cours<template v-if="summary.lent.money"> · {{ formatEuros(summary.lent.money) }} à récupérer</template>
          </p>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">On m'a prêté</p>
          <p class="text-2xl font-semibold text-gray-900">{{ summary.borrowed.count }}</p>
          <p class="text-xs text-gray-400">
            chose{{ summary.borrowed.count > 1 ? 's' : '' }} à rendre<template v-if="summary.borrowed.money"> · {{ formatEuros(summary.borrowed.money) }} à rembourser</template>
          </p>
        </div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-xs text-gray-500">En retard</p>
          <p class="text-2xl font-semibold" :class="summary.overdue ? 'text-red-600' : 'text-gray-900'">{{ summary.overdue }}</p>
          <p class="text-xs text-gray-400">date de retour prévue dépassée</p>
        </div>
      </div>

      <!-- Filtre par contact (lien depuis la page Contacts) -->
      <div v-if="contactFilter" class="flex items-center gap-2 mb-4 text-sm">
        <span class="bg-indigo-50 text-indigo-700 px-3 py-1.5 rounded-full">Prêts avec {{ contactFilterName }}</span>
        <button @click="clearContactFilter" class="text-gray-400 hover:text-gray-600 underline">Voir tous les prêts</button>
      </div>

      <!-- Filtres -->
      <div v-if="loans.length" class="flex flex-wrap gap-2 mb-4">
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

      <div v-if="loans.length" class="flex flex-wrap gap-3 mb-4">
        <input v-model="search" type="text" placeholder="Rechercher (personne, objet, notes...)" class="border rounded-lg px-3 py-2 text-sm flex-1 min-w-[200px]" />
        <select v-model="filterDirection" class="border rounded-lg px-3 py-2 text-sm">
          <option value="">Dans les deux sens</option>
          <option v-for="d in directions" :key="d.value" :value="d.value">{{ d.label }}</option>
        </select>
      </div>

      <div v-if="loaded && filtered.length === 0" class="text-center text-gray-400 py-12">
        {{ loans.length ? 'Aucun prêt ne correspond' : 'Aucun prêt enregistré' }}
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div
          v-for="loan in filtered"
          :key="loan.id"
          class="bg-white rounded-xl shadow-sm p-5"
          :class="{ 'opacity-60': loan.status === 'returned' }"
        >
          <div class="flex items-start justify-between gap-3 mb-2">
            <div class="min-w-0">
              <h3 class="font-semibold text-gray-900 text-lg leading-tight">{{ kindIcon(loan.kind) }} {{ loan.label }}</h3>
              <p class="text-sm text-gray-500 truncate">
                {{ directionShort(loan.direction) }}
                <router-link v-if="loan.contact" :to="`/loans?contact=${loan.contact.id}`" class="text-indigo-600 hover:underline">{{ loan.person_name }}</router-link>
                <span v-else class="text-gray-700">{{ loan.person_name }}</span>
              </p>
            </div>
            <div class="flex gap-2 flex-shrink-0">
              <button @click="openForm(loan)" class="text-gray-400 hover:text-indigo-600" title="Modifier">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>
              <button @click="deleteLoan(loan)" class="text-red-400 hover:text-red-600" title="Supprimer">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </div>
          </div>

          <div class="flex flex-wrap items-center gap-2 mb-3">
            <span :class="directionBadge(loan.direction)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ loan.direction === 'lent' ? 'Prêté' : 'Emprunté' }}</span>
            <span :class="statusBadge(loan.status)" class="text-xs px-2 py-0.5 rounded-full font-medium">{{ statusLabel(loan.status) }}</span>
            <span v-if="loan.kind === 'object' && loan.amount" class="text-xs text-gray-500">valeur {{ formatEuros(loan.amount) }}</span>
          </div>

          <!-- Remboursement d'un pret d'argent -->
          <div v-if="loan.kind === 'money' && loan.status !== 'returned'" class="mb-3">
            <div class="h-1.5 bg-gray-100 rounded-full overflow-hidden">
              <div class="h-full rounded-full bg-emerald-500" :style="{ width: `${repaidPercent(loan)}%` }"></div>
            </div>
            <p class="text-xs text-gray-500 mt-1">
              {{ formatEuros(loan.repaid_amount || 0) }} remboursé{{ Number(loan.repaid_amount) > 1 ? 's' : '' }} · reste {{ formatEuros(loan.remaining_amount) }}
            </p>
          </div>

          <div class="flex flex-wrap justify-between gap-2 text-xs text-gray-500 mb-3">
            <span>Depuis le {{ formatDate(loan.started_on) }} <template v-if="loan.status !== 'returned'">({{ durationSince(loan.started_on) }})</template></span>
            <span v-if="loan.returned_on">{{ loan.kind === 'money' ? 'Remboursé' : 'Rendu' }} le {{ formatDate(loan.returned_on) }}</span>
            <span v-else-if="loan.due_on" :class="{ 'text-red-600 font-medium': loan.status === 'overdue', 'text-orange-600 font-medium': loan.status === 'due_soon' }">
              Retour prévu le {{ formatDate(loan.due_on) }} ({{ dueLabel(loan.days_until_due) }})
            </span>
            <span v-else class="text-gray-400">Pas de date de retour</span>
          </div>

          <p v-if="loan.notes" class="text-sm text-gray-600 mb-3 whitespace-pre-line line-clamp-3">{{ loan.notes }}</p>

          <div v-if="loan.status !== 'returned'" class="pt-2 border-t border-gray-100">
            <button @click="markReturned(loan)" class="text-sm text-emerald-700 hover:text-emerald-800 font-medium">
              ✓ {{ returnLabel(loan) }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import apiClient from '../../plugins/axios'
import {
  directions, directionShort, directionBadge, kindIcon, statusLabel, statusBadge,
  durationSince, dueLabel, contactName, todayIso, formatEuros, formatDate,
} from '../../composables/useLoans'
import LoanForm from '../../components/loans/LoanForm.vue'

const route = useRoute()
const router = useRouter()

const loans = ref([])
const contacts = ref([])
const loaded = ref(false)
const showForm = ref(false)
const editing = ref(null)
const saving = ref(false)
const formErrors = ref([])
const search = ref('')
const filterStatus = ref('open')
const filterDirection = ref('')

const statusFilters = [
  { value: 'open', label: 'En cours' },
  { value: 'overdue', label: 'En retard' },
  { value: 'returned', label: 'Rendus' },
  { value: '', label: 'Tous' },
]

const contactFilter = computed(() => Number(route.query.contact) || null)
const contactFilterName = computed(() => {
  const contact = contacts.value.find(c => c.id === contactFilter.value)
  return contact ? contactName(contact) : 'ce contact'
})
// Nouveau pret depuis la vue d'un contact : le contact est deja choisi.
const newDefaults = computed(() => (contactFilter.value ? { contact_id: contactFilter.value } : {}))

const clearContactFilter = () => router.replace({ query: {} })

const matchesStatus = (loan, status) => {
  if (status === 'open') return loan.status !== 'returned'
  return !status || loan.status === status
}

const outstanding = computed(() => loans.value.filter(l => l.status !== 'returned'))
const summary = computed(() => {
  const side = (direction) => {
    const list = outstanding.value.filter(l => l.direction === direction)
    return {
      count: list.length,
      money: list.filter(l => l.kind === 'money').reduce((sum, l) => sum + Number(l.remaining_amount || 0), 0),
    }
  }
  return { lent: side('lent'), borrowed: side('borrowed'), overdue: outstanding.value.filter(l => l.status === 'overdue').length }
})

// Contact, sens et recherche, avant le filtre de statut : sert aussi aux compteurs des pastilles.
const searched = computed(() => {
  let result = loans.value
  if (contactFilter.value) result = result.filter(l => l.contact_id === contactFilter.value)
  if (filterDirection.value) result = result.filter(l => l.direction === filterDirection.value)
  const q = search.value.toLowerCase()
  if (q) result = result.filter(l => [l.person_name, l.item, l.notes].some(text => text && text.toLowerCase().includes(q)))
  return result
})

const countByStatus = (status) => searched.value.filter(l => matchesStatus(l, status)).length
const filtered = computed(() => searched.value.filter(l => matchesStatus(l, filterStatus.value)))

const repaidPercent = (loan) => Math.min(100, Math.round((Number(loan.repaid_amount || 0) / Number(loan.amount)) * 100))

const returnLabel = (loan) => {
  if (loan.kind === 'money') return loan.direction === 'lent' ? "On m'a remboursé" : "J'ai remboursé"
  return loan.direction === 'lent' ? "On me l'a rendu" : "Je l'ai rendu"
}

const fetchLoans = async () => {
  loans.value = (await apiClient.get('/loans')).data || []
  loaded.value = true
}

const fetchContacts = async () => {
  contacts.value = (await apiClient.get('/contacts')).data || []
}

const openForm = (loan = null) => {
  formErrors.value = []
  if (showForm.value && !loan && !editing.value) {
    showForm.value = false
    return
  }
  editing.value = loan
  showForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

const closeForm = () => {
  showForm.value = false
  editing.value = null
}

const saveLoan = async (attributes) => {
  saving.value = true
  formErrors.value = []
  try {
    if (editing.value) {
      await apiClient.patch(`/loans/${editing.value.id}`, { loan: attributes })
    } else {
      await apiClient.post('/loans', { loan: attributes })
    }
    closeForm()
    await fetchLoans()
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

// Rendu ou rembourse aujourd'hui ; un pret d'argent est alors solde.
const markReturned = async (loan) => {
  const attributes = { returned_on: todayIso() }
  if (loan.kind === 'money') attributes.repaid_amount = loan.amount
  await apiClient.patch(`/loans/${loan.id}`, { loan: attributes })
  await fetchLoans()
}

const deleteLoan = async (loan) => {
  if (!confirm(`Supprimer le prêt « ${loan.label} » (${loan.person_name}) ?`)) return
  await apiClient.delete(`/loans/${loan.id}`)
  if (editing.value?.id === loan.id) closeForm()
  await fetchLoans()
}

onMounted(() => Promise.all([fetchLoans(), fetchContacts()]))
</script>
