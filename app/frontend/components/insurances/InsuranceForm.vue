<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <h2 class="text-lg font-semibold mb-4">{{ title || (initial ? 'Modifier le contrat' : 'Nouvelle assurance') }}</h2>
    <slot name="intro" />

    <ul v-if="errors.length" class="mb-4 text-sm text-red-600 list-disc list-inside">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>

    <form @submit.prevent="submit" class="space-y-6">
      <!-- Contrat -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">Nom du contrat *</label>
          <input v-model="form.name" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Multirisque habitation appartement Créteil" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
          <select v-model="form.insurance_type" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="t in insuranceTypes" :key="t.value" :value="t.value">{{ t.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Statut</label>
          <select v-model="form.status" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="s in insuranceStatuses" :key="s.value" :value="s.value">{{ s.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Assureur</label>
          <input v-model="form.insurer" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="MAIF, AXA, Alan..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Numéro de contrat</label>
          <input v-model="form.policy_number" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <!-- Dates et cotisation -->
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Début</label>
          <input v-model="form.start_date" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Échéance principale</label>
          <input v-model="form.renewal_date" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" title="Date anniversaire du contrat : c'est avant elle qu'on résilie" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Fin</label>
          <input v-model="form.end_date" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Cotisation (€)</label>
          <div class="flex gap-2">
            <input v-model="form.premium" type="number" step="0.01" min="0" class="w-24 flex-1 border rounded-lg px-3 py-2 text-sm" />
            <select v-model="form.premium_frequency" class="border rounded-lg px-2 py-2 text-sm">
              <option v-for="f in premiumFrequencies" :key="f.value" :value="f.value">{{ f.label }}</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Contacts -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">N° sinistre / assistance</label>
          <input v-model="form.claims_phone" type="tel" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Espace client / site</label>
          <input v-model="form.website_url" type="url" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="https://..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Conseiller</label>
          <input v-model="form.advisor_name" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div class="grid grid-cols-2 gap-2">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Téléphone</label>
            <input v-model="form.advisor_phone" type="tel" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
            <input v-model="form.advisor_email" type="email" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Conditions importantes</label>
        <textarea v-model="form.conditions" rows="4" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Exclusions générales, délai de déclaration d'un sinistre, conditions de résiliation, obligations (alarme, serrure 3 points)..."></textarea>
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
        <textarea v-model="form.notes" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm"></textarea>
      </div>

      <!-- Garanties et biens extraits d'un contrat (import IA) -->
      <slot />

      <div class="flex justify-end gap-2">
        <button type="button" @click="$emit('cancel')" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50">
          {{ submitLabel || (initial ? 'Enregistrer' : 'Ajouter') }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { insuranceTypes, insuranceStatuses, premiumFrequencies } from '../../composables/useInsurances'

const props = defineProps({
  initial: { type: Object, default: null },
  title: { type: String, default: '' },
  submitLabel: { type: String, default: '' },
  defaultType: { type: String, default: 'habitation' },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})
const emit = defineEmits(['submit', 'cancel'])

const FIELDS = [
  'name', 'insurer', 'policy_number', 'start_date', 'end_date', 'renewal_date', 'premium',
  'conditions', 'notes', 'advisor_name', 'advisor_phone', 'advisor_email', 'claims_phone', 'website_url',
]

const form = ref({
  ...Object.fromEntries(FIELDS.map((field) => [field, props.initial?.[field] ?? ''])),
  insurance_type: props.initial?.insurance_type || props.defaultType,
  status: props.initial?.status || 'active',
  premium_frequency: props.initial?.premium_frequency || 'yearly',
})

// Champs vides envoyes a null : une date ou un montant vide n'est pas une chaine.
const submit = () => {
  if (!form.value.name.trim()) return
  const attributes = Object.fromEntries(
    Object.entries(form.value).map(([key, value]) => [key, typeof value === 'string' ? (value.trim() || null) : value])
  )
  emit('submit', attributes)
}
</script>
