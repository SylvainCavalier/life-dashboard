<template>
  <BaseModal :title="`Nouveau devis — ${company?.name}`" @close="$emit('close')">
    <form @submit.prevent="save" class="space-y-6">
      <!-- Client enregistre -->
      <section v-if="clients.length">
        <label class="block text-xs text-gray-500 mb-1">Client enregistre</label>
        <select v-model="selectedClientId" @change="applyClient" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
          <option :value="null">-- Saisie manuelle --</option>
          <option v-for="c in clients" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </section>

      <!-- Infos client -->
      <section>
        <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Client</h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs text-gray-500 mb-1">Nom du client *</label>
            <input v-model="form.client_name" type="text" required class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Email</label>
            <input v-model="form.client_email" type="email" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Telephone</label>
            <input v-model="form.client_phone" type="tel" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">SIRET</label>
            <input v-model="form.client_siret" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">N° TVA</label>
            <input v-model="form.client_vat_number" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Adresse</label>
            <input v-model="form.client_address_line1" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Code postal</label>
            <input v-model="form.client_postal_code" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Ville</label>
            <input v-model="form.client_city" type="text" class="input-field" />
          </div>
        </div>
      </section>

      <!-- Details du devis -->
      <section>
        <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Details du devis</h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div>
            <label class="block text-xs text-gray-500 mb-1">Objet</label>
            <input v-model="form.subject" type="text" placeholder="ex: Prestation de conseil" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Date d'emission</label>
            <input v-model="form.issue_date" type="date" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Date de validite</label>
            <input v-model="form.validity_date" type="date" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Taux TVA (%)</label>
            <input v-model.number="form.tva_rate" type="number" step="0.01" min="0" :disabled="form.tva_exempt" class="input-field disabled:bg-gray-100 disabled:text-gray-400" />
          </div>
          <div class="flex items-center gap-2 self-end pb-2">
            <input v-model="form.tva_exempt" type="checkbox" id="quote-tva-exempt" @change="onTvaExemptChange" class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500" />
            <label for="quote-tva-exempt" class="text-sm text-gray-700">Exonere de TVA</label>
          </div>
        </div>
        <p v-if="form.tva_exempt" class="text-xs text-amber-600 mt-2">TVA non applicable, art. 293 B du CGI</p>
      </section>

      <!-- Lignes du devis -->
      <section>
        <div class="flex items-center justify-between mb-3 border-b pb-2">
          <h3 class="text-sm font-semibold text-gray-700">Lignes du devis</h3>
          <button type="button" @click="addItem" class="text-indigo-600 hover:text-indigo-800 text-xs font-medium">+ Ajouter une ligne</button>
        </div>
        <div v-for="(item, index) in form.items" :key="index" class="bg-gray-50 rounded-lg p-3 mb-2">
          <div class="grid grid-cols-12 gap-2 items-start">
            <div class="col-span-4">
              <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Description *</label>
              <textarea v-model="item.description" rows="3" required placeholder="Prestation..." class="input-field resize-y"></textarea>
            </div>
            <div class="col-span-1">
              <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Qte *</label>
              <input v-model.number="item.quantity" type="number" step="0.01" min="0.01" required class="input-field" />
            </div>
            <div class="col-span-2">
              <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Unite</label>
              <select v-model="item.unit" class="input-field bg-white">
                <option v-for="u in unitTypes" :key="u.value" :value="u.value">{{ u.label }}</option>
              </select>
            </div>
            <div class="col-span-2">
              <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Prix unit. HT *</label>
              <input v-model.number="item.unit_price" type="number" step="0.01" min="0" required class="input-field" />
            </div>
            <div class="col-span-2 text-right text-sm font-semibold text-gray-700 py-2">
              {{ formatCurrency(computeLineTotal(item)) }}
            </div>
            <div class="col-span-1">
              <button v-if="form.items.length > 1" type="button" @click="removeItem(index)" class="text-red-500 hover:text-red-700 p-2">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
          </div>
          <div class="grid grid-cols-12 gap-2 mt-1 items-center">
            <div class="col-span-4"></div>
            <div class="col-span-2">
              <select v-model="item.discount_type" class="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-indigo-500 bg-white text-gray-500">
                <option value="none">Pas de remise</option>
                <option value="percent">Remise %</option>
                <option value="amount">Remise fixe</option>
              </select>
            </div>
            <div class="col-span-2">
              <input v-if="item.discount_type && item.discount_type !== 'none'" v-model.number="item.discount_value" type="number" step="0.01" min="0" :placeholder="item.discount_type === 'percent' ? '%' : 'EUR'" class="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-indigo-500" />
            </div>
            <div class="col-span-4"></div>
          </div>
        </div>
      </section>

      <!-- Totaux -->
      <section class="bg-gray-50 rounded-lg p-4">
        <div class="flex justify-end">
          <div class="w-64 space-y-1">
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">Total HT</span>
              <span class="font-semibold text-gray-900">{{ formatCurrency(totalHT) }}</span>
            </div>
            <div class="flex justify-between text-sm">
              <span class="text-gray-600">{{ form.tva_exempt ? 'TVA (exoneree)' : 'TVA (' + form.tva_rate + '%)' }}</span>
              <span class="font-semibold text-gray-900">{{ formatCurrency(totalTVA) }}</span>
            </div>
            <div class="flex justify-between text-sm font-bold border-t pt-1">
              <span class="text-gray-900">Total TTC</span>
              <span class="text-gray-900">{{ formatCurrency(totalTTC) }}</span>
            </div>
          </div>
        </div>
      </section>

      <!-- Notes et conditions -->
      <section>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs text-gray-500 mb-1">Conditions de paiement</label>
            <textarea v-model="form.conditions" rows="2" placeholder="ex: Paiement a 30 jours..." class="input-field"></textarea>
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Notes</label>
            <textarea v-model="form.notes" rows="2" class="input-field"></textarea>
          </div>
        </div>
      </section>

      <div class="flex gap-2 justify-end">
        <button type="button" @click="$emit('close')" class="bg-gray-200 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50">
          {{ saving ? 'Generation...' : 'Generer le devis' }}
        </button>
      </div>
    </form>
  </BaseModal>
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import apiClient from '../../plugins/axios'
import { useFormat, unitTypes } from '../../composables/useFormat'
import BaseModal from './BaseModal.vue'

