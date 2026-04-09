<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
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

      <!-- Alertes renouvellement -->
      <div
        v-for="alert in renewalAlerts"
        :key="'renew-' + alert.id"
        class="mb-3 flex items-center gap-3 px-4 py-3 rounded-lg text-sm"
        :class="alert.days <= 0 ? 'bg-red-50 border border-red-200 text-red-800' : 'bg-amber-50 border border-amber-200 text-amber-800'"
      >
        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span>
          <strong>{{ alert.name }}</strong> —
          <template v-if="alert.days < 0">expire depuis {{ -alert.days }} jour{{ -alert.days > 1 ? 's' : '' }}</template>
          <template v-else-if="alert.days === 0">expire aujourd'hui</template>
          <template v-else>expire dans {{ alert.days }} jour{{ alert.days > 1 ? 's' : '' }}</template>
        </span>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">🔄</span>
            <h1 class="text-2xl font-bold text-gray-900">Abonnements</h1>
            <span class="text-sm text-gray-400">({{ filteredSubscriptions.length }})</span>
          </div>
          <button
            @click="openForm()"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showForm ? 'Annuler' : '+ Ajouter' }}
          </button>
        </div>

        <!-- Resume des couts -->
        <div v-if="subscriptions.length > 0" class="grid grid-cols-2 gap-4 mb-6">
          <div class="bg-indigo-50 rounded-lg p-4">
            <p class="text-sm text-indigo-600 font-medium">Total par mois</p>
            <p class="text-2xl font-bold text-indigo-900">{{ totalMonthly.toFixed(2) }} €</p>
          </div>
          <div class="bg-emerald-50 rounded-lg p-4">
            <p class="text-sm text-emerald-600 font-medium">Total par an</p>
            <p class="text-2xl font-bold text-emerald-900">{{ totalYearly.toFixed(2) }} €</p>
          </div>
        </div>

        <!-- Filtre par categorie -->
        <div v-if="subscriptions.length > 0" class="flex flex-wrap gap-2 mb-6">
          <button
            @click="filterCategory = ''"
            :class="filterCategory === '' ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            Tous
          </button>
          <button
            v-for="cat in usedCategories"
            :key="cat"
            @click="filterCategory = cat"
            :class="filterCategory === cat ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            {{ categoryLabel(cat) }}
            <span class="ml-1 opacity-70">{{ categoryTotal(cat) }} €/mois</span>
          </button>
        </div>

        <!-- Formulaire d'ajout / edition -->
        <form v-if="showForm" @submit.prevent="saveSubscription" class="mb-6 p-5 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            <input
              v-model="form.name"
              type="text"
              placeholder="Nom de l'abonnement *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <div class="flex gap-2">
              <input
                v-model="form.cost"
                type="number"
                step="0.01"
                min="0"
                placeholder="Montant (€) *"
                required
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
              <select
                v-model="form.billing_cycle"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              >
                <option value="monthly">/ mois</option>
                <option value="yearly">/ an</option>
              </select>
            </div>
            <select
              v-model="form.category"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Categorie</option>
              <option v-for="cat in categories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
            </select>
            <input
              v-model="form.url"
              type="url"
              placeholder="URL du site"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.start_date"
              type="date"
              title="Date de debut"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.end_date"
              type="date"
              title="Date de fin"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <div class="mt-3 flex gap-2">
            <button
              type="submit"
              class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
            >
              {{ editingId ? 'Modifier' : 'Enregistrer' }}
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

        <!-- Tableau -->
        <div v-if="subscriptions.length === 0" class="text-center text-gray-400 py-12">
          Aucun abonnement enregistre
        </div>

        <table v-else class="w-full">
          <thead>
            <tr class="border-b border-gray-200 text-left text-sm text-gray-500">
              <th class="pb-3 font-medium cursor-pointer hover:text-gray-700" @click="toggleSort('name')">
                Nom {{ sortIndicator('name') }}
              </th>
              <th class="pb-3 font-medium">Categorie</th>
              <th class="pb-3 font-medium cursor-pointer hover:text-gray-700" @click="toggleSort('monthly')">
                Cout / mois {{ sortIndicator('monthly') }}
              </th>
              <th class="pb-3 font-medium cursor-pointer hover:text-gray-700" @click="toggleSort('yearly')">
                Cout / an {{ sortIndicator('yearly') }}
              </th>
              <th class="pb-3 font-medium">Debut</th>
              <th class="pb-3 font-medium">Fin</th>
              <th class="pb-3 font-medium">Site</th>
              <th class="pb-3 font-medium w-24"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="sub in filteredSubscriptions"
              :key="sub.id"
              class="border-b border-gray-100 hover:bg-gray-50"
            >
              <td class="py-3 text-sm text-gray-900 font-medium">{{ sub.name }}</td>
              <td class="py-3 text-sm">
                <span
                  v-if="sub.category"
                  class="px-2 py-0.5 rounded-full text-xs font-medium"
                  :class="categoryBadgeClass(sub.category)"
                >
                  {{ categoryLabel(sub.category) }}
                </span>
                <span v-else class="text-gray-400">—</span>
              </td>
              <td class="py-3 text-sm text-gray-700">{{ monthlyCost(sub).toFixed(2) }} €</td>
              <td class="py-3 text-sm text-gray-700">{{ yearlyCost(sub).toFixed(2) }} €</td>
              <td class="py-3 text-sm text-gray-700">{{ formatDate(sub.start_date) }}</td>
              <td class="py-3 text-sm text-gray-700">
                <span v-if="sub.end_date" :class="isPast(sub.end_date) ? 'text-red-500' : ''">
                  {{ formatDate(sub.end_date) }}
                </span>
                <span v-else class="text-gray-400">—</span>
              </td>
              <td class="py-3 text-sm">
                <a
                  v-if="sub.url"
                  :href="sub.url"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-indigo-600 hover:text-indigo-800 underline"
                >
                  Lien
                </a>
                <span v-else class="text-gray-400">—</span>
              </td>
              <td class="py-3 text-right flex gap-2 justify-end">
                <button
                  @click="editSubscription(sub)"
                  class="text-gray-400 hover:text-indigo-600 text-sm"
                  title="Modifier"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                  </svg>
                </button>
                <button
                  @click="deleteSubscription(sub.id)"
                  class="text-red-400 hover:text-red-600 text-sm"
                  title="Supprimer"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud } = useApi()
