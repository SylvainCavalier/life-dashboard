<template>
  <div class="bg-white rounded-xl shadow-sm p-5">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-gray-900">Ce qui est assuré</h2>
      <button v-if="!formOpen" @click="openForm()" class="text-blue-600 hover:text-blue-800 text-sm font-medium">+ Ajouter</button>
    </div>

    <form v-if="formOpen" @submit.prevent="save" class="bg-gray-50 rounded-lg p-4 mb-4 space-y-3">
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <div>
          <label class="block text-xs text-gray-500 mb-1">Nature</label>
          <select v-model="form.kind" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
            <option v-for="k in itemKinds" :key="k.value" :value="k.value">{{ k.label }}</option>
          </select>
        </div>
        <div v-if="form.kind === 'logement'">
          <label class="block text-xs text-gray-500 mb-1">Bien (page Immobilier)</label>
          <select v-model="form.property_id" @change="onPropertySelected" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
            <option :value="null">-- Aucun --</option>
            <option v-for="p in properties" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>
        <div :class="form.kind === 'logement' ? 'sm:col-span-2' : ''">
          <label class="block text-xs text-gray-500 mb-1">Nom *</label>
          <input v-model="form.name" type="text" required class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" :placeholder="placeholder" />
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Valeur déclarée (€)</label>
          <input v-model="form.value" type="number" step="0.01" min="0" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
        </div>
      </div>
      <div>
        <label class="block text-xs text-gray-500 mb-1">Description</label>
        <textarea v-model="form.description" rows="2" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" placeholder="Surface, immatriculation, bénéficiaires, numéro de série..."></textarea>
      </div>
      <p v-if="error" class="text-xs text-red-600">{{ error }}</p>
      <div class="flex justify-end gap-2">
        <button type="button" @click="closeForm" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-blue-600 text-white rounded-lg px-3 py-1.5 text-sm font-medium hover:bg-blue-700 disabled:opacity-50">
          {{ editingId ? 'Enregistrer' : 'Ajouter' }}
        </button>
      </div>
    </form>

    <ul v-if="items.length" class="space-y-2">
      <li v-for="item in items" :key="item.id" class="p-3 rounded-lg bg-gray-50 group">
        <div class="flex items-start gap-3">
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-gray-900">
              {{ item.name }}
              <span class="ml-1 text-xs font-normal bg-white border border-gray-200 text-gray-600 px-2 py-0.5 rounded-full">{{ itemKindLabel(item.kind) }}</span>
            </p>
            <p v-if="item.property_name" class="text-xs mt-0.5">
              <router-link to="/properties" class="text-blue-600 hover:text-blue-800">Bien : {{ item.property_name }}</router-link>
            </p>
            <p v-if="item.value" class="text-xs text-gray-500 mt-0.5">Valeur déclarée : {{ formatEuros(item.value) }}</p>
            <p v-if="item.description" class="text-xs text-gray-600 mt-1 whitespace-pre-line">{{ item.description }}</p>
          </div>
          <div class="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
            <button @click="openForm(item)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
            <button @click="remove(item)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
          </div>
        </div>
      </li>
    </ul>
    <p v-else-if="!formOpen" class="text-sm text-gray-400 text-center py-2">Rien de renseigné</p>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { itemKinds, itemKindLabel, formatEuros } from '../../composables/useInsurances'

const props = defineProps({
  insuranceId: { type: [Number, String], required: true },
  insuranceType: { type: String, default: 'autre' },
  initial: { type: Array, default: () => [] },
})
const emit = defineEmits(['changed'])

const { get, post, patch, delete: del } = useApi()

const DEFAULT_KINDS = { habitation: 'logement', auto: 'vehicule', moto: 'vehicule', animaux: 'animal', sante: 'personne', prevoyance: 'personne', vie: 'personne', emprunteur: 'personne', scolaire: 'personne' }

const items = ref([...props.initial])
const properties = ref([])
const formOpen = ref(false)
const editingId = ref(null)
const saving = ref(false)
const error = ref('')
const blank = () => ({ kind: DEFAULT_KINDS[props.insuranceType] || 'autre', property_id: null, name: '', value: '', description: '' })
const form = reactive(blank())

const placeholder = computed(() => ({
  logement: 'Appartement de Créteil',
  vehicule: 'Peugeot 208 AB-123-CD',
  personne: 'Sylvain',
  animal: 'Nom de l\'animal',
  objet: 'MacBook Pro, montre...',
}[form.kind] || ''))

const base = () => `/insurances/${props.insuranceId}/insured_items`

const openForm = (item = null) => {
  editingId.value = item?.id || null
  Object.assign(form, blank(), item ? {
    kind: item.kind,
    property_id: item.property_id,
    name: item.name,
    value: item.value || '',
    description: item.description || '',
  } : {})
  error.value = ''
  formOpen.value = true
}

const closeForm = () => {
  formOpen.value = false
  editingId.value = null
}

// Le nom du bien choisi pre-remplit le nom, s'il est vide.
const onPropertySelected = () => {
  const property = properties.value.find(p => p.id === form.property_id)
  if (property && !form.name) form.name = property.name
}

const save = async () => {
  saving.value = true
  error.value = ''
  const attributes = {
    ...form,
    property_id: form.kind === 'logement' ? form.property_id : null,
    value: form.value === '' ? null : form.value,
  }
  try {
    if (editingId.value) {
      const updated = await patch(`${base()}/${editingId.value}`, { insured_item: attributes })
      items.value = items.value.map(i => (i.id === updated.id ? updated : i))
    } else {
      items.value.push(await post(base(), { insured_item: attributes }))
    }
    emit('changed', items.value)
    closeForm()
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Enregistrement impossible'
  } finally {
    saving.value = false
  }
}

const remove = async (item) => {
  if (!confirm(`Retirer « ${item.name} » de ce contrat ?`)) return
  try {
    await del(`${base()}/${item.id}`)
    items.value = items.value.filter(i => i.id !== item.id)
    emit('changed', items.value)
  } catch {
    alert('Suppression impossible')
  }
}

onMounted(async () => {
  try {
    properties.value = await get('/properties') || []
  } catch {
    properties.value = []
  }
})
</script>
