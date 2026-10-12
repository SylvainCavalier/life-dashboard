<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <div class="flex items-center justify-between mb-4 gap-3 flex-wrap">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Échéances notables</h2>
        <p class="text-xs text-gray-400">Les douze prochains mois. Chaque échéance apparaît aussi dans l'agenda.</p>
      </div>
      <div class="flex items-center gap-3">
        <button
          v-if="deadlines.length"
          @click="showAll = !showAll"
          class="text-xs text-gray-500 hover:text-gray-700"
        >{{ showAll ? 'Vue chronologique' : `Toutes les échéances (${deadlines.length})` }}</button>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Échéance
        </button>
      </div>
    </div>

    <!-- Formulaire -->
    <div v-if="showForm" class="border rounded-xl p-4 mb-5 bg-gray-50">
      <h3 class="text-sm font-semibold mb-3">{{ editingId ? 'Modifier l\'échéance' : 'Nouvelle échéance' }}</h3>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
        <div class="md:col-span-2">
          <label class="block text-xs font-medium text-gray-600 mb-1">Intitulé *</label>
          <input v-model="form.title" type="text" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm" placeholder="Taxe foncière, crédit immobilier, déclaration URSSAF..." />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Catégorie</label>
          <select v-model="form.category" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm">
            <option v-for="(label, value) in CATEGORIES" :key="value" :value="value">{{ label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Montant (facultatif)</label>
          <input v-model="form.amount" type="number" min="0" step="0.01" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm" placeholder="€" />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">{{ form.recurrence === 'none' ? 'Date *' : 'Première échéance *' }}</label>
          <input v-model="form.due_on" type="date" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm" />
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">Récurrence</label>
          <select v-model="form.recurrence" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm">
            <option v-for="(label, value) in RECURRENCES" :key="value" :value="value">{{ label }}</option>
          </select>
        </div>
        <div v-if="form.recurrence !== 'none'">
          <label class="block text-xs font-medium text-gray-600 mb-1">Dernière échéance (facultatif)</label>
          <input v-model="form.ends_on" type="date" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm" />
          <p class="text-xs text-gray-400 mt-1">Fin d'un crédit, par exemple. Vide = sans fin.</p>
        </div>
        <div class="md:col-span-2">
          <label class="block text-xs font-medium text-gray-600 mb-1">Notes</label>
          <textarea v-model="form.notes" rows="2" class="w-full border rounded-lg px-3 py-2 text-base md:text-sm" placeholder="Référence, mode de paiement, lien vers l'espace en ligne..."></textarea>
        </div>
      </div>
      <p v-if="errors.length" class="text-xs text-red-600 mb-3">{{ errors.join(' · ') }}</p>
      <div class="flex items-center justify-between">
        <button
          v-if="editingId"
          @click="removeDeadline(editingId)"
          class="text-xs text-red-400 hover:text-red-600"
        >Supprimer</button>
        <span v-else></span>
        <div class="flex gap-2">
          <button @click="closeForm" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
          <button
            @click="saveDeadline"
            :disabled="saving"
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50"
          >{{ editingId ? 'Modifier' : 'Ajouter' }}</button>
        </div>
      </div>
    </div>

    <div v-if="loaded && deadlines.length === 0 && !showForm" class="text-center text-sm text-gray-400 py-6">
      Aucune échéance. Crédit, charges, URSSAF, impôts : ajoutez ce qu'il ne faut pas oublier.
    </div>

    <!-- Vue chronologique -->
    <div v-else-if="!showAll">
      <div v-if="loaded && deadlines.length && upcomingGroups.length === 0" class="text-sm text-gray-400 py-4 text-center">
        Aucune échéance dans les douze prochains mois.
      </div>
      <div v-for="group in upcomingGroups" :key="group.key" class="mb-4 last:mb-0">
        <h3 class="text-xs font-semibold text-gray-400 uppercase mb-1.5">{{ group.label }}</h3>
        <ul class="divide-y divide-gray-100">
          <li
            v-for="item in group.items"
            :key="item.deadline.id + '-' + item.date"
            @click="openForm(item.deadline)"
            class="flex items-center gap-3 py-2 cursor-pointer hover:bg-gray-50 rounded-lg px-2 -mx-2"
          >
            <div class="w-11 flex-shrink-0 text-center">
              <div :class="['text-lg font-semibold leading-none', urgencyClass(item.date)]">{{ dayOf(item.date) }}</div>
              <div class="text-[10px] text-gray-400 uppercase mt-0.5">{{ weekdayOf(item.date) }}</div>
            </div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2 flex-wrap">
                <span class="text-sm font-medium text-gray-900 truncate">{{ item.deadline.title }}</span>
                <span class="text-[11px] px-2 py-0.5 rounded-full bg-rose-50 text-rose-700 flex-shrink-0">{{ item.deadline.category_label }}</span>
              </div>
              <div class="text-xs text-gray-400">
                {{ item.deadline.recurrence_label }}<span v-if="relativeLabel(item.date)"> · {{ relativeLabel(item.date) }}</span>
              </div>
            </div>
            <div v-if="item.deadline.formatted_amount" class="text-sm font-medium text-gray-700 flex-shrink-0">
              {{ item.deadline.formatted_amount }}
            </div>
          </li>
        </ul>
      </div>
    </div>

    <!-- Toutes les échéances (gestion) -->
    <ul v-else class="divide-y divide-gray-100">
      <li
        v-for="deadline in deadlines"
        :key="deadline.id"
        @click="openForm(deadline)"
        class="flex items-center gap-3 py-2 cursor-pointer hover:bg-gray-50 rounded-lg px-2 -mx-2"
      >
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 flex-wrap">
            <span class="text-sm font-medium text-gray-900 truncate">{{ deadline.title }}</span>
            <span class="text-[11px] px-2 py-0.5 rounded-full bg-rose-50 text-rose-700">{{ deadline.category_label }}</span>
          </div>
          <div class="text-xs text-gray-400">
            {{ deadline.recurrence_label }}
            · {{ deadline.next_on ? 'prochaine le ' + longDate(deadline.next_on) : 'passée (' + longDate(deadline.due_on) + ')' }}
            <span v-if="deadline.ends_on"> · jusqu'au {{ longDate(deadline.ends_on) }}</span>
          </div>
        </div>
        <div v-if="deadline.formatted_amount" class="text-sm text-gray-700 flex-shrink-0">{{ deadline.formatted_amount }}</div>
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

// Les occurrences sont posées dans l'agenda par le serveur : la page parente
// recharge ses événements à chaque modification.
const emit = defineEmits(['changed'])

const { useCrud } = useApi()
const { list, create, update, destroy } = useCrud('deadlines')

const CATEGORIES = {
  credit: 'Crédit / emprunt',
  charges: 'Charges / copropriété',
  impots: 'Impôts et taxes',
  social: 'URSSAF / social',
  assurance: 'Assurance',
  loyer: 'Loyer',
  autre: 'Autre',
}

const RECURRENCES = {
  none: 'Une seule fois',
  monthly: 'Tous les mois',
  quarterly: 'Tous les trimestres',
  semiannual: 'Tous les six mois',
  yearly: 'Tous les ans',
}

const deadlines = ref([])
const upcoming = ref([])
const loaded = ref(false)
const showAll = ref(false)
const showForm = ref(false)
const editingId = ref(null)
const saving = ref(false)
const errors = ref([])

const defaultForm = () => ({
  title: '',
  category: 'autre',
  due_on: '',
  recurrence: 'none',
  ends_on: '',
  amount: '',
  notes: '',
})

const form = ref(defaultForm())

const fetchDeadlines = async () => {
  const data = await list()
  deadlines.value = data.deadlines
  upcoming.value = data.upcoming
  loaded.value = true
}

// Occurrences groupées par mois.
const upcomingGroups = computed(() => {
  const byId = Object.fromEntries(deadlines.value.map(d => [d.id, d]))
  const groups = []
  upcoming.value.forEach(({ deadline_id, date }) => {
    const deadline = byId[deadline_id]
    if (!deadline) return
    const key = date.slice(0, 7)
    let group = groups[groups.length - 1]
    if (!group || group.key !== key) {
      group = { key, label: monthLabel(date), items: [] }
      groups.push(group)
    }
    group.items.push({ deadline, date })
  })
  return groups
})

const openForm = (deadline = null) => {
  errors.value = []
  if (deadline) {
    editingId.value = deadline.id
    form.value = {
      title: deadline.title,
      category: deadline.category,
      due_on: deadline.due_on,
      recurrence: deadline.recurrence,
      ends_on: deadline.ends_on || '',
      amount: deadline.amount ?? '',
      notes: deadline.notes || '',
    }
  } else {
    editingId.value = null
    form.value = defaultForm()
  }
  showForm.value = true
}

const closeForm = () => {
  showForm.value = false
  editingId.value = null
}

const saveDeadline = async () => {
  if (!form.value.title.trim() || !form.value.due_on) {
    errors.value = ['Intitulé et date obligatoires']
    return
  }
  const payload = { ...form.value }
  if (payload.recurrence === 'none') payload.ends_on = null
  if (payload.ends_on === '') payload.ends_on = null
  if (payload.amount === '') payload.amount = null

  saving.value = true
  errors.value = []
  try {
    if (editingId.value) {
      await update(editingId.value, { deadline: payload })
    } else {
      await create({ deadline: payload })
    }
    closeForm()
    await fetchDeadlines()
    emit('changed')
  } catch (e) {
    errors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const removeDeadline = async (id) => {
  if (!confirm('Supprimer cette échéance ? Ses occurrences à venir quitteront l\'agenda.')) return
  await destroy(id)
  closeForm()
  await fetchDeadlines()
  emit('changed')
}

// === Dates (chaînes AAAA-MM-JJ, lues en heure locale) ===
const parseDate = (str) => {
  const [y, m, d] = str.split('-').map(Number)
  return new Date(y, m - 1, d)
}

const daysUntil = (str) => {
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return Math.round((parseDate(str) - today) / 86400000)
}

const monthLabel = (str) => parseDate(str).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })
const dayOf = (str) => parseDate(str).getDate()
const weekdayOf = (str) => parseDate(str).toLocaleDateString('fr-FR', { weekday: 'short' }).replace('.', '')
const longDate = (str) => parseDate(str).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })

const relativeLabel = (str) => {
  const days = daysUntil(str)
  if (days === 0) return "aujourd'hui"
  if (days === 1) return 'demain'
  if (days <= 30) return `dans ${days} jours`
  return ''
}

const urgencyClass = (str) => {
  const days = daysUntil(str)
  if (days <= 3) return 'text-rose-600'
  if (days <= 14) return 'text-amber-600'
  return 'text-gray-800'
}

onMounted(fetchDeadlines)
</script>
