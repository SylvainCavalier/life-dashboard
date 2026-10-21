<template>
  <div class="overflow-x-auto">
    <table class="w-full">
      <thead>
        <tr class="border-b border-gray-200 text-left text-xs text-gray-500 uppercase tracking-wider">
          <th class="pb-3 font-medium">Contact</th>
          <th v-if="showRole" class="pb-3 font-medium">Rôle</th>
          <th class="pb-3 font-medium">Téléphone</th>
          <th class="pb-3 font-medium">Email</th>
          <th class="pb-3 font-medium">Priorité</th>
          <th class="pb-3 font-medium">Dernier contact</th>
          <th class="pb-3 font-medium">Prochain RDV</th>
          <th v-if="showProjects" class="pb-3 font-medium">Projets</th>
          <th class="pb-3 font-medium">Notes</th>
          <th class="pb-3 font-medium w-16"></th>
        </tr>
      </thead>
      <tbody>
        <template v-for="row in rows" :key="row.key">
          <tr class="border-b border-gray-100 hover:bg-gray-50">
            <td class="py-3 pr-3 text-sm text-gray-900 font-medium whitespace-nowrap">
              {{ [row.contact.last_name, row.contact.first_name].filter(Boolean).join(' ') }}
            </td>
            <td v-if="showRole" class="py-3 pr-3 text-sm text-gray-500">{{ row.role || '—' }}</td>
            <td class="py-3 pr-3 text-sm text-gray-700 whitespace-nowrap">
              <a v-if="row.contact.phone" :href="'tel:' + row.contact.phone" class="text-indigo-600 hover:underline">{{ row.contact.phone }}</a>
              <span v-else>—</span>
            </td>
            <td class="py-3 pr-3 text-sm text-gray-700">
              <a v-if="row.contact.email" :href="'mailto:' + row.contact.email" class="text-indigo-600 hover:underline">{{ row.contact.email }}</a>
              <span v-else>—</span>
            </td>
            <template v-if="row.profile">
              <td class="py-3 pr-3">
                <span class="inline-block px-2 py-0.5 rounded-full text-xs font-medium" :class="crmPriorityBadge(row.profile.priority)">
                  {{ crmPriorityLabel(row.profile.priority) }}
                </span>
              </td>
              <td class="py-3 pr-3 text-sm text-gray-700 whitespace-nowrap">
                {{ formatCrmDate(row.profile.last_contact_on) }}
                <span v-if="row.profile.last_contact_method" class="text-gray-400">({{ crmMethodLabel(row.profile.last_contact_method) }})</span>
              </td>
              <td class="py-3 pr-3 text-sm whitespace-nowrap" :class="isCrmDue(row.profile.next_appointment_on) ? 'text-rose-600 font-medium' : 'text-gray-700'">
                {{ formatCrmDate(row.profile.next_appointment_on) }}
              </td>
            </template>
            <td v-else colspan="3" class="py-3 pr-3 text-sm text-gray-400">
              Hors CRM
              <button type="button" class="ml-2 text-indigo-600 hover:text-indigo-800 font-medium" @click="addToCrm(row)">Ajouter au CRM</button>
            </td>
            <td v-if="showProjects" class="py-3 pr-3">
              <div class="flex flex-wrap gap-1">
                <router-link
                  v-for="project in row.projects || []"
                  :key="project.id"
                  :to="`/projects/${project.id}`"
                  class="text-xs bg-slate-100 text-slate-700 hover:bg-slate-200 px-2 py-0.5 rounded-full whitespace-nowrap"
                >{{ project.name }}</router-link>
                <span v-if="!row.projects?.length" class="text-sm text-gray-300">—</span>
              </div>
            </td>
            <td class="py-3 pr-3 text-sm text-gray-500 max-w-xs truncate">{{ row.profile?.notes || '—' }}</td>
            <td class="py-3 text-right whitespace-nowrap">
              <button v-if="row.profile || showRole" @click="edit(row)" class="text-gray-400 hover:text-indigo-600 text-sm mr-2" title="Modifier">
                <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                </svg>
              </button>
              <button @click="$emit('remove', row)" class="text-gray-400 hover:text-red-600 text-sm" :title="removeLabel">
                <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
              </button>
            </td>
          </tr>
          <!-- Formulaire d'édition inline -->
          <tr v-if="editingKey === row.key">
            <td :colspan="columnCount" class="pb-4">
              <form @submit.prevent="save(row)" class="p-5 bg-gray-50 rounded-lg grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                <input
                  v-if="showRole"
                  v-model="form.role"
                  type="text"
                  placeholder="Rôle dans le projet"
                  class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:col-span-2 lg:col-span-3"
                />
                <template v-if="row.profile">
                  <select v-model="form.priority" class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
                    <option v-for="p in crmPriorities" :key="p.value" :value="p.value">{{ p.label }}</option>
                  </select>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Dernier contact</label>
                    <input v-model="form.last_contact_on" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                  </div>
                  <select v-model="form.last_contact_method" class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500">
                    <option value="">Moyen de contact</option>
                    <option v-for="m in crmContactMethods" :key="m.value" :value="m.value">{{ m.label }}</option>
                  </select>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Prochain rendez-vous</label>
                    <input v-model="form.next_appointment_on" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                  </div>
                  <textarea
                    v-model="form.notes"
                    placeholder="Notes CRM"
                    rows="2"
                    class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 sm:col-span-2 lg:col-span-3"
                  ></textarea>
                </template>
                <div class="flex gap-2 sm:col-span-2 lg:col-span-3">
                  <button type="submit" :disabled="saving" class="bg-green-600 text-white px-5 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50">
                    Enregistrer
                  </button>
                  <button type="button" @click="editingKey = null" class="bg-gray-200 text-gray-700 px-5 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">
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
</template>