const { list, create, update, destroy } = useCrud('subscriptions')

const subscriptions = ref([])
const showForm = ref(false)
const editingId = ref(null)
const filterCategory = ref('')
const sortBy = ref('')
const sortDir = ref('asc')

const categories = [
  { value: 'ia', label: 'IA' },
  { value: 'sport', label: 'Sport' },
  { value: 'telecom', label: 'Telecom' },
  { value: 'streaming', label: 'Streaming' },
  { value: 'assurance', label: 'Assurance' },
  { value: 'logiciel', label: 'Logiciel' },
  { value: 'media', label: 'Media' },
  { value: 'alimentation', label: 'Alimentation' },
  { value: 'autre', label: 'Autre' },
]

const categoryLabels = Object.fromEntries(categories.map(c => [c.value, c.label]))

const categoryColors = {
  ia: 'bg-violet-100 text-violet-700',
  sport: 'bg-green-100 text-green-700',
  telecom: 'bg-blue-100 text-blue-700',
  streaming: 'bg-red-100 text-red-700',
  assurance: 'bg-yellow-100 text-yellow-700',
  logiciel: 'bg-cyan-100 text-cyan-700',
  media: 'bg-pink-100 text-pink-700',
  alimentation: 'bg-orange-100 text-orange-700',
  autre: 'bg-gray-100 text-gray-700',
}

