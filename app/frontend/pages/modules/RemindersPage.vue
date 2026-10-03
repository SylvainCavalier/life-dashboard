<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-3xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Rappels</h1>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouveau rappel
        </button>
      </div>

      <!-- Notifications de cet appareil -->
      <div class="bg-white rounded-xl shadow-sm p-4 sm:p-5 mb-6">
        <div class="flex flex-wrap items-start justify-between gap-3">
          <div class="min-w-0">
            <h2 class="font-semibold text-gray-900">Notifications</h2>
            <p class="text-sm mt-1" :class="deviceStatus.tone">{{ deviceStatus.text }}</p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              v-if="canSubscribe"
              @click="push.subscribe()"
              :disabled="push.busy.value"
              class="bg-indigo-600 text-white text-sm px-3 py-2 rounded-lg hover:bg-indigo-700 disabled:opacity-50"
            >
              Activer sur cet appareil
            </button>
            <button
              v-if="push.server.value.subscriptions.length"
              @click="sendTest"
              :disabled="push.busy.value"
              class="text-sm border border-gray-200 hover:border-gray-300 rounded-lg px-3 py-2 disabled:opacity-50"
            >
              Envoyer un test
            </button>
          </div>
        </div>

        <div v-if="push.needsInstall" class="mt-3 text-sm text-gray-600 bg-amber-50 border border-amber-200 rounded-lg p-3">
          Sur iPhone, les notifications ne fonctionnent que depuis l'application installée : bouton Partager de Safari,
          « Sur l'écran d'accueil », puis ouvrez le Dashboard depuis son icône et revenez ici.
        </div>
        <p v-if="push.error.value" class="mt-3 text-sm text-red-600">{{ push.error.value }}</p>
        <p v-if="testResult" class="mt-3 text-sm text-gray-600">{{ testResult }}</p>

        <ul v-if="push.server.value.subscriptions.length" class="mt-4 divide-y divide-gray-100 border-t border-gray-100">
          <li v-for="device in push.server.value.subscriptions" :key="device.id" class="flex items-center justify-between gap-3 py-2 text-sm">
            <div class="min-w-0">
              <span class="text-gray-800">{{ device.device }}</span>
              <span v-if="device.endpoint === push.endpoint.value" class="ml-2 text-xs bg-indigo-50 text-indigo-700 px-1.5 py-0.5 rounded">cet appareil</span>
              <p v-if="device.last_error" class="text-xs text-red-500 truncate">Échec : {{ device.last_error }}</p>
              <p v-else class="text-xs text-gray-400">
                {{ device.last_success_at ? `Dernière notification : ${formatDateTime(device.last_success_at)}` : `Abonné le ${formatDateTime(device.created_at)}` }}
              </p>
            </div>
            <button @click="push.removeDevice(device)" class="text-xs text-red-400 hover:text-red-600 flex-shrink-0">Retirer</button>
          </li>
        </ul>
        <p class="mt-3 text-xs text-gray-400">
          Sans réponse, une notification est relancée deux fois à 10 minutes d'intervalle{{ push.server.value.email_fallback ? ', puis un mail part.' : '.' }}
          Pensez à autoriser le Dashboard dans vos modes Concentration (Réglages > Concentration > Apps).
        </p>
      </div>

      <!-- Formulaire -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-4 sm:p-6 mb-6">
        <h2 class="text-lg font-semibold mb-4">{{ editingId ? 'Modifier le rappel' : 'Nouveau rappel' }}</h2>
        <div class="mb-4">
          <div class="flex items-center justify-between mb-1">
            <label class="block text-sm font-medium text-gray-700">Me rappeler de *</label>
            <VoiceInputButton size="sm" @transcribed="(text) => (form.title = form.title ? `${form.title} ${text}` : text)" />
          </div>
          <input v-model="form.title" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Appeler le notaire" />
        </div>

        <div class="flex flex-wrap gap-2 mb-3">
          <button
            v-for="preset in presets"
            :key="preset.label"
            type="button"
            @click="applyPreset(preset)"
            class="text-xs border border-gray-200 hover:border-indigo-300 hover:bg-indigo-50 rounded-full px-3 py-1"
          >
            {{ preset.label }}
          </button>
        </div>
        <div class="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Date *</label>
            <input v-model="form.date" type="date" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Heure *</label>
            <input v-model="form.time" type="time" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div class="col-span-2 sm:col-span-1">
            <label class="block text-sm font-medium text-gray-700 mb-1">Répétition</label>
            <select v-model="form.recurrence" class="w-full border rounded-lg px-3 py-2 text-sm bg-white">
              <option v-for="(label, value) in RECURRENCES" :key="value" :value="value">{{ label }}</option>
            </select>
          </div>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Précisions</label>
          <textarea v-model="form.notes" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Affichées dans la notification"></textarea>
        </div>
        <p v-if="formError" class="text-sm text-red-600 mb-3">{{ formError }}</p>
        <div class="flex justify-end gap-2">
          <button @click="showForm = false" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
          <button @click="saveReminder" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
            {{ editingId ? 'Modifier' : 'Ajouter' }}
          </button>
        </div>
      </div>

      <!-- A traiter -->
      <section v-if="dueReminders.length" class="mb-8">
        <h2 class="text-sm font-semibold text-red-600 uppercase tracking-wide mb-3">À traiter ({{ dueReminders.length }})</h2>
        <div class="space-y-3">
          <ReminderCard
            v-for="reminder in dueReminders"
            :key="reminder.id"
            :reminder="reminder"
            :highlighted="reminder.id === highlightedId"
            due
            @done="markDone"
            @snooze="snooze"
            @edit="openForm"
            @remove="removeReminder"
          />
        </div>
      </section>

      <!-- A venir -->
      <section class="mb-8">
        <h2 class="text-sm font-semibold text-gray-500 uppercase tracking-wide mb-3">À venir</h2>
        <p v-if="!upcomingGroups.length" class="text-center text-gray-400 py-8">Aucun rappel programmé</p>
        <div v-for="group in upcomingGroups" :key="group.label" class="mb-5">
          <h3 class="text-xs font-medium text-gray-400 mb-2">{{ group.label }}</h3>
          <div class="space-y-2">
            <ReminderCard
              v-for="reminder in group.items"
              :key="reminder.id"
              :reminder="reminder"
              :highlighted="reminder.id === highlightedId"
              @done="markDone"
              @snooze="snooze"
              @edit="openForm"
              @remove="removeReminder"
            />
          </div>
        </div>
      </section>

      <!-- Termines -->
      <section v-if="completedReminders.length">
        <button @click="showCompleted = !showCompleted" class="text-sm font-semibold text-gray-400 uppercase tracking-wide mb-3">
          Terminés ({{ completedReminders.length }}) {{ showCompleted ? '▾' : '▸' }}
        </button>
        <div v-if="showCompleted" class="space-y-2">
          <div v-for="reminder in completedReminders" :key="reminder.id" class="bg-white rounded-lg px-4 py-2 flex items-center justify-between text-sm">
            <span class="text-gray-400 line-through truncate">{{ reminder.title }}</span>
            <div class="flex gap-3 flex-shrink-0 ml-3">
              <span class="text-xs text-gray-300">{{ formatDateTime(reminder.completed_at) }}</span>
              <button @click="removeReminder(reminder)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import { usePushNotifications, updateAppBadge } from '../../composables/usePushNotifications'
