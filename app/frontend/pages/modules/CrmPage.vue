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
        :key="'due-' + alert.key"
        class="mb-3 flex items-center gap-3 px-4 py-3 bg-rose-50 border border-rose-200 rounded-lg text-sm text-rose-800"
      >
        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
        </svg>
        <span>
          <strong>{{ alert.name }}</strong>
          — à relancer<template v-if="alert.next_appointment_on"> le {{ formatCrmDate(alert.next_appointment_on) }}</template>
        </span>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">📇</span>
            <h1 class="text-2xl font-bold text-gray-900">CRM</h1>
            <span class="text-sm text-gray-400">({{ rows.length }})</span>
          </div>
        </div>

        <div v-if="rows.length === 0" class="text-center text-gray-400 py-12">
          Aucun contact dans le CRM. Ajoute-en depuis la page Contacts.
        </div>

        <CrmProfilesTable v-else :rows="rows" show-projects @changed="fetchProfiles" @remove="removeFromCrm" />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { formatCrmDate, crmDueAlerts } from '../../composables/useCrm'
import ContactsCrmTabs from '../../components/contacts/ContactsCrmTabs.vue'
import CrmProfilesTable from '../../components/contacts/CrmProfilesTable.vue'

const { useCrud } = useApi()
const { list, destroy } = useCrud('crm_profiles')

const profiles = ref([])

const rows = computed(() =>
  profiles.value.map((profile) => ({ key: profile.id, contact: profile.contact, profile, projects: profile.projects })),
)

const dueAlerts = computed(() => crmDueAlerts(rows.value))

const fetchProfiles = async () => {
  profiles.value = await list()
}

const removeFromCrm = async (row) => {
  if (!confirm('Retirer ce contact du CRM ?')) return
  await destroy(row.profile.id)
  await fetchProfiles()
}

onMounted(fetchProfiles)
</script>
