<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <h2 class="text-lg font-semibold mb-4">{{ initial ? 'Modifier le véhicule' : 'Nouveau véhicule' }}</h2>

    <ul v-if="errors.length" class="mb-4 text-sm text-red-600 list-disc list-inside">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>

    <form @submit.prevent="submit" class="space-y-6">
      <!-- Identification -->
      <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4">
        <div class="sm:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">Nom *</label>
          <input v-model="form.name" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="La Clio, la Bonneville..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
          <select v-model="form.vehicle_type" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="t in vehicleTypes" :key="t.value" :value="t.value">{{ t.icon }} {{ t.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Statut</label>
          <select v-model="form.status" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="s in vehicleStatuses" :key="s.value" :value="s.value">{{ s.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Marque</label>
          <input v-model="form.brand" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Renault" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Modèle</label>
          <input v-model="form.model" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Clio V" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Version / finition</label>
          <input v-model="form.version" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="TCe 90 Evolution" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Année modèle</label>
          <input v-model="form.year" type="number" min="1886" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Immatriculation</label>
          <input v-model="form.registration_number" type="text" class="w-full border rounded-lg px-3 py-2 text-sm uppercase" placeholder="AB-123-CD" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">1re mise en circulation</label>
          <input v-model="form.first_registration_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" title="Case B de la carte grise" />
        </div>
        <div class="sm:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">N° de série (VIN)</label>
          <input v-model="form.vin" type="text" class="w-full border rounded-lg px-3 py-2 text-sm uppercase font-mono" title="Case E de la carte grise" />
        </div>
      </div>

      <!-- Caracteristiques -->
      <div>
        <h3 class="text-sm font-semibold text-gray-900 mb-2">Caractéristiques</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Énergie</label>
            <select v-model="form.fuel" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="">--</option>
              <option v-for="f in fuels" :key="f.value" :value="f.value">{{ f.label }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Puissance fiscale (CV)</label>
            <input v-model="form.fiscal_power" type="number" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Puissance (ch)</label>
            <input v-model="form.power_hp" type="number" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Cylindrée (cm³)</label>
            <input v-model="form.engine_displacement" type="number" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Couleur</label>
            <input v-model="form.color" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Pneus</label>
            <input v-model="form.tire_size" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="195/55 R16 87H" />
          </div>
          <div class="col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Huile préconisée</label>
            <input v-model="form.oil_type" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="5W30 RN17, 4,1 L" />
          </div>
        </div>
      </div>

      <!-- Achat et kilometrage -->
      <div>
        <h3 class="text-sm font-semibold text-gray-900 mb-2">Achat et kilométrage</h3>
        <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Acheté le</label>
            <input v-model="form.purchased_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Prix d'achat (€)</label>
            <input v-model="form.purchase_price" type="number" step="0.01" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Km à l'achat</label>
            <input v-model="form.purchase_mileage" type="number" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Km actuel</label>
            <input v-model="form.mileage" type="number" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Relevé le</label>
            <input v-model="form.mileage_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
        </div>
      </div>

      <!-- Echeances -->
      <div>
        <h3 class="text-sm font-semibold text-gray-900 mb-2">Échéances</h3>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Prochain contrôle technique</label>
            <input v-model="form.technical_inspection_due_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
            <p class="text-xs text-gray-400 mt-1">Mis à jour tout seul quand un contrôle est consigné dans le carnet.</p>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Révision tous les (km)</label>
            <input v-model="form.service_interval_km" type="number" min="0" step="1000" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="15000" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">ou tous les (mois)</label>
            <input v-model="form.service_interval_months" type="number" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="12" />
          </div>
        </div>
      </div>

      <!-- Vente -->
      <div v-if="form.status === 'vendu'" class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Vendu le</label>
          <input v-model="form.sold_on" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Prix de vente (€)</label>
          <input v-model="form.sale_price" type="number" step="0.01" min="0" class="w-full border rounded-lg px-3 py-2 text-sm" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Notes</label>
        <textarea v-model="form.notes" rows="3" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Code de l'autoradio, emplacement du double de clé, options..."></textarea>
      </div>

      <div class="flex justify-end gap-2">
        <button type="button" @click="$emit('cancel')" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50">
          {{ initial ? 'Enregistrer' : 'Ajouter' }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { vehicleTypes, vehicleStatuses, fuels } from '../../composables/useVehicles'

const props = defineProps({
  initial: { type: Object, default: null },
  defaultType: { type: String, default: 'voiture' },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})
const emit = defineEmits(['submit', 'cancel'])

const FIELDS = [
  'name', 'brand', 'model', 'version', 'year', 'registration_number', 'vin', 'first_registration_on',
  'fuel', 'fiscal_power', 'power_hp', 'engine_displacement', 'color', 'tire_size', 'oil_type',
  'purchased_on', 'purchase_price', 'purchase_mileage', 'mileage', 'mileage_on',
  'technical_inspection_due_on', 'service_interval_km', 'service_interval_months', 'sold_on', 'sale_price', 'notes',
]

const form = ref({
  ...Object.fromEntries(FIELDS.map((field) => [field, props.initial?.[field] ?? ''])),
  vehicle_type: props.initial?.vehicle_type || props.defaultType,
  status: props.initial?.status || 'active',
})

// Champs vides envoyes a null : une date ou un nombre vide n'est pas une chaine.
const submit = () => {
  if (!String(form.value.name).trim()) return
  const attributes = Object.fromEntries(
    Object.entries(form.value).map(([key, value]) => [key, typeof value === 'string' ? (value.trim() || null) : value])
  )
  emit('submit', attributes)
}
</script>