import VoiceInputButton from '../../components/VoiceInputButton.vue'
import ReminderCard from '../../components/reminders/ReminderCard.vue'

const RECURRENCES = {
  none: 'Une seule fois',
  daily: 'Tous les jours',
  weekly: 'Toutes les semaines',
  monthly: 'Tous les mois',
  yearly: 'Tous les ans',
}

const route = useRoute()
const router = useRouter()
const { useCrud, post } = useApi()
const { list, create, update, destroy } = useCrud('reminders')
const push = usePushNotifications()

const reminders = ref([])
const showForm = ref(false)
const showCompleted = ref(false)
const editingId = ref(null)
const formError = ref('')
const highlightedId = ref(null)
const testResult = ref('')
const now = ref(new Date())

// --- Dates : saisie en heure locale, envoyee sans fuseau (Rails l'interprete en heure de Paris)
const pad = (n) => String(n).padStart(2, '0')
const toDateInput = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
const toTimeInput = (d) => `${pad(d.getHours())}:${pad(d.getMinutes())}`
const formatDateTime = (iso) => iso
  ? new Date(iso).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
  : ''

const at = (days, hours, minutes = 0) => {
  const d = new Date()
  d.setDate(d.getDate() + days)
  d.setHours(hours, minutes, 0, 0)
  return d
}
const presets = [
  { label: 'Dans 1 h', at: () => { const d = new Date(Date.now() + 3600e3); d.setMinutes(Math.ceil(d.getMinutes() / 5) * 5, 0, 0); return d } },
  { label: 'Ce soir 19 h', at: () => (at(0, 19) > new Date() ? at(0, 19) : at(1, 19)) },
  { label: 'Demain 9 h', at: () => at(1, 9) },
  { label: 'Lundi 9 h', at: () => at(((8 - new Date().getDay()) % 7) || 7, 9) },
]
const applyPreset = (preset) => {
  const d = preset.at()
  form.value.date = toDateInput(d)
  form.value.time = toTimeInput(d)
}

const defaultForm = () => {
  const d = presets[0].at()
  return { title: '', notes: '', date: toDateInput(d), time: toTimeInput(d), recurrence: 'none' }
}
const form = ref(defaultForm())

// --- Listes
const active = computed(() => reminders.value.filter((r) => !r.completed_at))
const dueReminders = computed(() => active.value.filter((r) => new Date(r.remind_at) <= now.value))
const completedReminders = computed(() => reminders.value.filter((r) => r.completed_at))

