<template>
  <BaseModal :title="client ? 'Modifier le client' : 'Nouveau client'" max-width-class="max-w-2xl" @close="$emit('close')">
    <form @submit.prevent="save" class="space-y-6">
      <section>
        <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Identite</h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="sm:col-span-2">
            <label class="block text-xs text-gray-500 mb-1">Nom / Raison sociale *</label>
            <input v-model="form.name" type="text" required class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Email</label>
            <input v-model="form.email" type="email" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Telephone</label>
            <input v-model="form.phone" type="tel" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">SIRET</label>
            <input v-model="form.siret" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">N° TVA</label>
            <input v-model="form.vat_number" type="text" class="input-field" />
          </div>
        </div>
      </section>

      <section>
        <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Adresse</h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="sm:col-span-2">
            <label class="block text-xs text-gray-500 mb-1">Adresse</label>
            <input v-model="form.address_line1" type="text" class="input-field" />
          </div>
          <div class="sm:col-span-2">
            <label class="block text-xs text-gray-500 mb-1">Complement</label>
            <input v-model="form.address_line2" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Code postal</label>
            <input v-model="form.postal_code" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Ville</label>
            <input v-model="form.city" type="text" class="input-field" />
          </div>
          <div>
            <label class="block text-xs text-gray-500 mb-1">Pays</label>
            <input v-model="form.country" type="text" class="input-field" />
          </div>
        </div>
      </section>

      <section>
        <label class="block text-xs text-gray-500 mb-1">Notes</label>
        <textarea v-model="form.notes" rows="2" class="input-field"></textarea>
      </section>

      <div class="flex gap-2 justify-end">
        <button type="button" @click="$emit('close')" class="bg-gray-200 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50">
          {{ saving ? 'Enregistrement...' : (client ? 'Modifier' : 'Enregistrer') }}
        </button>
      </div>
    </form>
  </BaseModal>
</template>

<script setup>
import { ref, reactive } from 'vue'
import apiClient from '../../plugins/axios'
import BaseModal from './BaseModal.vue'

const props = defineProps({
  company: { type: Object, required: true },
  client: { type: Object, default: null },
})
const emit = defineEmits(['close', 'saved'])

const saving = ref(false)

const form = reactive({
  name: props.client?.name || '',
  email: props.client?.email || '',
  phone: props.client?.phone || '',
  siret: props.client?.siret || '',
  vat_number: props.client?.vat_number || '',
  address_line1: props.client?.address_line1 || '',
  address_line2: props.client?.address_line2 || '',
  postal_code: props.client?.postal_code || '',
  city: props.client?.city || '',
  country: props.client?.country || 'France',
  notes: props.client?.notes || '',
})

const save = async () => {
  saving.value = true
  try {
    if (props.client) {
      await apiClient.patch(`/companies/${props.company.id}/clients/${props.client.id}`, form)
    } else {
      await apiClient.post(`/companies/${props.company.id}/clients`, form)
    }
    emit('saved')
  } catch (e) {
    console.error('Erreur sauvegarde client:', e)
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
