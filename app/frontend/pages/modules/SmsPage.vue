<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-3xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <h1 class="text-2xl font-bold text-gray-900">Textos</h1>
      <p class="text-sm text-gray-500 mt-1 mb-6">
        <template v-if="overview?.configured">Alfred répond au {{ overview.number }}, uniquement aux numéros ci-dessous.</template>
        <span v-else-if="overview" class="text-amber-700">Twilio n'est pas configuré (voir DEPLOY.md) : aucun texto ne peut partir.</span>
      </p>

      <p v-if="error" class="mb-4 text-sm text-red-600">{{ error }}</p>

      <section v-if="overview?.pending.length" class="bg-white rounded-xl shadow-sm p-4 sm:p-5 mb-6">
        <h2 class="font-semibold text-gray-900 mb-3">Demandes en attente</h2>
        <ul class="divide-y divide-gray-100">
          <li v-for="request in overview.pending" :key="request.id" class="py-2 flex flex-wrap items-center justify-between gap-2">
            <div class="min-w-0">
              <p class="text-sm text-gray-900">{{ request.summary }}</p>
              <p class="text-xs text-gray-500">{{ request.from }} · {{ formatDate(request.created_at) }}</p>
            </div>
            <button type="button" class="text-sm px-3 py-1.5 rounded-lg bg-black text-white hover:bg-gray-800" @click="openInPanel(request.conversation_id)">Voir</button>
          </li>
        </ul>
      </section>

      <section class="bg-white rounded-xl shadow-sm p-4 sm:p-5 mb-6">
        <h2 class="font-semibold text-gray-900 mb-1">Numéros autorisés</h2>
        <p class="text-xs text-gray-500 mb-3">Un texto venu d'un autre numéro est ignoré, sans réponse ni coût.</p>

        <ul class="divide-y divide-gray-100 mb-4">
          <li v-for="person in overview?.correspondents || []" :key="person.id" class="py-2">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <button type="button" class="min-w-0 text-left" @click="toggleThread(person)">
                <p class="text-sm font-medium text-gray-900">
                  {{ person.name }}
                  <span v-if="person.owner" class="ml-1 text-[11px] px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700">moi</span>
                  <span v-if="!person.enabled" class="ml-1 text-[11px] px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">désactivé</span>
                </p>
                <p class="text-xs text-gray-500">{{ person.phone }}<span v-if="person.last_message_at"> · dernier texto {{ formatDate(person.last_message_at) }}</span></p>
              </button>
              <div class="flex flex-wrap items-center gap-2">
                <select :value="person.contact_id ?? ''" class="max-w-[12rem] rounded-lg border border-gray-300 px-2 py-1 text-xs text-gray-700" aria-label="Fiche contact liée" @change="linkContact(person, $event.target.value)">
                  <option value="">Sans fiche contact</option>
                  <option v-for="contact in overview.contacts" :key="contact.id" :value="contact.id">{{ contact.label }} ({{ contact.relationship }})</option>
                </select>
                <button type="button" class="text-xs px-2 py-1 rounded-lg border border-gray-300 text-gray-700 hover:bg-gray-50" @click="toggleEnabled(person)">{{ person.enabled ? 'Désactiver' : 'Activer' }}</button>
                <button type="button" class="text-xs px-2 py-1 rounded-lg border border-red-200 text-red-700 hover:bg-red-50" @click="removeCorrespondent(person)">Retirer</button>
              </div>
            </div>

            <div v-if="threadOf === person.id" class="mt-3 rounded-lg bg-gray-50 p-3">
              <p v-if="!thread.length" class="text-xs text-gray-500">Aucun texto pour l'instant.</p>
              <div class="space-y-2 max-h-80 overflow-y-auto">
                <div v-for="message in thread" :key="message.id" class="flex" :class="message.direction === 'outbound' ? 'justify-end' : 'justify-start'">
                  <div class="max-w-[85%] rounded-2xl px-3 py-1.5 text-sm whitespace-pre-wrap break-words" :class="message.direction === 'outbound' ? 'bg-gray-900 text-white' : 'bg-white border border-gray-200 text-gray-800'">
                    {{ message.body }}
                    <p class="text-[10px] mt-0.5 opacity-60">{{ formatDate(message.created_at) }}<span v-if="message.status === 'failed'"> · échec : {{ message.error }}</span></p>
                  </div>
                </div>
              </div>
              <form class="mt-3 flex gap-2" @submit.prevent="sendText(person)">
                <input v-model="draft" type="text" :maxlength="640" placeholder="Écrire un texto au nom d'Alfred..." class="min-w-0 flex-1 rounded-lg border border-gray-300 px-3 py-1.5 text-sm" />
                <button type="submit" class="text-sm px-3 py-1.5 rounded-lg bg-black text-white hover:bg-gray-800 disabled:opacity-50" :disabled="!draft.trim() || sending || !overview?.configured">Envoyer</button>
              </form>
            </div>
          </li>
        </ul>

        <form class="grid gap-2 sm:grid-cols-[1fr_1fr_auto]" @submit.prevent="addCorrespondent">
          <select v-model="form.contact_id" class="sm:col-span-3 rounded-lg border border-gray-300 px-3 py-1.5 text-sm text-gray-700" aria-label="Fiche contact" @change="fillFromContact">
            <option :value="null">Choisir une fiche contact (facultatif)</option>
            <option v-for="contact in overview?.contacts || []" :key="contact.id" :value="contact.id">{{ contact.label }} ({{ contact.relationship }}){{ contact.phone ? '' : ' - sans numéro' }}</option>
          </select>
          <p class="sm:col-span-3 text-xs text-gray-500">Liée à une fiche, la personne est reconnue par Alfred (ami, copine, famille...) pour adapter son ton. Il n'apprend rien d'autre de la fiche et n'obtient aucun droit de plus.</p>
          <input v-model="form.name" type="text" required placeholder="Nom" class="rounded-lg border border-gray-300 px-3 py-1.5 text-sm" />
          <input v-model="form.phone" type="tel" required placeholder="06 12 34 56 78" class="rounded-lg border border-gray-300 px-3 py-1.5 text-sm" />
          <button type="submit" class="text-sm px-3 py-1.5 rounded-lg bg-black text-white hover:bg-gray-800">Autoriser</button>
          <label class="sm:col-span-3 flex items-center gap-2 text-xs text-gray-600">
            <input v-model="form.owner" type="checkbox" /> C'est mon numéro (mêmes limites que les autres : un numéro peut être usurpé)
          </label>
        </form>
      </section>

      <section class="bg-white rounded-xl shadow-sm p-4 sm:p-5">
        <h2 class="font-semibold text-gray-900 mb-1">Ce qu'Alfred peut dire de moi</h2>
        <p class="text-xs text-gray-500 mb-3">
          Par texto, Alfred ne connaît de vous que ce texte et vos créneaux libres ou occupés (jamais le contenu de l'agenda). Vidé, le texte revient aux valeurs par défaut.
        </p>
        <textarea v-model="facts" rows="5" class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm" />
        <div class="mt-2 flex items-center gap-3">
          <button type="button" class="text-sm px-3 py-1.5 rounded-lg bg-black text-white hover:bg-gray-800 disabled:opacity-50" :disabled="facts === overview?.facts" @click="saveFacts">Enregistrer</button>
          <span v-if="factsSaved" class="text-xs text-green-700">Enregistré.</span>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import apiClient from '../../plugins/axios'
import { useAlfred } from '../../composables/useAlfred'

const route = useRoute()
const { openInPanel } = useAlfred()

const overview = ref(null)
const error = ref(null)
const facts = ref('')
const factsSaved = ref(false)
const form = ref({ name: '', phone: '', owner: false, contact_id: null })
const threadOf = ref(null)
const thread = ref([])
const draft = ref('')
const sending = ref(false)

const messageOf = (err) => err.response?.data?.error || err.response?.data?.errors?.join(', ') || 'Une erreur est survenue.'
const formatDate = (value) => new Date(value).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })

const attempt = async (work) => {
  error.value = null
  try {
    await work()
  } catch (err) {
    error.value = messageOf(err)
  }
}

const load = () => attempt(async () => {
  overview.value = (await apiClient.get('/sms')).data
  facts.value = overview.value.facts
})

// Sans numero sur la fiche, le champ reste a remplir a la main.
const fillFromContact = () => {
  const contact = overview.value.contacts.find((c) => c.id === form.value.contact_id)
  if (!contact) return
  form.value.name = contact.name
  form.value.phone = contact.phone || ''
}

const linkContact = (person, value) => attempt(async () => {
  try {
    await apiClient.patch(`/sms_correspondents/${person.id}`, { sms_correspondent: { contact_id: value || null } })
  } finally {
    await load()
  }
})

const addCorrespondent = () => attempt(async () => {
  await apiClient.post('/sms_correspondents', { sms_correspondent: form.value })
  form.value = { name: '', phone: '', owner: false, contact_id: null }
  await load()
})

const toggleEnabled = (person) => attempt(async () => {
  await apiClient.patch(`/sms_correspondents/${person.id}`, { sms_correspondent: { enabled: !person.enabled } })
  await load()
})

const removeCorrespondent = (person) => attempt(async () => {
  if (!window.confirm(`Retirer ${person.name} et supprimer ses textos ?`)) return
  await apiClient.delete(`/sms_correspondents/${person.id}`)
  if (threadOf.value === person.id) threadOf.value = null
  await load()
})

const toggleThread = (person) => attempt(async () => {
  if (threadOf.value === person.id) {
    threadOf.value = null
    return
  }
  thread.value = (await apiClient.get(`/sms_correspondents/${person.id}/messages`)).data
  threadOf.value = person.id
  draft.value = ''
})

const sendText = async (person) => {
  sending.value = true
  await attempt(async () => {
    thread.value = (await apiClient.post(`/sms_correspondents/${person.id}/send_text`, { body: draft.value })).data
    draft.value = ''
  })
  sending.value = false
}

const saveFacts = () => attempt(async () => {
  overview.value = (await apiClient.patch('/sms', { facts: facts.value })).data
  facts.value = overview.value.facts
  factsSaved.value = true
  window.setTimeout(() => { factsSaved.value = false }, 2000)
})

// Notification d'une demande : le widget s'ouvre sur sa carte de confirmation.
const openRequested = () => {
  const id = route.query.conversation
  if (id) attempt(() => openInPanel(id))
}

watch(() => route.query.conversation, openRequested)
const onActionResolved = () => load()

onMounted(() => {
  load()
  openRequested()
  window.addEventListener('alfred:action-resolved', onActionResolved)
})
onBeforeUnmount(() => window.removeEventListener('alfred:action-resolved', onActionResolved))
</script>