const dayLabel = (d) => {
  const day = toDateInput(d)
  if (day === toDateInput(new Date())) return "Aujourd'hui"
  if (day === toDateInput(at(1, 0))) return 'Demain'
  const label = d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' })
  return label.charAt(0).toUpperCase() + label.slice(1)
}
const upcomingGroups = computed(() => {
  const groups = []
  active.value
    .filter((r) => new Date(r.remind_at) > now.value)
    .forEach((r) => {
      const label = dayLabel(new Date(r.remind_at))
      const group = groups.find((g) => g.label === label)
      group ? group.items.push(r) : groups.push({ label, items: [r] })
    })
  return groups
})

const fetchReminders = async () => {
  reminders.value = await list()
  now.value = new Date()
  updateAppBadge(dueReminders.value.length)
}

// --- Formulaire
const openForm = (reminder = null) => {
  formError.value = ''
  if (reminder) {
    const d = new Date(reminder.remind_at)
    editingId.value = reminder.id
    form.value = { title: reminder.title, notes: reminder.notes || '', date: toDateInput(d), time: toTimeInput(d), recurrence: reminder.recurrence }
  } else {
    editingId.value = null
    form.value = defaultForm()
  }
  showForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

const saveReminder = async () => {
  formError.value = ''
  if (!form.value.title.trim() || !form.value.date || !form.value.time) {
    formError.value = 'Le libellé, la date et l’heure sont obligatoires.'
    return
  }
  const payload = {
    reminder: {
      title: form.value.title.trim(),
      notes: form.value.notes,
      recurrence: form.value.recurrence,
      remind_at: `${form.value.date}T${form.value.time}`,
    },
  }
  try {
    editingId.value ? await update(editingId.value, payload) : await create(payload)
    showForm.value = false
    await fetchReminders()
  } catch (e) {
    formError.value = e.response?.data?.errors?.join(', ') || 'Enregistrement impossible'
  }
}

// --- Actions
const markDone = async (reminder) => {
  await post(`/reminders/${reminder.id}/done`)
  await fetchReminders()
}

// `target` : nombre de minutes, ou 'tomorrow' (demain 9 h)
const snooze = async (reminder, target) => {
  const body = target === 'tomorrow' ? { until: `${toDateInput(at(1, 9))}T09:00` } : { minutes: target }
  await post(`/reminders/${reminder.id}/snooze`, body)
  await fetchReminders()
}

const removeReminder = async (reminder) => {
  if (!confirm(`Supprimer le rappel « ${reminder.title} » ?`)) return
  await destroy(reminder.id)
  await fetchReminders()
}

const sendTest = async () => {
  testResult.value = ''
  const result = await push.sendTest()
  if (result) testResult.value = `Notification envoyée à ${result.reached} appareil(s) sur ${result.total}.`
}

// --- Notifications de cet appareil
const canSubscribe = computed(() => push.supported && push.server.value.configured && !push.subscribed.value && push.permission.value !== 'denied')
const deviceStatus = computed(() => {
  if (!push.server.value.configured) return { tone: 'text-amber-600', text: 'Le serveur n’a pas encore de clés VAPID : les notifications push sont désactivées.' }
  if (push.needsInstall) return { tone: 'text-amber-600', text: 'Cet iPhone ne peut pas recevoir de notifications depuis Safari.' }
  if (!push.supported) return { tone: 'text-gray-500', text: 'Ce navigateur ne gère pas les notifications push.' }
  if (push.permission.value === 'denied') return { tone: 'text-red-600', text: 'Notifications bloquées pour le Dashboard dans les réglages de cet appareil.' }
  if (push.subscribed.value) return { tone: 'text-green-700', text: 'Cet appareil reçoit les rappels.' }
  return { tone: 'text-gray-500', text: 'Cet appareil ne reçoit pas encore les rappels.' }
})

// --- Arrivee depuis une notification : /reminders?open=ID[&do=done|snooze]
const handleNotificationQuery = async () => {
  const id = Number(route.query.open)
  if (!id) return
  const action = route.query.do
  router.replace({ query: {} })
  highlightedId.value = id
  try {
    if (action === 'done') await post(`/reminders/${id}/done`)
    else if (action === 'snooze') await post(`/reminders/${id}/snooze`, { minutes: 10 })
    else await post(`/reminders/${id}/seen`)
  } catch {
    // Rappel supprime entre-temps : rien a faire.
  }
  await fetchReminders()
  await nextTick()
  document.getElementById(`reminder-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
}
watch(() => route.query.open, handleNotificationQuery)

// Les rappels echus basculent dans « A traiter » sans recharger la page.
let timer = null
const onVisible = () => { if (document.visibilityState === 'visible') fetchReminders() }

onMounted(async () => {
  await fetchReminders()
  await handleNotificationQuery()
  timer = setInterval(fetchReminders, 60_000)
  document.addEventListener('visibilitychange', onVisible)
  push.refresh().catch(() => {})
})

onBeforeUnmount(() => {
  clearInterval(timer)
  document.removeEventListener('visibilitychange', onVisible)
})
</script>
