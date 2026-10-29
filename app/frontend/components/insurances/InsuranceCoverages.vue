<template>
  <div class="bg-white rounded-xl shadow-sm p-5">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-gray-900">Garanties</h2>
      <button v-if="!formOpen" @click="openForm()" class="text-blue-600 hover:text-blue-800 text-sm font-medium">+ Ajouter</button>
    </div>

    <form v-if="formOpen" @submit.prevent="save" class="bg-gray-50 rounded-lg p-4 mb-4 space-y-3">
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <div class="sm:col-span-2">
          <label class="block text-xs text-gray-500 mb-1">Garantie *</label>
          <input v-model="form.name" type="text" required list="coverage-suggestions" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" placeholder="Dégâts des eaux" />
          <datalist id="coverage-suggestions">
            <option v-for="s in suggestions" :key="s" :value="s" />
          </datalist>
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Couverture</label>
          <select v-model="form.included" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
            <option :value="true">Couverte</option>
            <option :value="false">Non couverte / exclue</option>
          </select>
        </div>
        <div>
          <label class="block text-xs text-gray-500 mb-1">Plafond</label>
          <input v-model="form.ceiling" type="text" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" placeholder="50 000 €, valeur à neuf..." />
        </div>
        <div class="sm:col-span-2">
          <label class="block text-xs text-gray-500 mb-1">Franchise</label>
          <input v-model="form.deductible" type="text" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" placeholder="150 €" />
        </div>
      </div>
      <div>
        <label class="block text-xs text-gray-500 mb-1">Conditions et exclusions</label>
        <textarea v-model="form.conditions" rows="3" class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" placeholder="Fuites accidentelles uniquement, défaut d'entretien exclu, déclaration sous 5 jours ouvrés..."></textarea>
      </div>
      <p v-if="error" class="text-xs text-red-600">{{ error }}</p>
      <div class="flex justify-end gap-2">
        <button type="button" @click="closeForm" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-blue-600 text-white rounded-lg px-3 py-1.5 text-sm font-medium hover:bg-blue-700 disabled:opacity-50">
          {{ editingId ? 'Enregistrer' : 'Ajouter' }}
        </button>
      </div>
    </form>

    <ul v-if="coverages.length" class="divide-y divide-gray-100">
      <li v-for="coverage in coverages" :key="coverage.id" class="py-3 group">
        <div class="flex items-start gap-3">
          <span class="mt-0.5 flex-shrink-0 text-sm font-bold" :class="coverage.included ? 'text-green-600' : 'text-red-500'" :title="coverage.included ? 'Couverte' : 'Non couverte'">
            {{ coverage.included ? '✓' : '✗' }}
          </span>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium" :class="coverage.included ? 'text-gray-900' : 'text-gray-500 line-through'">{{ coverage.name }}</p>
            <p v-if="coverage.ceiling || coverage.deductible" class="text-xs text-gray-500 mt-0.5">
              <span v-if="coverage.ceiling">Plafond : {{ coverage.ceiling }}</span>
              <span v-if="coverage.ceiling && coverage.deductible"> · </span>
              <span v-if="coverage.deductible">Franchise : {{ coverage.deductible }}</span>
            </p>
            <p v-if="coverage.conditions" class="text-xs text-gray-600 mt-1 whitespace-pre-line">{{ coverage.conditions }}</p>
          </div>
          <div class="flex items-center gap-2 opacity-0 group-hover:opacity-100 transition-opacity flex-shrink-0">
            <button @click="openForm(coverage)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
            <button @click="remove(coverage)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
          </div>
        </div>
      </li>
    </ul>
    <p v-else-if="!formOpen" class="text-sm text-gray-400 text-center py-2">Aucune garantie renseignée</p>
  </div>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { useApi } from '../../composables/useApi'
import { coverageSuggestions } from '../../composables/useInsurances'

const props = defineProps({
  insuranceId: { type: [Number, String], required: true },
  insuranceType: { type: String, default: 'autre' },
  initial: { type: Array, default: () => [] },
})
const emit = defineEmits(['changed'])

const { post, patch, delete: del } = useApi()

const coverages = ref([...props.initial])
const formOpen = ref(false)
const editingId = ref(null)
const saving = ref(false)
const error = ref('')
const blank = { name: '', included: true, ceiling: '', deductible: '', conditions: '' }
const form = reactive({ ...blank })

// Suggestions du type de contrat, sans celles deja saisies.
const suggestions = computed(() =>
  (coverageSuggestions[props.insuranceType] || []).filter(s => !coverages.value.some(c => c.name === s))
)

const base = () => `/insurances/${props.insuranceId}/insurance_coverages`

const openForm = (coverage = null) => {
  editingId.value = coverage?.id || null
  Object.assign(form, blank, coverage ? {
    name: coverage.name,
    included: coverage.included,
    ceiling: coverage.ceiling || '',
    deductible: coverage.deductible || '',
    conditions: coverage.conditions || '',
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
  try {
    if (editingId.value) {
      const updated = await patch(`${base()}/${editingId.value}`, { insurance_coverage: { ...form } })
      coverages.value = coverages.value.map(c => (c.id === updated.id ? updated : c))
    } else {
      coverages.value.push(await post(base(), { insurance_coverage: { ...form } }))
    }
    emit('changed', coverages.value)
    closeForm()
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Enregistrement impossible'
  } finally {
    saving.value = false
  }
}

const remove = async (coverage) => {
  if (!confirm(`Supprimer la garantie « ${coverage.name} » ?`)) return
  try {
    await del(`${base()}/${coverage.id}`)
    coverages.value = coverages.value.filter(c => c.id !== coverage.id)
    emit('changed', coverages.value)
  } catch {
    alert('Suppression impossible')
  }
}
</script>
