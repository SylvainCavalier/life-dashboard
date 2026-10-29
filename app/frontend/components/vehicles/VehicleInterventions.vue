<template>
  <div class="bg-white rounded-xl shadow-sm p-5">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Carnet d'entretien</h2>
        <p v-if="totalCost" class="text-xs text-gray-500">{{ formatEuros(totalCost) }} dépensés au total<template v-if="filterKind"> ({{ kindLabel(filterKind).toLowerCase() }})</template></p>
      </div>
      <button v-if="!formOpen" @click="openForm()" class="text-blue-600 hover:text-blue-800 text-sm font-medium">+ Ajouter</button>
    </div>

    <form v-if="formOpen" @submit.prevent="save" class="bg-gray-50 rounded-lg p-4 mb-4 space-y-3">
      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div>
          <label class="block text-xs text-gray-500 mb-1">Date *</label>
          <input v-model="form.occurred_on" type="date" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Nature</label>
          <select v-model="form.kind" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
            <option v-for="k in interventionKinds" :key="k.value" :value="k.value">{{ k.icon }} {{ k.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Kilométrage</label>
          <input v-model="form.mileage" type="number" min="0" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Coût (€)</label>
          <input v-model="form.cost" type="number" step="0.01" min="0" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
        </div>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs text-gray-500 mb-1">Intitulé</label>
          <input v-model="form.title" type="text" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" :placeholder="titlePlaceholder" />
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Garage / prestataire</label>
          <input v-model="form.garage" type="text" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
        </div>
      </div>
      <div v-if="form.kind === 'controle_technique'">
        <label class="block text-xs text-gray-500 mb-1">Résultat</label>
        <select v-model="form.outcome" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
          <option :value="null">-- Non renseigné --</option>
          <option v-for="o in inspectionOutcomes" :key="o.value" :value="o.value">{{ o.label }}</option>
        </select>
        <p class="text-xs text-gray-400 mt-1">Avec un résultat, la date du prochain contrôle est recalculée (contre-visite : deux mois).</p>
      </div>
      <div>
        <label class="block text-xs text-gray-500 mb-1">Travaux effectués</label>
        <textarea v-model="form.description" rows="2" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" placeholder="Vidange, filtres à huile et à air, plaquettes avant..."></textarea>
      </div>
      <p v-if="error" class="text-xs text-red-600">{{ error }}</p>
      <div class="flex justify-end gap-2">
        <button type="button" @click="closeForm" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-blue-600 text-white rounded-lg px-3 py-1.5 text-sm font-medium hover:bg-blue-700 disabled:opacity-50">
          {{ editingId ? 'Enregistrer' : 'Ajouter' }}
        </button>
      </div>
    </form>

    <div v-if="usedKinds.length > 1" class="flex flex-wrap gap-1.5 mb-3">
      <button
        @click="filterKind = ''"
        class="text-xs px-2.5 py-1 rounded-full border transition"
        :class="filterKind === '' ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
      >Tout</button>
      <button
        v-for="k in usedKinds"
        :key="k.value"
        @click="filterKind = k.value"
        class="text-xs px-2.5 py-1 rounded-full border transition"
        :class="filterKind === k.value ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
      >{{ k.icon }} {{ k.label }}</button>
    </div>

    <ol v-if="filtered.length" class="relative border-l border-gray-200 ml-2 space-y-4">
      <li v-for="item in filtered" :key="item.id" class="ml-5 group">
        <span class="absolute -left-3 flex items-center justify-center w-6 h-6 bg-white rounded-full text-sm">{{ kindIcon(item.kind) }}</span>
        <div class="flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <p class="text-xs text-gray-500">
              {{ formatDate(item.occurred_on) }}<template v-if="item.mileage"> · {{ formatKm(item.mileage) }}</template>
            </p>
            <p class="text-sm font-medium text-gray-900">
              {{ item.title }}
              <span v-if="item.outcome" :class="outcomeBadge(item.outcome)" class="ml-1 text-xs font-normal px-2 py-0.5 rounded-full">{{ outcomeLabel(item.outcome) }}</span>
            </p>
            <p v-if="item.garage || item.cost" class="text-xs text-gray-500 mt-0.5">
              {{ item.garage }}<template v-if="item.garage && item.cost"> · </template><template v-if="item.cost">{{ formatEuros(item.cost) }}</template>
            </p>
            <p v-if="item.description" class="text-xs text-gray-600 mt-1 whitespace-pre-line">{{ item.description }}</p>
          </div>
          <div class="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
            <button @click="openForm(item)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
            <button @click="remove(item)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
          </div>
        </div>
      </li>
    </ol>
    <p v-else-if="!formOpen" class="text-sm text-gray-400 text-center py-2">Aucune intervention consignée</p>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { useApi } from '../../composables/useApi'
import {
  interventionKinds, inspectionOutcomes, kindLabel, kindIcon, outcomeLabel, outcomeBadge,
  formatEuros, formatDate, formatKm,
} from '../../composables/useVehicles'

const props = defineProps({
  vehicleId: { type: [Number, String], required: true },
  mileage: { type: Number, default: null },
  initial: { type: Array, default: () => [] },
})
// Chaque ecriture renvoie aussi la fiche du vehicule (kilometrage, prochain controle).
const emit = defineEmits(['vehicle-updated'])

const { post, patch, delete: del } = useApi()

const items = ref([...props.initial])
const filterKind = ref('')
const formOpen = ref(false)
const editingId = ref(null)
const saving = ref(false)
const error = ref('')

const today = () => new Date().toLocaleDateString('sv-SE')
const blank = () => ({ occurred_on: today(), kind: 'entretien', title: '', mileage: props.mileage ?? '', cost: '', garage: '', outcome: null, description: '' })
const form = reactive(blank())

const titlePlaceholder = computed(() => ({
  entretien: 'Révision des 60 000 km',
  controle_technique: 'Contrôle technique',
  reparation: 'Remplacement de l\'embrayage',
  pneus: '2 pneus avant Michelin',
  carrosserie: 'Pare-chocs arrière',
  sinistre: 'Accrochage parking',
}[form.kind] || ''))

const usedKinds = computed(() => interventionKinds.filter(k => items.value.some(i => i.kind === k.value)))
const filtered = computed(() => (filterKind.value ? items.value.filter(i => i.kind === filterKind.value) : items.value))
const totalCost = computed(() => filtered.value.reduce((sum, i) => sum + Number(i.cost || 0), 0))

const base = () => `/vehicles/${props.vehicleId}/vehicle_interventions`

const sortItems = (list) => [...list].sort((a, b) => b.occurred_on.localeCompare(a.occurred_on) || b.id - a.id)

const openForm = (item = null) => {
  editingId.value = item?.id || null
  Object.assign(form, blank(), item ? {
    occurred_on: item.occurred_on,
    kind: item.kind,
    title: item.title,
    mileage: item.mileage ?? '',
    cost: item.cost ?? '',
    garage: item.garage || '',
    outcome: item.outcome,
    description: item.description || '',
  } : {})
  error.value = ''
  formOpen.value = true
}

const closeForm = () => {
  formOpen.value = false
  editingId.value = null
}

const save = async () => {
  saving.value = true
  error.value = ''
  const attributes = {
    ...form,
    mileage: form.mileage === '' ? null : form.mileage,
    cost: form.cost === '' ? null : form.cost,
    outcome: form.kind === 'controle_technique' ? form.outcome : null,
  }
  try {
    const data = editingId.value
      ? await patch(`${base()}/${editingId.value}`, { vehicle_intervention: attributes })
      : await post(base(), { vehicle_intervention: attributes })
    items.value = sortItems([...items.value.filter(i => i.id !== data.intervention.id), data.intervention])
    emit('vehicle-updated', data.vehicle)
    closeForm()
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Enregistrement impossible'
  } finally {
    saving.value = false
  }
}

const remove = async (item) => {
  if (!confirm(`Supprimer « ${item.title} » du carnet ?`)) return
  try {
    const data = await del(`${base()}/${item.id}`)
    items.value = items.value.filter(i => i.id !== item.id)
    if (data?.vehicle) emit('vehicle-updated', data.vehicle)
  } catch {
    alert('Suppression impossible')
  }
}
</script>
