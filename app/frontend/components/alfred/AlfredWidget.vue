<template>
  <!-- Alfred : bouton flottant + panneau de chat, monte une fois dans App.vue -->
  <div class="fixed bottom-5 right-5 z-50 flex flex-col items-end gap-3 print:hidden">
    <transition
      enter-active-class="transition duration-150 ease-out"
      enter-from-class="opacity-0 translate-y-2"
      leave-active-class="transition duration-100 ease-in"
      leave-to-class="opacity-0 translate-y-2"
    >
      <section
        v-if="isOpen"
        class="w-[26rem] max-w-[calc(100vw-2.5rem)] h-[38rem] max-h-[calc(100vh-7rem)] bg-white rounded-2xl shadow-2xl border border-gray-200 flex flex-col overflow-hidden"
        aria-label="Conversation avec Alfred"
      >
        <!-- En-tete -->
        <header class="flex items-center gap-2 px-3 py-2.5 bg-gray-900 text-white">
          <img :src="avatar" alt="" class="h-9 w-9 rounded-full object-cover ring-2 ring-white/20 flex-shrink-0" />
          <div class="flex-1 min-w-0">
            <h2 class="font-semibold leading-tight">Alfred</h2>
            <p class="text-xs text-gray-400 truncate">{{ subtitle }}</p>
          </div>
          <button type="button" class="header-btn" title="Nouvelle conversation" @click="newConversation">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" d="M12 5v14M5 12h14" /></svg>
          </button>
          <button type="button" class="header-btn" :class="{ 'bg-white/20': view === 'history' }" title="Conversations" @click="toggle('history')">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l2.5 2.5M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </button>
          <!-- Export PDF et vidage : seulement quand une conversation est ouverte -->
          <a v-if="conversation" :href="exportUrl(conversation.id)" class="header-btn" title="Enregistrer en PDF" download>
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v12m0 0l-4-4m4 4l4-4M4 20h16" /></svg>
          </a>
          <button v-if="conversation" type="button" class="header-btn hover:text-red-300" title="Vider la conversation" :disabled="busy" @click="clearConversation">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M4 7h16M10 11v6M14 11v6M6 7l1 12a1 1 0 001 1h8a1 1 0 001-1l1-12M9 7V4h6v3" /></svg>
          </button>
          <button type="button" class="header-btn" title="Page Alfred : instructions, outils, reglages" @click="openSettingsPage">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" d="M4 7h10M18 7h2M4 17h2M10 17h10" /><circle cx="16" cy="7" r="2" /><circle cx="8" cy="17" r="2" /></svg>
          </button>
          <button type="button" class="header-btn" title="Fermer" @click="isOpen = false">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" d="M6 6l12 12M18 6L6 18" /></svg>
          </button>
        </header>

        <!-- Alfred non configure -->
        <div v-if="overview && !overview.available" class="px-4 py-2 text-xs bg-amber-50 text-amber-800 border-b border-amber-100">
          Alfred n'est pas configure : {{ overview.missing_keys.join(', ') }} manquante(s).
        </div>

        <!-- Historique -->
        <div v-if="view === 'history'" class="flex-1 overflow-y-auto p-3">
          <p v-if="!conversations.length" class="text-sm text-gray-400 text-center mt-8">Aucune conversation.</p>
          <div
            v-for="item in conversations"
            :key="item.id"
            class="group flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-gray-50 cursor-pointer"
            @click="openConversation(item.id)"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm text-gray-800 truncate">{{ item.title || 'Conversation sans titre' }}</p>
              <p class="text-xs text-gray-400">{{ formatDateTime(item.last_message_at) }}</p>
            </div>
            <button type="button" class="text-xs text-gray-300 hover:text-red-600 opacity-0 group-hover:opacity-100" @click.stop="remove(item.id)">
              Supprimer
            </button>
          </div>
        </div>

        <!-- Conversation -->
        <template v-else>
          <div ref="scroller" class="flex-1 overflow-y-auto px-4 py-3 space-y-3 bg-gray-50" @click="onContentClick">
            <div v-if="!messages.length" class="text-center mt-8 px-4">
              <img :src="avatar" alt="Alfred" class="mx-auto h-20 w-20 rounded-full object-cover ring-4 ring-white shadow-md mb-3" />
              <p class="text-sm text-gray-600">Bonjour, Monsieur. Que puis-je pour vous ?</p>
              <div class="mt-4 flex flex-col gap-2">
                <button v-for="hint in hints" :key="hint" type="button" class="text-xs text-left text-gray-600 bg-white border border-gray-200 rounded-lg px-3 py-2 hover:border-gray-400" @click="submit(hint)">
                  {{ hint }}
                </button>
              </div>
            </div>

            <template v-for="message in messages" :key="message.id">
              <!-- Sylvain -->
              <div v-if="message.role === 'user'" class="flex justify-end">
                <p class="max-w-[85%] whitespace-pre-wrap rounded-2xl rounded-br-md bg-gray-900 text-white text-sm px-3.5 py-2">{{ message.content }}</p>
              </div>

              <!-- Note systeme : ecriture executee ou annulee -->
              <p v-else-if="message.role === 'event'" class="text-xs text-center text-gray-400 px-6">{{ message.content }}</p>

              <!-- Alfred -->
              <div v-else class="flex items-end gap-2 max-w-[92%]">
                <img :src="avatar" alt="" class="h-7 w-7 rounded-full object-cover ring-1 ring-gray-200 flex-shrink-0 mb-0.5" :class="{ 'animate-pulse': isRunning(message) }" />
                <div class="min-w-0 flex-1">
                  <ul v-if="message.steps.length" class="mb-1 space-y-0.5">
                    <li v-for="(step, index) in message.steps" :key="index" class="text-xs text-gray-400 truncate">{{ step.label }}</li>
                  </ul>

                  <div v-if="message.content" class="rounded-2xl rounded-bl-md bg-white border border-gray-200 text-sm text-gray-800 px-3.5 py-2 break-words" v-html="renderMarkdown(message.content)" />
                  <p v-else-if="isRunning(message)" class="text-sm text-gray-400 italic">Alfred reflechit...</p>

                  <p v-if="message.status === 'failed'" class="mt-1 text-xs text-red-600">{{ message.error || 'La reponse a echoue.' }}</p>

                  <!-- Ecritures proposees : rien n'est ecrit sans le bouton Confirmer -->
                  <div v-for="action in message.actions" :key="action.id" class="mt-2 rounded-xl border bg-white text-sm overflow-hidden" :class="actionBorder(action)">
                    <div class="px-3 py-2 border-b border-gray-100">
                      <p class="text-xs uppercase tracking-wide text-gray-400">
                        {{ operationLabel(action) }} · {{ action.target_model }}<span v-if="action.record_id"> #{{ action.record_id }}</span>
                      </p>
                      <p class="text-gray-800">{{ action.summary }}</p>
                    </div>
                    <dl class="px-3 py-2 space-y-1 text-xs">
                      <div v-for="(value, field) in action.attributes" :key="field" class="flex gap-2">
                        <dt class="w-28 flex-shrink-0 text-gray-400 truncate">{{ field }}</dt>
                        <dd class="min-w-0 break-words whitespace-pre-line">
                          <span v-if="action.operation === 'update'" class="text-gray-400 line-through mr-1">{{ display(action.before[field]) }}</span>
                          <span class="text-gray-900">{{ display(value) }}</span>
                        </dd>
                      </div>
                    </dl>
                    <div v-if="action.status === 'proposed'" class="flex gap-2 px-3 py-2 border-t border-gray-100 bg-gray-50">
                      <button type="button" class="px-3 py-1 rounded-lg bg-gray-900 text-white text-xs hover:bg-gray-700 disabled:opacity-50" :disabled="resolving === action.id" @click="resolve(action, 'confirm')">Confirmer</button>
                      <button type="button" class="px-3 py-1 rounded-lg border border-gray-300 text-xs text-gray-700 hover:bg-white disabled:opacity-50" :disabled="resolving === action.id" @click="resolve(action, 'cancel')">Annuler</button>
                    </div>
                    <p v-else class="px-3 py-2 border-t border-gray-100 text-xs" :class="actionStatusClass(action)">
                      {{ actionStatusLabel(action) }}
                    </p>
                  </div>

                  <!-- Sources citees par Alfred (Alfred::Citations) -->
                  <div v-if="message.sources.length && message.status === 'done'" class="mt-1.5 flex flex-wrap gap-1">
                    <a
                      v-for="source in message.sources.slice(0, 6)"
                      :key="`${source.type}-${source.id}`"
                      :href="source.download || source.page || '#'"
                      :data-internal="source.download ? null : 'true'"
                      :target="source.download ? '_blank' : null"
                      class="text-[11px] text-gray-500 bg-white border border-gray-200 rounded-full px-2 py-0.5 hover:border-gray-400 max-w-[14rem] truncate"
                      :title="`${source.type} #${source.id}`"
                    >{{ source.label }}</a>
                  </div>
                </div>
              </div>
            </template>
          </div>

          <p v-if="error" class="px-4 py-1.5 text-xs text-red-700 bg-red-50 border-t border-red-100">{{ error }}</p>

          <form class="flex items-end gap-2 p-3 border-t border-gray-200 bg-white" @submit.prevent="submit()">
            <textarea
              ref="input"
              v-model="draft"
              rows="1"
              placeholder="Ecrire a Alfred..."
              class="flex-1 resize-none max-h-32 rounded-xl border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-gray-900/20"
              @keydown.enter.exact.prevent="submit()"
              @input="autosize"
            />
            <VoiceInputButton :disabled="busy" @transcribed="insertDictation" />
            <button type="submit" class="h-9 w-9 flex-shrink-0 flex items-center justify-center rounded-xl bg-gray-900 text-white hover:bg-gray-700 disabled:opacity-40" :disabled="busy || !draft.trim()" title="Envoyer">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14M13 6l6 6-6 6" /></svg>
            </button>
          </form>
        </template>
      </section>
    </transition>

    <!-- Bouton flottant : l'avatar d'Alfred, avec une croix quand le panneau est ouvert -->
    <button
      type="button"
      class="relative h-[4.5rem] w-[4.5rem] rounded-full bg-gray-900 shadow-lg ring-4 ring-white hover:scale-105 transition flex items-center justify-center overflow-hidden"
      :title="isOpen ? 'Fermer Alfred' : 'Parler a Alfred'"
      :aria-expanded="isOpen"
      @click="toggleOpen"
    >
      <img :src="avatar" alt="Alfred" class="h-full w-full object-cover" :class="{ 'opacity-40': isOpen }" />
      <svg v-if="isOpen" class="absolute w-7 h-7 text-white drop-shadow" fill="none" stroke="currentColor" stroke-width="2.2" viewBox="0 0 24 24"><path stroke-linecap="round" d="M6 6l12 12M18 6L6 18" /></svg>
    </button>
  </div>
