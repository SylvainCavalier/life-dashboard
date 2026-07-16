<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
      <!-- Retour -->
      <router-link
        to="/"
        class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6"
      >
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour au dashboard
      </router-link>

      <ContactsCrmTabs />

      <!-- Alertes à relancer -->
      <div
        v-for="alert in dueAlerts"
        :key="'due-' + alert.id"
        class="mb-3 flex items-center gap-3 px-4 py-3 bg-rose-50 border border-rose-200 rounded-lg text-sm text-rose-800"
      >
        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
        </svg>
        <span>
          <strong>{{ [alert.first_name, alert.last_name].filter(Boolean).join(' ') }}</strong>
          — à relancer<template v-if="alert.next_appointment_on"> le {{ formatDate(alert.next_appointment_on) }}</template>
        </span>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">📇</span>
            <h1 class="text-2xl font-bold text-gray-900">CRM</h1>
            <span class="text-sm text-gray-400">({{ profiles.length }})</span>
          </div>
        </div>

        <div v-if="profiles.length === 0" class="text-center text-gray-400 py-12">
          Aucun contact dans le CRM. Ajoute-en depuis la page Contacts.
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-gray-200 text-left text-xs text-gray-500 uppercase tracking-wider">
                <th class="pb-3 font-medium">Contact</th>
                <th class="pb-3 font-medium">Téléphone</th>
                <th class="pb-3 font-medium">Email</th>
                <th class="pb-3 font-medium">Priorité</th>
                <th class="pb-3 font-medium">Dernier contact</th>
                <th class="pb-3 font-medium">Prochain RDV</th>
                <th class="pb-3 font-medium">Notes</th>
                <th class="pb-3 font-medium w-16"></th>
              </tr>
            </thead>
            <tbody>
              <template v-for="profile in profiles" :key="profile.id">
                <tr class="border-b border-gray-100 hover:bg-gray-50">
                  <td class="py-3 text-sm text-gray-900 font-medium whitespace-nowrap">
                    {{ [profile.contact.last_name, profile.contact.first_name].filter(Boolean).join(' ') }}
                  </td>
                  <td class="py-3 text-sm text-gray-700 whitespace-nowrap">
                    <a v-if="profile.contact.phone" :href="'tel:' + profile.contact.phone" class="text-indigo-600 hover:underline">{{ profile.contact.phone }}</a>
                    <span v-else>—</span>
                  </td>
                  <td class="py-3 text-sm text-gray-700">
                    <a v-if="profile.contact.email" :href="'mailto:' + profile.contact.email" class="text-indigo-600 hover:underline">{{ profile.contact.email }}</a>
                    <span v-else>—</span>
                  </td>
                  <td class="py-3">
                    <span
                      class="inline-block px-2 py-0.5 rounded-full text-xs font-medium"
                      :class="priorityBadge(profile.priority)"
                    >
                      {{ priorityLabel(profile.priority) }}
                    </span>
                  </td>
                  <td class="py-3 text-sm text-gray-700 whitespace-nowrap">
                    {{ formatDate(profile.last_contact_on) }}
                    <span v-if="profile.last_contact_method" class="text-gray-400">({{ methodLabel(profile.last_contact_method) }})</span>
                  </td>
                  <td class="py-3 text-sm whitespace-nowrap" :class="isDue(profile.next_appointment_on) ? 'text-rose-600 font-medium' : 'text-gray-700'">
                    {{ formatDate(profile.next_appointment_on) }}
                  </td>
                  <td class="py-3 text-sm text-gray-500 max-w-xs truncate">{{ profile.notes || '—' }}</td>
                  <td class="py-3 text-right whitespace-nowrap">
                    <button @click="editProfile(profile)" class="text-gray-400 hover:text-indigo-600 text-sm mr-2" title="Modifier">
                      <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                      </svg>
                    </button>
                    <button @click="removeFromCrm(profile)" class="text-gray-400 hover:text-red-600 text-sm" title="Retirer du CRM">
                      <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </td>
                </tr>
                <!-- Formulaire d'édition inline -->
                <tr v-if="editingId === profile.id">
                  <td colspan="8" class="pb-4">
                    <form @submit.prevent="saveProfile" class="p-5 bg-gray-50 rounded-lg grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                      <select
                        v-model="form.priority"
                        class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      >
                        <option v-for="p in priorities" :key="p.value" :value="p.value">{{ p.label }}</option>
                      </select>
                      <div>
                        <label class="block text-xs text-gray-500 mb-1">Dernier contact</label>
                        <input
                          v-model="form.last_contact_on"
                          type="date"
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>
                      <select
                        v-model="form.last_contact_method"
                        class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                      >
                        <option value="">Moyen de contact</option>
                        <option v-for="m in contactMethods" :key="m.value" :value="m.value">{{ m.label }}</option>
                      </select>
                      <div>
                        <label class="block text-xs text-gray-500 mb-1">Prochain rendez-vous</label>
                        <input
                          v-model="form.next_appointment_on"
                          type="date"
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>
                      <textarea
                        v-model="form.notes"
                        placeholder="Notes CRM"
                        rows="2"
                        class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:col-span-2 lg:col-span-3"
                      ></textarea>
                      <div class="flex gap-2 sm:col-span-2 lg:col-span-3">
                        <button
                          type="submit"
                          class="bg-green-600 text-white px-5 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
                        >
                          Enregistrer
                        </button>
                        <button
                          type="button"
                          @click="editingId = null"
                          class="bg-gray-200 text-gray-700 px-5 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium"
                        >
                          Annuler
                        </button>
                      </div>
                    </form>
                  </td>
                </tr>
              </template>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import ContactsCrmTabs from '../../components/contacts/ContactsCrmTabs.vue'