const defaultForm = {
  name: '',
  cost: '',
  billing_cycle: 'monthly',
  category: '',
  start_date: '',
  end_date: '',
  url: '',
}

const form = reactive({ ...defaultForm })

const monthlyCost = (sub) => {
  const cost = parseFloat(sub.cost || 0)
  return sub.billing_cycle === 'yearly' ? cost / 12 : cost
}

const yearlyCost = (sub) => {
  const cost = parseFloat(sub.cost || 0)
  return sub.billing_cycle === 'yearly' ? cost : cost * 12
}

const categoryLabel = (value) => categoryLabels[value] || value
const categoryBadgeClass = (value) => categoryColors[value] || 'bg-gray-100 text-gray-700'

const usedCategories = computed(() => {
  const cats = new Set(subscriptions.value.map(s => s.category).filter(Boolean))
  return categories.map(c => c.value).filter(v => cats.has(v))
})

const categoryTotal = (cat) => {
  return subscriptions.value
    .filter(s => s.category === cat)
    .reduce((sum, s) => sum + monthlyCost(s), 0)
    .toFixed(2)
}

const renewalAlerts = computed(() => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const in30days = new Date(today)
  in30days.setDate(in30days.getDate() + 30)

  return subscriptions.value
    .filter(s => s.end_date)
    .map(s => {
      const end = new Date(s.end_date)
      end.setHours(0, 0, 0, 0)
      const diff = Math.round((end - today) / (1000 * 60 * 60 * 24))
      return { id: s.id, name: s.name, days: diff, end_date: s.end_date }
    })
    .filter(a => a.days <= 30)
    .sort((a, b) => a.days - b.days)
})

const toggleSort = (field) => {
  if (sortBy.value === field) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = field
    sortDir.value = 'asc'
  }
}

const sortIndicator = (field) => {
  if (sortBy.value !== field) return ''
  return sortDir.value === 'asc' ? '↑' : '↓'
}

const filteredSubscriptions = computed(() => {
  let result = filterCategory.value
    ? subscriptions.value.filter(s => s.category === filterCategory.value)
    : [...subscriptions.value]

  if (sortBy.value) {
    const dir = sortDir.value === 'asc' ? 1 : -1
    result.sort((a, b) => {
      if (sortBy.value === 'name') {
        return dir * a.name.localeCompare(b.name, 'fr')
      }
      return dir * (monthlyCost(a) - monthlyCost(b))
    })
  }

  return result
})

const totalMonthly = computed(() => {
  return filteredSubscriptions.value.reduce((sum, s) => sum + monthlyCost(s), 0)
})

const totalYearly = computed(() => {
  return filteredSubscriptions.value.reduce((sum, s) => sum + yearlyCost(s), 0)
})

const fetchSubscriptions = async () => {
  subscriptions.value = await list()
}

const openForm = () => {
  if (showForm.value && !editingId.value) {
    showForm.value = false
    return
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = true
}

const saveSubscription = async () => {
  const data = { subscription: { ...form } }
  if (editingId.value) {
    await update(editingId.value, data)
  } else {
    await create(data)
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = false
  await fetchSubscriptions()
}

const editSubscription = (sub) => {
  editingId.value = sub.id
  Object.assign(form, {
    name: sub.name,
    cost: sub.cost,
    billing_cycle: sub.billing_cycle || 'monthly',
    category: sub.category || '',
    start_date: sub.start_date || '',
    end_date: sub.end_date || '',
    url: sub.url || '',
  })
  showForm.value = true
}

const cancelEdit = () => {
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = false
}

const deleteSubscription = async (id) => {
  await destroy(id)
  await fetchSubscriptions()
}

const formatDate = (date) => {
  if (!date) return '—'
  return new Date(date).toLocaleDateString('fr-FR')
}

const isPast = (date) => {
  return new Date(date) < new Date()
}

onMounted(fetchSubscriptions)
</script>