</template>

<script setup>
import { ref, computed, watch, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import { useAlfred } from '../../composables/useAlfred'
import { renderMarkdown } from '../../utils/markdown'
import avatar from '../../images/alfred-avatar.png'
import VoiceInputButton from '../VoiceInputButton.vue'
import { insertAtCursor } from '../../composables/useVoiceRecorder'

const router = useRouter()
const {
  overview, conversation, conversations, messages, busy, error,
  loadOverview, resume, open, startNew, loadConversations, remove, clear, exportUrl, send, resolveAction,
} = useAlfred()

const isOpen = ref(false)
const view = ref('chat') // chat | history
const draft = ref('')
const resolving = ref(null)
const scroller = ref(null)
const input = ref(null)

const hints = [
  'Quels sont mes rendez-vous de la semaine ?',
  'Retrouve mon dernier avis d\'imposition.',
  'Ajoute une tache : renouveler mon passeport.',
]

const subtitle = computed(() => (busy.value ? 'A votre service, un instant...' : 'Votre intendant'))

const isRunning = (message) => ['pending', 'processing'].includes(message.status)

const scrollToBottom = () => nextTick(() => {
  if (scroller.value) scroller.value.scrollTop = scroller.value.scrollHeight
})

const toggleOpen = async () => {
  isOpen.value = !isOpen.value
  if (!isOpen.value) return
  view.value = 'chat'
  await Promise.allSettled([loadOverview(), resume()])
  scrollToBottom()
  nextTick(() => input.value?.focus())
}

const toggle = async (target) => {
  view.value = view.value === target ? 'chat' : target
  if (view.value === 'history') await loadConversations()
  if (view.value === 'chat') scrollToBottom()
}

const newConversation = () => {
  startNew()
  view.value = 'chat'
  nextTick(() => input.value?.focus())
}

// Supprime la conversation courante (rien n'est archive : l'export PDF est la pour ca).
const clearConversation = async () => {
  if (!conversation.value || busy.value) return
  await clear()
  view.value = 'chat'
  nextTick(() => input.value?.focus())
}

// Les reglages vivent sur la page Alfred ; le panneau reste ouvert pour y revenir.
const openSettingsPage = () => {
  router.push('/alfred')
}

const openConversation = async (id) => {
  await open(id)
  view.value = 'chat'
  scrollToBottom()
}

const autosize = () => {
  const el = input.value
  if (!el) return
  el.style.height = 'auto'
  el.style.height = `${el.scrollHeight}px`
}

// Dictee : le texte rejoint le brouillon sans partir, pour relecture avant envoi.
const insertDictation = (text) => {
  draft.value = insertAtCursor(input.value, draft.value, text)
  nextTick(autosize)
}

const submit = async (text) => {
  const content = text ?? draft.value
  if (!content.trim() || busy.value) return
  if (text === undefined) draft.value = ''
  nextTick(autosize)
  const sent = await send(content)
  if (!sent && text === undefined) draft.value = content
}

const resolve = async (action, decision) => {
  resolving.value = action.id
  await resolveAction(action, decision)
  resolving.value = null
}

// Liens internes des reponses (rendus par v-html) : navigation par le routeur,
// sans recharger la page ni fermer la conversation.
const onContentClick = (event) => {
  const link = event.target.closest('a[data-internal]')
  if (!link) return
  event.preventDefault()
  const href = link.getAttribute('href')
  if (href && href !== '#') router.push(href)
}

const display = (value) => {
  if (value === null || value === undefined || value === '') return '(vide)'
  if (typeof value === 'boolean') return value ? 'oui' : 'non'
  if (Array.isArray(value)) return value.map((v) => (typeof v === 'object' ? JSON.stringify(v) : String(v))).join('\n')
  return typeof value === 'object' ? JSON.stringify(value) : String(value)
}

// Ecritures en base (create / update) et actions Gmail, confirmees par la meme carte.
const operationLabel = (action) => ({
  create: 'Creation',
  update: 'Modification',
  send_email: 'Envoi d\'un mail',
  draft_email: 'Brouillon Gmail',
  triage_email: 'Tri de mails',
}[action.operation] || action.operation)

const actionBorder = (action) => ({
  proposed: 'border-indigo-200',
  executed: 'border-green-200',
  cancelled: 'border-gray-200 opacity-70',
  failed: 'border-red-200',
}[action.status])

const actionStatusClass = (action) => ({
  executed: 'text-green-700 bg-green-50',
  cancelled: 'text-gray-500 bg-gray-50',
  failed: 'text-red-700 bg-red-50',
}[action.status])

const actionStatusLabel = (action) => ({
  executed: action.operation === 'send_email' ? 'Confirme et envoye.' : 'Confirme et execute.',
  cancelled: 'Annule, rien n\'a ete fait.',
  failed: `Echec : ${action.error || 'erreur inconnue'}`,
}[action.status])

const formatDateTime = (value) =>
  (value ? new Date(value).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '')

// Suit la reponse pendant qu'elle s'ecrit, sauf si l'on est remonte dans le fil.
watch(
  () => messages.value.map((m) => `${m.id}:${m.content?.length}:${m.steps.length}:${m.actions.length}`).join('|'),
  () => {
    const el = scroller.value
    if (!el || el.scrollHeight - el.scrollTop - el.clientHeight < 160) scrollToBottom()
  },
)
</script>

<style scoped>
.header-btn {
  @apply h-8 w-8 flex items-center justify-center rounded-lg text-gray-300 hover:text-white hover:bg-white/10 transition-colors;
}
</style>