const props = defineProps({
  company: { type: Object, required: true },
  clients: { type: Array, default: () => [] },
  initialData: { type: Object, default: null },
})
const emit = defineEmits(['close', 'saved'])

const { formatCurrency, computeLineTotal } = useFormat()

const saving = ref(false)
const selectedClientId = ref(null)

const today = new Date().toISOString().split('T')[0]
const validity = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
const isAutoEntrepreneur = props.company.legal_form === 'auto_entrepreneur'

const defaultItem = () => ({ description: '', quantity: 1, unit: 'unite', unit_price: null, discount_type: 'none', discount_value: null })

const form = reactive(props.initialData ? buildFromInitial(props.initialData) : {
  client_id: null,
  client_name: '', client_email: '', client_phone: '',
  client_siret: '', client_vat_number: '',
  client_address_line1: '', client_postal_code: '', client_city: '',
  subject: '', issue_date: today, validity_date: validity,
  tva_rate: isAutoEntrepreneur ? 0 : 20,
  tva_exempt: isAutoEntrepreneur,
  notes: '', conditions: '',
  items: [defaultItem()],
})

function buildFromInitial(q) {
  return {
    client_id: q.client_id || null,
    client_name: q.client_name || '',
    client_email: q.client_email || '',
    client_phone: q.client_phone || '',
    client_siret: q.client_siret || '',
    client_vat_number: q.client_vat_number || '',
    client_address_line1: q.client_address_line1 || '',
    client_postal_code: q.client_postal_code || '',
    client_city: q.client_city || '',
    subject: q.subject || '',
    issue_date: today,
    validity_date: validity,
    tva_rate: q.tva_rate ?? (isAutoEntrepreneur ? 0 : 20),
    tva_exempt: q.tva_rate === 0 || q.tva_rate === '0',
    notes: q.notes || '',
    conditions: q.conditions || '',
    items: (q.items || []).length ? q.items.map(item => ({
      description: item.description,
      quantity: item.quantity,
      unit: item.unit,
      unit_price: item.unit_price,
      discount_type: item.discount_type || 'none',
      discount_value: item.discount_value || null,
    })) : [defaultItem()],
  }
}

const applyClient = () => {
  if (!selectedClientId.value) {
    form.client_id = null
    return
  }
  const c = props.clients.find(cl => cl.id === selectedClientId.value)
  if (!c) return
  form.client_id = c.id
  form.client_name = c.name || ''
  form.client_email = c.email || ''
  form.client_phone = c.phone || ''
  form.client_siret = c.siret || ''
  form.client_vat_number = c.vat_number || ''
  form.client_address_line1 = c.address_line1 || ''
  form.client_postal_code = c.postal_code || ''
  form.client_city = c.city || ''
}

const onTvaExemptChange = () => {
  form.tva_rate = form.tva_exempt ? 0 : 20
}

const addItem = () => form.items.push(defaultItem())
const removeItem = (index) => form.items.splice(index, 1)

const totalHT = computed(() => form.items.reduce((sum, item) => sum + computeLineTotal(item), 0))
const totalTVA = computed(() => Math.round(totalHT.value * (form.tva_rate || 0) / 100 * 100) / 100)
const totalTTC = computed(() => totalHT.value + totalTVA.value)

const save = async () => {
  saving.value = true
  try {
    const payload = {
      client_id: form.client_id,
      client_name: form.client_name,
      client_email: form.client_email,
      client_phone: form.client_phone,
      client_siret: form.client_siret,
      client_vat_number: form.client_vat_number,
      client_address_line1: form.client_address_line1,
      client_postal_code: form.client_postal_code,
      client_city: form.client_city,
      subject: form.subject,
      issue_date: form.issue_date,
      validity_date: form.validity_date,
      tva_rate: form.tva_rate,
      notes: form.notes,
      conditions: form.conditions,
      quote_items_attributes: form.items.map((item, i) => ({
        description: item.description,
        quantity: item.quantity,
        unit: item.unit,
        unit_price: item.unit_price,
        discount_type: item.discount_type || 'none',
        discount_value: item.discount_value || 0,
        position: i,
      })),
    }
    await apiClient.post(`/companies/${props.company.id}/quotes`, payload)
    emit('saved')
  } catch (e) {
    console.error('Erreur creation devis:', e)
  } finally {
    saving.value = false
  }
}
</script>

<style scoped>
.input-field {
  @apply w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500;
}
</style>
