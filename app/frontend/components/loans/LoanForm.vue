<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <h2 class="text-lg font-semibold mb-4">{{ initial ? 'Modifier le prêt' : 'Nouveau prêt' }}</h2>

    <ul v-if="errors.length" class="mb-4 text-sm text-red-600 list-disc list-inside">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>

    <form @submit.prevent="submit" class="space-y-6">
      <!-- Sens et nature -->
      <div class="flex flex-wrap gap-6">
        <div>
          <p class="text-sm font-medium text-gray-700 mb-1">Sens</p>
          <div class="flex gap-2">
            <button
              v-for="d in directions"
              :key="d.value"
              type="button"
              @click="form.direction = d.value"
              class="text-sm px-3 py-1.5 rounded-full border transition"
              :class="form.direction === d.value ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
            >
              {{ d.label }}
            </button>
          </div>
        </div>
        <div>
          <p class="text-sm font-medium text-gray-700 mb-1">Quoi</p>
          <div class="flex gap-2">
            <button
              v-for="k in kinds"
              :key="k.value"
              type="button"
              @click="form.kind = k.value"
              class="text-sm px-3 py-1.5 rounded-full border transition"
              :class="form.kind === k.value ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
            >
              {{ k.icon }} {{ k.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- Personne et chose -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">
            {{ form.direction === 'lent' ? 'Prêté à *' : 'Prêté par *' }}
          </label>
          <input
            v-model="personInput"
            type="text"
            required
            list="loan-contacts"
            autocomplete="off"
            class="w-full border rounded-lg px-3 py-2 text-sm"
            placeholder="Choisir un contact ou taper un nom"
          />
          <datalist id="loan-contacts">
            <option v-for="c in contacts" :key="c.id" :value="contactName(c)" />
          </datalist>
          <p class="text-xs mt-1" :class="linkedContact ? 'text-emerald-600' : 'text-gray-400'">
            {{ linkedContact ? 'Lié à la fiche contact' : (personInput ? 'Nom libre, hors de vos contacts' : 'Un contact de votre liste ou n’importe quel nom') }}
          </p>
        </div>
        <div v-if="form.kind === 'object'">
          <label class="block text-sm font-medium text-gray-700 mb-1">Objet *</label>
          <input v-model="form.item" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Perceuse, livre « Dune », tente..." />
        </div>
        <div v-else class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Montant (€) *</label>
            <input v-model="form.amount" type="number" step="0.01" min="0.01" required class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Déjà remboursé (€)</label>
            <input v-model="form.repaid_amount" type="number" step="0.01" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="0" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Motif</label>
            <input v-model="form.item" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Avance pour le loyer, part du cadeau..." />
          </div>
        </div>
        <div v-if="form.kind === 'object'">
          <label class="block text-sm font-medium text-gray-700 mb-1">Valeur estimée (€)</label>
          <input v-model="form.amount" type="number" step="0.01" min="0.01" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <!-- Dates -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Début du prêt *</label>
          <input v-model="form.started_on" type="date" required class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Retour prévu</label>
          <input v-model="form.due_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">{{ form.kind === 'money' ? 'Remboursé le' : 'Rendu le' }}</label>
          <input v-model="form.returned_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
          <p class="text-xs text-gray-400 mt-1">Vide tant que le prêt court.</p>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
        <textarea v-model="form.notes" rows="3" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="État de l'objet, conditions, remboursements..."></textarea>
      </div>

      <div class="flex gap-2">
        <button type="submit" :disabled="saving" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50">
          {{ saving ? 'Enregistrement...' : 'Enregistrer' }}
        </button>
        <button type="button" @click="$emit('cancel')" class="bg-white border border-gray-300 text-gray-700 text-sm px-4 py-2 rounded-lg hover:border-gray-500 transition">
          Annuler
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { reactive, ref, computed } from 'vue'
import { directions, kinds, contactName, todayIso } from '../../composables/useLoans'

const props = defineProps({
  initial: { type: Object, default: null },
  // Pre-remplissage d'un nouveau pret (contact choisi depuis ?contact=)
  defaults: { type: Object, default: () => ({}) },
  contacts: { type: Array, default: () => [] },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})

const emit = defineEmits(['submit', 'cancel'])

const FIELDS = ['direction', 'kind', 'item', 'amount', 'repaid_amount', 'started_on', 'due_on', 'returned_on', 'notes']

const source = props.initial || { direction: 'lent', kind: 'object', started_on: todayIso(), ...props.defaults }
const form = reactive(Object.fromEntries(FIELDS.map(field => [field, source[field] ?? ''])))

const initialContact = props.contacts.find(c => c.id === source.contact_id)
const personInput = ref(initialContact ? contactName(initialContact) : (source.person_name || ''))

// Un nom qui correspond exactement a un contact le lie ; sinon c'est un nom libre.
const linkedContact = computed(() => {
  const name = personInput.value.trim().toLowerCase()
  return name ? props.contacts.find(c => contactName(c).toLowerCase() === name) || null : null
})

const submit = () => {
  const attributes = { ...form, contact_id: linkedContact.value?.id ?? '', person_name: personInput.value.trim() }
  // Les champs propres a l'argent ne survivent pas a un passage en objet.
  if (form.kind === 'object') attributes.repaid_amount = ''
  emit('submit', attributes)
}
</script>