<script setup>
import { ref, reactive, computed } from 'vue'
import { useApi } from '../../composables/useApi'
import {
  crmPriorities, crmContactMethods, formatCrmDate, isCrmDue,
  crmPriorityLabel, crmPriorityBadge, crmMethodLabel,
} from '../../composables/useCrm'

// rows : [{ key, contact, profile (CrmProfile ou null), projects?, role?, roleUrl? }]
// Le suivi s'enregistre ici (/api/crm_profiles) ; le role d'un contact de projet sur roleUrl.
const props = defineProps({
  rows: { type: Array, required: true },
  showProjects: { type: Boolean, default: false },
  showRole: { type: Boolean, default: false },
  removeLabel: { type: String, default: 'Retirer du CRM' },
})

const emit = defineEmits(['changed', 'remove'])

const { post, patch } = useApi()

const editingKey = ref(null)
const saving = ref(false)
const form = reactive({})

const columnCount = computed(() => 8 + (props.showRole ? 1 : 0) + (props.showProjects ? 1 : 0))

const edit = (row) => {
  const profile = row.profile || {}
  Object.assign(form, {
    role: row.role || '',
    priority: profile.priority || 'moyenne',
    last_contact_on: profile.last_contact_on || '',
    last_contact_method: profile.last_contact_method || '',
    next_appointment_on: profile.next_appointment_on || '',
    notes: profile.notes || '',
  })
  editingKey.value = row.key
}

const showError = (e, fallback) => {
  const errors = e.response?.data?.errors
  alert(errors ? errors.join('\n') : fallback)
}

const save = async (row) => {
  saving.value = true
  try {
    if (row.profile) {
      const attributes = {
        priority: form.priority,
        last_contact_on: form.last_contact_on || null,
        last_contact_method: form.last_contact_method || null,
        next_appointment_on: form.next_appointment_on || null,
        notes: form.notes || null,
      }
      await patch(`/crm_profiles/${row.profile.id}`, { crm_profile: attributes })
    }
    if (props.showRole && row.roleUrl && form.role !== (row.role || '')) {
      await patch(row.roleUrl, { project_contact: { role: form.role || null } })
    }
    editingKey.value = null
    emit('changed')
  } catch (e) {
    showError(e, 'Enregistrement impossible')
  } finally {
    saving.value = false
  }
}

const addToCrm = async (row) => {
  try {
    await post('/crm_profiles', { crm_profile: { contact_id: row.contact.id } })
    emit('changed')
  } catch (e) {
    showError(e, 'Ajout au CRM impossible')
  }
}
</script>
