<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Bandeau alertes -->
      <div v-if="urgentEvents.length > 0" class="mb-4 space-y-2">
        <div
          v-for="event in urgentEvents"
          :key="'alert-' + event.id"
          :class="[
            'flex items-center gap-3 px-4 py-3 rounded-lg text-sm font-medium',
            isWithin1h(event) ? 'bg-red-100 text-red-800 animate-pulse' : 'bg-amber-100 text-amber-800'
          ]"
        >
          <span class="text-lg">{{ isWithin1h(event) ? '🔴' : '🟡' }}</span>
          <span class="font-semibold">{{ event.title }}</span>
          <span class="text-xs opacity-75">— {{ formatRelativeTime(event.start_time) }}</span>
          <span v-if="event.location" class="text-xs opacity-60 ml-auto">{{ event.location }}</span>
        </div>
      </div>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Agenda</h1>
        <div class="flex items-center gap-3">
          <!-- Toggle vue -->
          <div class="flex bg-gray-200 rounded-lg p-0.5">
            <button
              @click="viewMode = 'calendar'"
              :class="['text-sm px-3 py-1.5 rounded-md transition', viewMode === 'calendar' ? 'bg-white shadow-sm font-medium' : 'text-gray-500']"
            >Calendrier</button>
            <button
              @click="viewMode = 'list'"
              :class="['text-sm px-3 py-1.5 rounded-md transition', viewMode === 'list' ? 'bg-white shadow-sm font-medium' : 'text-gray-500']"
            >Liste</button>
          </div>
          <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
            + Nouvel événement
          </button>
        </div>
      </div>

      <!-- Formulaire -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <h2 class="text-lg font-semibold mb-4">{{ editingId ? 'Modifier l\'événement' : 'Nouvel événement' }}</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Titre *</label>
            <input v-model="form.title" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Titre de l'événement" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Type *</label>
            <select v-model="form.event_type" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option v-for="t in eventTypes" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Début *</label>
            <input v-model="form.start_time" type="datetime-local" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Fin</label>
            <input v-model="form.end_time" type="datetime-local" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Lieu</label>
            <input v-model="form.location" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Adresse ou lien visio" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Rappel</label>
            <select v-model="form.reminder_minutes" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option :value="0">Pas de rappel</option>
              <option :value="5">5 minutes avant</option>
              <option :value="15">15 minutes avant</option>
              <option :value="30">30 minutes avant</option>
              <option :value="60">1 heure avant</option>
              <option :value="1440">1 jour avant</option>
            </select>
          </div>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
          <textarea v-model="form.description" rows="3" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Notes ou détails..."></textarea>
        </div>
        <div class="flex items-center justify-between">
          <label class="flex items-center gap-2 cursor-pointer select-none">
            <input v-model="form.all_day" type="checkbox" class="rounded" />
            <span class="text-sm text-gray-700">Journée entière</span>
          </label>
          <div class="flex gap-2">
            <button @click="showForm = false" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
            <button @click="saveEvent" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
              {{ editingId ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Lien ICS -->
      <div class="mb-6 flex items-center gap-2">
        <button @click="copyIcsLink" class="text-xs text-indigo-500 hover:text-indigo-700 flex items-center gap-1">
          <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
          </svg>
          Copier le lien ICS (pour synchroniser avec iPhone)
        </button>
        <span v-if="icsCopied" class="text-xs text-green-600">Copié !</span>
      </div>

      <!-- === VUE CALENDRIER === -->
      <div v-if="viewMode === 'calendar'">
        <!-- Navigation mois -->
        <div class="flex items-center justify-between mb-4">
          <button @click="prevMonth" class="text-gray-500 hover:text-gray-700 p-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <h2 class="text-lg font-semibold text-gray-900 capitalize">{{ monthLabel }}</h2>
          <button @click="nextMonth" class="text-gray-500 hover:text-gray-700 p-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        <!-- Grille calendrier -->
        <div class="bg-white rounded-xl shadow-sm overflow-hidden">
          <!-- Jours de la semaine -->
          <div class="grid grid-cols-7 border-b">
            <div v-for="day in weekDays" :key="day" class="text-center text-xs font-medium text-gray-500 py-2">
              {{ day }}
            </div>
          </div>
          <!-- Cellules -->
          <div class="grid grid-cols-7">
            <div
              v-for="(cell, idx) in calendarCells"
              :key="idx"
              :class="[
                'min-h-[80px] border-b border-r p-1 cursor-pointer hover:bg-gray-50 transition',
                cell.isCurrentMonth ? '' : 'bg-gray-50',
                cell.isToday ? 'bg-indigo-50' : ''
              ]"
              @click="onDayClick(cell)"
            >
              <div class="flex items-start justify-between">
                <span :class="[
                  'text-xs font-medium w-6 h-6 flex items-center justify-center rounded-full',
                  cell.isToday ? 'bg-indigo-600 text-white' : cell.isCurrentMonth ? 'text-gray-700' : 'text-gray-400'
                ]">
                  {{ cell.day }}
                </span>
              </div>
              <div class="mt-0.5 space-y-0.5">
                <div
                  v-for="ev in cell.events.slice(0, 3)"
                  :key="ev.id"
                  @click.stop="openForm(ev)"
                  :class="['text-xs truncate rounded px-1 py-0.5 cursor-pointer hover:opacity-80']"
                  :style="{ backgroundColor: getEventColor(ev) + '20', color: getEventColor(ev) }"
                >
                  {{ ev.all_day ? '' : formatTime(ev.start_time) + ' ' }}{{ ev.title }}
                </div>
                <div v-if="cell.events.length > 3" class="text-xs text-gray-400 px-1">
                  +{{ cell.events.length - 3 }} autre{{ cell.events.length - 3 > 1 ? 's' : '' }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- === VUE LISTE === -->
      <div v-if="viewMode === 'list'">
        <!-- Filtres -->
        <div class="flex gap-2 mb-4 flex-wrap">
          <button
            @click="filterType = ''"
            :class="['text-xs px-3 py-1.5 rounded-full transition', filterType === '' ? 'bg-gray-900 text-white' : 'bg-gray-200 text-gray-600 hover:bg-gray-300']"
          >Tous</button>
          <button
            v-for="t in eventTypes"
            :key="t.value"
            @click="filterType = t.value"
            :class="['text-xs px-3 py-1.5 rounded-full transition', filterType === t.value ? 'bg-gray-900 text-white' : 'bg-gray-200 text-gray-600 hover:bg-gray-300']"
          >{{ t.label }}</button>
        </div>

        <div v-if="filteredEvents.length === 0" class="text-center text-gray-400 py-12">
          Aucun événement
        </div>

        <!-- Groupé par date -->
        <div v-for="(group, date) in groupedEvents" :key="date" class="mb-6">
          <h3 class="text-sm font-semibold text-gray-500 mb-2 uppercase">{{ formatGroupDate(date) }}</h3>
          <div class="space-y-2">
            <div
              v-for="event in group"
              :key="event.id"
              class="bg-white rounded-xl shadow-sm p-4 flex items-center gap-4 hover:shadow-md transition"
            >
              <!-- Barre couleur -->
              <div class="w-1 h-12 rounded-full flex-shrink-0" :style="{ backgroundColor: getEventColor(event) }"></div>
              <!-- Heure -->
              <div class="w-16 flex-shrink-0 text-center">
                <span v-if="event.all_day" class="text-xs font-medium text-gray-500">Journée</span>
                <template v-else>
                  <div class="text-sm font-semibold text-gray-900">{{ formatTime(event.start_time) }}</div>
                  <div v-if="event.end_time" class="text-xs text-gray-400">{{ formatTime(event.end_time) }}</div>
                </template>
              </div>
              <!-- Contenu -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2">
                  <h4 class="font-medium text-gray-900 truncate">{{ event.title }}</h4>
                  <span
                    class="text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0"
                    :style="{ backgroundColor: getEventColor(event) + '20', color: getEventColor(event) }"
                  >{{ eventTypeLabel(event.event_type) }}</span>
                </div>
                <p v-if="event.location" class="text-xs text-gray-400 mt-0.5 truncate">{{ event.location }}</p>
              </div>
              <!-- Actions -->
              <div class="flex gap-2 flex-shrink-0">
                <button @click="openForm(event)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
                <button @click="deleteEvent(event.id)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud, get } = useApi()
const { list, create, update, destroy } = useCrud('events')

const events = ref([])
const showForm = ref(false)
const editingId = ref(null)
const viewMode = ref('calendar')
const filterType = ref('')
const icsCopied = ref(false)

// Calendrier
const currentMonth = ref(new Date().getMonth())
const currentYear = ref(new Date().getFullYear())

const eventTypes = [
  { value: 'rdv', label: 'Rendez-vous' },
  { value: 'visio', label: 'Visioconférence' },
  { value: 'lecon', label: 'Leçon' },
  { value: 'reunion', label: 'Réunion' },
  { value: 'autre', label: 'Autre' },
]

const eventTypeColors = {
  rdv: '#6366f1',
  visio: '#8b5cf6',
  lecon: '#06b6d4',
  reunion: '#f59e0b',
  autre: '#64748b',
}

const weekDays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']

const defaultForm = () => ({
  title: '',
  description: '',
  event_type: 'rdv',
  start_time: '',
  end_time: '',
  location: '',
  all_day: false,
  reminder_minutes: 60,
})

const form = ref(defaultForm())

// === Alertes ===
const urgentEvents = ref([])
let alertInterval = null

const fetchAlerts = async () => {
  try {
    urgentEvents.value = await get('/events/upcoming')
  } catch {
    urgentEvents.value = []
  }
}

const isWithin1h = (event) => {
  const diff = new Date(event.start_time) - new Date()
  return diff > 0 && diff <= 3600000
}

const formatRelativeTime = (dateStr) => {
  const diff = new Date(dateStr) - new Date()
  if (diff <= 0) return "maintenant"
  const minutes = Math.floor(diff / 60000)
  if (minutes < 60) return `dans ${minutes} min`
  const hours = Math.floor(minutes / 60)
  return `dans ${hours}h${minutes % 60 > 0 ? String(minutes % 60).padStart(2, '0') : ''}`
}

// === Calendrier ===
const monthLabel = computed(() => {
  return new Date(currentYear.value, currentMonth.value).toLocaleDateString('fr-FR', { month: 'long', year: 'numeric' })
})

const calendarCells = computed(() => {
  const firstDay = new Date(currentYear.value, currentMonth.value, 1)
  const lastDay = new Date(currentYear.value, currentMonth.value + 1, 0)
  // Lundi = 0, Dimanche = 6
  let startOffset = firstDay.getDay() - 1
  if (startOffset < 0) startOffset = 6

  const cells = []
  const today = new Date()
  const todayStr = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`

  // Jours du mois précédent
  const prevLastDay = new Date(currentYear.value, currentMonth.value, 0)
  for (let i = startOffset - 1; i >= 0; i--) {
    const d = prevLastDay.getDate() - i
    const dateStr = formatDateKey(new Date(currentYear.value, currentMonth.value - 1, d))
    cells.push({ day: d, isCurrentMonth: false, isToday: false, date: dateStr, events: getEventsForDate(dateStr) })
  }

  // Jours du mois actuel
  for (let d = 1; d <= lastDay.getDate(); d++) {
    const dateStr = formatDateKey(new Date(currentYear.value, currentMonth.value, d))
    cells.push({ day: d, isCurrentMonth: true, isToday: dateStr === todayStr, date: dateStr, events: getEventsForDate(dateStr) })
  }

  // Compléter la dernière semaine
  const remaining = 7 - (cells.length % 7)
  if (remaining < 7) {
    for (let d = 1; d <= remaining; d++) {
      const dateStr = formatDateKey(new Date(currentYear.value, currentMonth.value + 1, d))
      cells.push({ day: d, isCurrentMonth: false, isToday: false, date: dateStr, events: getEventsForDate(dateStr) })
    }
  }

  return cells
})

const prevMonth = () => {
  if (currentMonth.value === 0) {
    currentMonth.value = 11
    currentYear.value--
  } else {
    currentMonth.value--
  }
}

const nextMonth = () => {
  if (currentMonth.value === 11) {
    currentMonth.value = 0
    currentYear.value++
  } else {
    currentMonth.value++
  }
}

const onDayClick = (cell) => {
  const f = defaultForm()
  f.start_time = cell.date + 'T09:00'
  f.end_time = cell.date + 'T10:00'
  form.value = f
  editingId.value = null
  showForm.value = true
}

// === Liste ===
const filteredEvents = computed(() => {
  let result = events.value
  if (filterType.value) {
    result = result.filter(e => e.event_type === filterType.value)
  }
  return result
})

const groupedEvents = computed(() => {
  const groups = {}
  filteredEvents.value.forEach(e => {
    const dateKey = formatDateKey(new Date(e.start_time))
    if (!groups[dateKey]) groups[dateKey] = []
    groups[dateKey].push(e)
  })
  return groups
})

// === CRUD ===
const fetchEvents = async () => {
  events.value = await list()
}

const openForm = (event = null) => {
  if (event) {
    editingId.value = event.id
    form.value = {
      title: event.title,
      description: event.description || '',
      event_type: event.event_type,
      start_time: toLocalDatetime(event.start_time),
      end_time: event.end_time ? toLocalDatetime(event.end_time) : '',
      location: event.location || '',
      all_day: event.all_day,
      reminder_minutes: event.reminder_minutes ?? 60,
    }
  } else {
    editingId.value = null
    form.value = defaultForm()
  }
  showForm.value = true
}

const saveEvent = async () => {
  if (!form.value.title.trim() || !form.value.start_time) return
  const payload = { event: { ...form.value } }
  if (!payload.event.end_time) delete payload.event.end_time
  if (editingId.value) {
    await update(editingId.value, payload)
  } else {
    await create(payload)
  }
  showForm.value = false
  await fetchEvents()
  await fetchAlerts()
}

const deleteEvent = async (id) => {
  if (!confirm('Supprimer cet événement ?')) return
  await destroy(id)
  await fetchEvents()
  await fetchAlerts()
}

// === Helpers ===
const getEventColor = (event) => eventTypeColors[event.event_type] || '#64748b'

const eventTypeLabel = (type) => {
  const found = eventTypes.find(t => t.value === type)
  return found ? found.label : type
}

const formatDateKey = (date) => {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
}

const getEventsForDate = (dateStr) => {
  return events.value.filter(e => {
    const eventDate = formatDateKey(new Date(e.start_time))
    return eventDate === dateStr
  })
}

const formatTime = (dateStr) => {
  return new Date(dateStr).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
}

const formatGroupDate = (dateStr) => {
  const date = new Date(dateStr + 'T00:00:00')
  const today = new Date()
  const tomorrow = new Date(today)
  tomorrow.setDate(tomorrow.getDate() + 1)

  if (formatDateKey(date) === formatDateKey(today)) return "Aujourd'hui"
  if (formatDateKey(date) === formatDateKey(tomorrow)) return 'Demain'
  return date.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })
}

const toLocalDatetime = (dateStr) => {
  const d = new Date(dateStr)
  const offset = d.getTimezoneOffset()
  const local = new Date(d.getTime() - offset * 60000)
  return local.toISOString().slice(0, 16)
}

const copyIcsLink = async () => {
  const url = `${window.location.origin}/api/calendar.ics`
  try {
    await navigator.clipboard.writeText(url)
    icsCopied.value = true
    setTimeout(() => { icsCopied.value = false }, 2000)
  } catch {
    prompt('Copiez ce lien pour vous abonner :', url)
  }
}

// === Lifecycle ===
onMounted(async () => {
  await fetchEvents()
  await fetchAlerts()
  alertInterval = setInterval(fetchAlerts, 60000)
})

onUnmounted(() => {
  if (alertInterval) clearInterval(alertInterval)
})
</script>
