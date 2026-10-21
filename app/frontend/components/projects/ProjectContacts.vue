<template>
  <div class="bg-white rounded-xl shadow-sm p-5">
    <div class="flex items-center justify-between mb-1">
      <h2 class="text-lg font-semibold text-gray-900">Contacts du projet</h2>
      <button @click="showForm = !showForm" class="text-blue-600 hover:text-blue-800 text-sm font-medium">
        {{ showForm ? 'Fermer' : '+ Lier un contact' }}
      </button>
    </div>
    <p class="text-xs text-gray-400 mb-4">
      Le suivi est celui du CRM : une modification ici se retrouve sur la page CRM, et inversement.
    </p>

    <form v-if="showForm" @submit.prevent="link" class="bg-gray-50 rounded-lg p-4 mb-4 grid grid-cols-1 sm:grid-cols-3 gap-3">
      <select v-model="form.contact_id" required class="border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white">
        <option :value="null" disabled>Choisir un contact</option>
        <option v-for="c in availableContacts" :key="c.id" :value="c.id">
          {{ [c.last_name, c.first_name].filter(Boolean).join(' ') }}{{ c.crm_profile ? '' : ' (hors CRM)' }}
        </option>
      </select>
      <input v-model="form.role" type="text" maxlength="120" placeholder="Rôle (conseiller, associé, client...)" class="border border-gray-300 rounded-lg px-3 py-2 text-sm bg-white" />
      <button type="submit" :disabled="!form.contact_id || saving" class="bg-blue-600 text-white rounded-lg px-3 py-2 text-sm font-medium hover:bg-blue-700 transition-colors disabled:opacity-50">
        Lier au projet
      </button>
      <p class="text-xs text-gray-400 sm:col-span-3">Un contact hors CRM y est ajouté en le liant.</p>
    </form>

    <div
      v-for="alert in dueAlerts"
      :key="'due-' + alert.key"
      class="mb-3 px-3 py-2 bg-rose-50 border border-rose-200 rounded-lg text-sm text-rose-800"
    >
      <strong>{{ alert.name }}</strong> — à relancer le {{ formatCrmDate(alert.next_appointment_on) }}
    </div>

    <CrmProfilesTable
      v-if="rows.length"
      :rows="rows"
      show-role
      remove-label="Retirer du projet"
      @changed="fetchLinks"
      @remove="unlink"
    />
    <p v-else-if="!showForm" class="text-sm text-gray-400 text-center py-2">Aucun contact lié</p>
  </div>
</template>

<script setup>
import { ref, reactive, computed, watch, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { formatCrmDate, crmDueAlerts } from '../../composables/useCrm'
import CrmProfilesTable from '../contacts/CrmProfilesTable.vue'

const props = defineProps({
  projectId: { type: [Number, String], required: true },
})

// Emet la liste des contacts lies (pour le choix de l'interlocuteur dans le journal).
const emit = defineEmits(['changed'])

const { get, post, delete: del } = useApi()

const links = ref([])
const allContacts = ref([])
const showForm = ref(false)
const saving = ref(false)
const form = reactive({ contact_id: null, role: '' })

const base = computed(() => `/projects/${props.projectId}/project_contacts`)

const rows = computed(() =>
  links.value.map((l) => ({
    key: l.id, contact: l.contact, profile: l.crm_profile, role: l.role, roleUrl: `${base.value}/${l.id}`,
  })),
)

const dueAlerts = computed(() => crmDueAlerts(rows.value))

const availableContacts = computed(() => {
  const linked = new Set(links.value.map((l) => l.contact_id))
  return allContacts.value.filter((c) => !linked.has(c.id))
})

const fetchLinks = async () => {
  links.value = await get(base.value) || []
  emit('changed', links.value.map((l) => l.contact))
}

// La liste complete des contacts n'est chargee qu'a l'ouverture du formulaire.
watch(showForm, async (open) => {
  if (open && !allContacts.value.length) allContacts.value = await get('/contacts') || []
})

const link = async () => {
  saving.value = true
  try {
    await post(base.value, { project_contact: { contact_id: form.contact_id, role: form.role || null } })
    Object.assign(form, { contact_id: null, role: '' })
    showForm.value = false
    allContacts.value = []
    await fetchLinks()
  } catch (e) {
    alert(e.response?.data?.errors?.join('\n') || 'Lien impossible')
  } finally {
    saving.value = false
  }
}

const unlink = async (row) => {
  if (!confirm('Retirer ce contact du projet ? Sa fiche CRM est conservée.')) return
  await del(row.roleUrl)
  await fetchLinks()
}

onMounted(fetchLinks)
</script>
