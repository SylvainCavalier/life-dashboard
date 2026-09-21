<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <h2 class="text-lg font-semibold mb-4">{{ initial?.id ? 'Modifier le voyage' : 'Nouveau voyage' }}</h2>

    <div v-if="errors.length" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mb-4">
      <p v-for="err in errors" :key="err">{{ err }}</p>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Destination *</label>
        <input v-model="form.destination" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Tokyo et Kyoto" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Pays *</label>
        <select v-model="form.country_code" class="w-full border rounded-lg px-3 py-2 text-sm">
          <option value="">Choisir un pays</option>
          <option v-for="c in COUNTRIES" :key="c.code" :value="c.code">{{ flagEmoji(c.code) }} {{ c.name }}</option>
        </select>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Date de départ *</label>
        <input v-model="form.start_date" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Date de retour *</label>
        <input v-model="form.end_date" type="date" :min="form.start_date" class="w-full border rounded-lg px-3 py-2 text-sm" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Voyageurs</label>
        <input v-model.number="form.travelers" type="number" min="1" class="w-full border rounded-lg px-3 py-2 text-sm" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Ville de départ</label>
        <input v-model="form.departure_city" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Paris" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Statut</label>
        <select v-model="form.status" class="w-full border rounded-lg px-3 py-2 text-sm">
          <option value="envisage">Envisagé</option>
          <option value="confirme">Confirmé</option>
          <option value="annule">Annulé</option>
        </select>
      </div>
      <div class="md:col-span-2">
        <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
        <textarea v-model="form.notes" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Envies, contraintes, budget cible... (transmises à l'IA)"></textarea>
      </div>
    </div>

    <div class="flex justify-end gap-2">
      <button @click="emit('cancel')" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
      <button @click="submit" :disabled="saving" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50">
        {{ saving ? 'Enregistrement...' : (initial?.id ? 'Modifier' : 'Ajouter') }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { ref, watch } from 'vue'
import { useCountries } from '../../composables/useCountries'

const props = defineProps({
  initial: { type: Object, default: null },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})
const emit = defineEmits(['submit', 'cancel'])

const { COUNTRIES, flagEmoji } = useCountries()

const defaultForm = () => ({
  destination: '', country_code: '', start_date: '', end_date: '',
  travelers: 1, departure_city: 'Paris', status: 'envisage', notes: '',
})

const form = ref(defaultForm())

const fill = (initial) => {
  const base = defaultForm()
  if (!initial) { form.value = base; return }
  Object.keys(base).forEach(key => {
    if (initial[key] !== undefined && initial[key] !== null) base[key] = initial[key]
  })
  form.value = base
}

watch(() => props.initial, fill, { immediate: true })

const submit = () => {
  if (!form.value.destination.trim() || !form.value.country_code || !form.value.start_date || !form.value.end_date) return
  emit('submit', { ...form.value })
}
</script>