const { useCrud } = useApi()
const { list, update, destroy } = useCrud('crm_profiles')

const profiles = ref([])
const editingId = ref(null)

const priorities = [
  { value: 'haute', label: 'Haute' },
  { value: 'moyenne', label: 'Moyenne' },
  { value: 'basse', label: 'Basse' },
]

const contactMethods = [
  { value: 'telephone', label: 'Téléphone' },
  { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' },
  { value: 'visio', label: 'Visio' },
  { value: 'rencontre', label: 'Rencontre' },
  { value: 'autre', label: 'Autre' },
]

const defaultForm = {
  priority: 'moyenne',
  last_contact_on: '',
  last_contact_method: '',
  next_appointment_on: '',
  notes: '',
}

const form = reactive({ ...defaultForm })

const fetchProfiles = async () => {
  profiles.value = await list()
}

const editProfile = (profile) => {
  Object.assign(form, {
    priority: profile.priority,
    last_contact_on: profile.last_contact_on || '',
    last_contact_method: profile.last_contact_method || '',
    next_appointment_on: profile.next_appointment_on || '',
    notes: profile.notes || '',
  })
  editingId.value = profile.id
}

const saveProfile = async () => {
  const payload = { crm_profile: { ...form } }
  Object.keys(payload.crm_profile).forEach((key) => {
    if (payload.crm_profile[key] === '') payload.crm_profile[key] = null
  })
  await update(editingId.value, payload)
  editingId.value = null
  await fetchProfiles()
}

const removeFromCrm = async (profile) => {
  if (!confirm('Retirer ce contact du CRM ?')) return
  await destroy(profile.id)
  await fetchProfiles()
}

const formatDate = (date) => {
  if (!date) return '—'
  return new Date(date).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

const isDue = (date) => {
  if (!date) return false
  return new Date(date) <= new Date()
}

const priorityLabel = (value) => priorities.find((p) => p.value === value)?.label || value
const methodLabel = (value) => contactMethods.find((m) => m.value === value)?.label || value

const priorityBadge = (value) => {
  const colors = {
    haute: 'bg-rose-100 text-rose-700',
    moyenne: 'bg-amber-100 text-amber-700',
    basse: 'bg-gray-100 text-gray-600',
  }
  return colors[value] || 'bg-gray-100 text-gray-500'
}

const dueAlerts = computed(() => {
  return profiles.value
    .filter((p) => isDue(p.next_appointment_on))
    .map((p) => ({
      id: p.id,
      first_name: p.contact.first_name,
      last_name: p.contact.last_name,
      next_appointment_on: p.next_appointment_on,
    }))
    .sort((a, b) => new Date(a.next_appointment_on) - new Date(b.next_appointment_on))
})

onMounted(fetchProfiles)
</script>
