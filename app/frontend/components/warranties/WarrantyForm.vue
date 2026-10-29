<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <h2 class="text-lg font-semibold mb-4">{{ initial ? 'Modifier la garantie' : 'Nouvelle garantie' }}</h2>

    <ul v-if="errors.length" class="mb-4 text-sm text-red-600 list-disc list-inside">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>

    <form @submit.prevent="submit" class="space-y-6">
      <!-- Objet -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">Objet *</label>
          <input v-model="form.name" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Lave-linge, MacBook Pro, aspirateur..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Marque</label>
          <input v-model="form.brand" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Bosch, Apple, Dyson..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Modèle / référence</label>
          <input v-model="form.model_reference" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Catégorie</label>
          <select v-model="form.category" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="c in warrantyCategories" :key="c.value" :value="c.value">{{ c.icon }} {{ c.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Numéro de série</label>
          <input v-model="form.serial_number" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <!-- Achat -->
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Date d'achat *</label>
          <input v-model="form.purchased_on" type="date" required class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Prix (€)</label>
          <input v-model="form.price" type="number" step="0.01" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Vendeur</label>
          <input v-model="form.store" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Darty, Fnac, Amazon..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">N° de commande</label>
          <input v-model="form.order_number" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <!-- Garantie -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Durée de garantie</label>
        <div class="flex flex-wrap items-center gap-2">
          <button
            v-for="preset in durationPresets"
            :key="preset.months"
            type="button"
            @click="setDuration(preset.months)"
            class="text-sm px-3 py-1.5 rounded-full border transition"
            :class="Number(form.duration_months) === preset.months ? 'bg-black text-white border-black' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-400'"
          >
            {{ preset.label }}
          </button>
          <div class="flex items-center gap-2">
            <input
              :value="form.duration_months"
              @input="setDuration($event.target.value)"
              type="number"
              min="1"
              class="w-20 border rounded-lg px-3 py-1.5 text-sm"
              placeholder="autre"
            />
            <span class="text-sm text-gray-500">mois</span>
          </div>
        </div>
        <p class="text-xs text-gray-400 mt-1">Garantie légale de conformité : 2 ans pour un bien neuf, 1 an d'occasion, acheté à un professionnel.</p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Fin de garantie *</label>
          <input v-model="form.ends_on" @input="endsManual = true" type="date" required class="w-full border rounded-lg px-3 py-2 text-sm" />
          <p class="text-xs text-gray-400 mt-1">Calculée depuis la date d'achat et la durée ; modifiable (extension de garantie...).</p>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">SAV / contact garantie</label>
          <input v-model="form.support_contact" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Téléphone, site, adresse mail du SAV" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
        <textarea v-model="form.notes" rows="3" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Extension souscrite, conditions, démarches..."></textarea>
      </div>

      <!-- Facture -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Facture / preuve d'achat</label>
        <div v-if="initial?.receipt && !removeReceipt && !receiptFile" class="flex items-center gap-3 text-sm mb-2">
          <a :href="initial.receipt.url" target="_blank" rel="noopener" class="text-indigo-600 hover:underline truncate">{{ initial.receipt.filename }}</a>
          <button type="button" @click="removeReceipt = true" class="text-red-500 hover:text-red-700 text-xs">Retirer</button>
        </div>
        <p v-if="removeReceipt" class="text-xs text-red-600 mb-2">
          La facture sera retirée à l'enregistrement.
          <button type="button" @click="removeReceipt = false" class="underline">Annuler</button>
        </p>
        <input type="file" accept="application/pdf,image/*" @change="pickFile" class="text-sm" />
        <p class="text-xs text-gray-400 mt-1">PDF ou photo, 10 Mo au plus. Alfred pourra la lire.</p>
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
import { reactive, ref, watch } from 'vue'
import { warrantyCategories, durationPresets, addMonths } from '../../composables/useWarranties'

const props = defineProps({
  initial: { type: Object, default: null },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})

const emit = defineEmits(['submit', 'cancel'])

const FIELDS = [
  'name', 'brand', 'model_reference', 'category', 'serial_number', 'store', 'order_number',
  'purchased_on', 'price', 'duration_months', 'ends_on', 'support_contact', 'notes',
]

const now = new Date()
const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
const form = reactive(Object.fromEntries(FIELDS.map(field => [field, props.initial?.[field] ?? ''])))
if (!props.initial) {
  form.category = 'autre'
  form.purchased_on = today
  form.duration_months = 24
  form.ends_on = addMonths(today, 24)
}

// Une fin saisie a la main (extension) n'est plus recalculee depuis la duree.
const endsManual = ref(Boolean(
  props.initial && (!props.initial.duration_months || addMonths(props.initial.purchased_on, props.initial.duration_months) !== props.initial.ends_on)
))
const receiptFile = ref(null)
const removeReceipt = ref(false)

const recompute = () => {
  if (endsManual.value || !form.purchased_on || !Number(form.duration_months)) return
  form.ends_on = addMonths(form.purchased_on, form.duration_months)
}

const setDuration = (months) => {
  form.duration_months = months === '' ? '' : Number(months)
  endsManual.value = false
  recompute()
}

watch(() => form.purchased_on, recompute)

const pickFile = (event) => {
  receiptFile.value = event.target.files[0] || null
}

const submit = () => {
  emit('submit', { attributes: { ...form }, receipt: receiptFile.value, removeReceipt: removeReceipt.value })
}
</script>
