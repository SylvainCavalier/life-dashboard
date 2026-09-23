<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-4xl mx-auto">
      <router-link to="/meetings" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Toutes les reunions</router-link>

      <div v-if="notFound" class="text-center text-gray-400 py-12">Reunion introuvable</div>

      <template v-else-if="meeting">
        <!-- En-tete -->
        <div class="bg-white rounded-xl shadow-sm p-6 mb-6">
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <h1 class="text-2xl font-bold text-gray-900">{{ meeting.title }}</h1>
              <p class="text-sm text-gray-500 mt-1">
                {{ formatDateTime(meeting.held_at) }} · {{ meeting.kind === 'visio' ? 'Visio' : 'Presentiel' }}
                <span v-if="meeting.duration_seconds"> · {{ formatDuration(meeting.duration_seconds) }}</span>
              </p>
              <p v-if="meeting.participants" class="text-sm text-gray-500">Participants : {{ meeting.participants }}</p>
            </div>
            <span :class="['flex-shrink-0 text-xs px-2 py-0.5 rounded-full', statusClass(meeting)]">{{ statusLabel(meeting) }}</span>
          </div>

          <!-- Progression -->
          <ol v-if="meeting.in_progress" class="flex flex-wrap gap-2 mt-4 text-xs">
            <li
              v-for="(label, key) in STEP_LABELS"
              :key="key"
              :class="['px-2 py-1 rounded-lg', stepState(key) === 'current' ? 'bg-blue-600 text-white' : stepState(key) === 'done' ? 'bg-blue-50 text-blue-700' : 'bg-gray-100 text-gray-400']"
            >
              {{ label }}
            </li>
          </ol>
          <p v-if="meeting.in_progress" class="text-xs text-gray-400 mt-2">
            Comptez environ une minute par heure d'enregistrement. Vous pouvez quitter la page, le traitement continue.
          </p>

          <!-- Enregistrement en direct en cours sur un autre appareil, ou interrompu -->
          <div v-if="meeting.status === 'recording'" class="mt-4 bg-red-50 border border-red-100 rounded-lg p-3">
            <p class="text-sm text-red-800">
              Enregistrement en cours ou interrompu : {{ meeting.recording?.chunks || 0 }} morceau(x) de 30 s recu(s)
              (environ {{ formatDuration((meeting.recording?.chunks || 0) * 30) || '0 min' }}).
            </p>
            <div class="flex flex-wrap gap-2 mt-3">
              <router-link :to="`/meetings/record?resume=${meeting.id}`" class="bg-white border text-sm px-3 py-1.5 rounded-lg hover:bg-gray-50">
                Reprendre l'enregistrement
              </router-link>
              <button
                class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800 disabled:opacity-40"
                :disabled="busy || !meeting.recording?.chunks"
                @click="finishRecording"
              >
                Terminer et transcrire
              </button>
            </div>
          </div>

          <div v-if="meeting.status === 'failed'" class="mt-4 bg-red-50 border border-red-100 rounded-lg p-3">
            <p class="text-sm text-red-700">{{ meeting.error }}</p>
          </div>
          <p v-if="actionError" class="text-sm text-red-600 mt-3">{{ actionError }}</p>

          <div class="flex flex-wrap gap-2 mt-4">
            <a
              v-if="meeting.document?.download_url"
              :href="meeting.document.download_url"
              target="_blank"
              rel="noopener"
              class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition"
            >
              Compte rendu PDF
            </a>
            <button
              v-if="meeting.status === 'failed' || meeting.stuck"
              class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition"
              :disabled="busy"
              @click="regenerate"
            >
              Relancer le traitement
            </button>
            <button v-if="!meeting.in_progress" class="text-sm px-4 py-2 rounded-lg border hover:bg-gray-50" @click="toggleEdit">
              {{ editing ? 'Fermer' : 'Modifier les infos' }}
            </button>
            <button v-if="!meeting.in_progress" class="text-sm text-red-500 hover:text-red-700 px-2 py-2" @click="remove">Supprimer</button>
          </div>

          <!-- Edition des metadonnees -->
          <form v-if="editing" class="mt-4 grid grid-cols-1 md:grid-cols-2 gap-3 border-t pt-4" @submit.prevent="saveInfos">
            <div class="md:col-span-2">
              <label class="block text-xs font-medium text-gray-600 mb-1">Titre</label>
              <input v-model="infos.title" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div class="md:col-span-2">
              <label class="block text-xs font-medium text-gray-600 mb-1">Participants</label>
              <input v-model="infos.participants" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div class="md:col-span-2">
              <label class="block text-xs font-medium text-gray-600 mb-1">Contexte</label>
              <textarea v-model="infos.context" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm"></textarea>
            </div>
            <div class="md:col-span-2 flex justify-end">
              <button type="submit" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition" :disabled="busy">Enregistrer</button>
            </div>
          </form>
        </div>

        <!-- Intervenants -->
        <div v-if="meeting.speakers?.length && !meeting.in_progress" class="bg-white rounded-xl shadow-sm p-6 mb-6">
          <h2 class="text-lg font-semibold mb-1">Intervenants</h2>
          <p class="text-xs text-gray-500 mb-4">
            Les voix sont distinguees automatiquement. Nommez-les puis regenerez : la synthese et le PDF seront refaits avec ces noms,
            sans repayer la transcription.
          </p>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-4">
            <label v-for="speaker in meeting.speakers" :key="speaker.id" class="flex items-center gap-2">
              <span :class="['w-2.5 h-2.5 rounded-full flex-shrink-0', speakerColor(speaker.id)]"></span>
              <span class="text-xs text-gray-400 w-24 flex-shrink-0">{{ defaultLabel(speaker.id) }}</span>
              <input v-model="names[speaker.id]" type="text" class="flex-1 min-w-0 border rounded-lg px-3 py-1.5 text-sm" placeholder="Nom" />
            </label>
          </div>
          <div class="flex justify-end">
            <button class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40" :disabled="busy" @click="saveNamesAndRegenerate">
              Enregistrer et regenerer la synthese
            </button>
          </div>
        </div>

        <!-- Synthese -->
        <div v-if="summary" class="bg-white rounded-xl shadow-sm p-6 mb-6">
          <h2 class="text-lg font-semibold mb-3">Synthese</h2>
          <p v-for="(paragraph, i) in paragraphs(summary.overview)" :key="i" class="text-sm text-gray-700 mb-3 whitespace-pre-line">{{ paragraph }}</p>

          <template v-for="section in listSections" :key="section.key">
            <div v-if="summary[section.key]?.length" class="mt-4">
              <h3 class="text-sm font-semibold text-gray-900 mb-1">{{ section.label }}</h3>
              <ul class="list-disc pl-5 space-y-1">
                <li v-for="(item, i) in summary[section.key]" :key="i" class="text-sm text-gray-700">{{ item }}</li>
              </ul>
            </div>
          </template>

          <div v-if="summary.action_items?.length" class="mt-4">
            <h3 class="text-sm font-semibold text-gray-900 mb-2">Actions a mener</h3>
            <ul class="space-y-2">
              <li v-for="(item, i) in summary.action_items" :key="i" class="flex items-start justify-between gap-3 text-sm">
                <div class="text-gray-700">
                  {{ item.description }}
                  <span class="text-xs text-gray-400">
                    <template v-if="item.owner"> · {{ item.owner }}</template>
                    <template v-if="item.due_date"> · pour le {{ formatDate(item.due_date) }}</template>
                  </span>
                </div>
                <button
                  class="flex-shrink-0 text-xs px-2 py-1 rounded-lg border hover:bg-gray-50 disabled:opacity-50"
                  :disabled="addedTasks.has(i)"
                  :title="addedTasks.has(i) ? 'Ajoutee a la to-do list' : 'Ajouter a la to-do list du dashboard'"
                  @click="addTask(item, i)"
                >
                  {{ addedTasks.has(i) ? 'Ajoutee' : '+ To-do' }}
                </button>
              </li>
            </ul>
          </div>
          <p v-if="meeting.summary_model" class="text-xs text-gray-300 mt-4">Synthese : {{ meeting.summary_model }}</p>
        </div>

        <!-- Transcription -->
        <div v-if="meeting.turns?.length" class="bg-white rounded-xl shadow-sm p-6">
          <div class="flex items-center justify-between gap-3 mb-4">
            <h2 class="text-lg font-semibold">Transcription</h2>
            <input v-model="search" type="text" placeholder="Rechercher..." class="border rounded-lg px-3 py-1.5 text-sm w-40 sm:w-56" />
          </div>
          <div class="space-y-3">
            <div v-for="(turn, i) in filteredTurns" :key="i" class="flex gap-3">
              <span :class="['mt-1.5 w-2.5 h-2.5 rounded-full flex-shrink-0', speakerColor(turn.speaker)]"></span>
              <div class="min-w-0">
                <p class="text-xs">
                  <span class="font-semibold text-gray-900">{{ labelOf(turn.speaker) }}</span>
                  <span class="text-gray-400 ml-2 tabular-nums">{{ timecode(turn.start) }}</span>
                </p>
                <p class="text-sm text-gray-700">{{ turn.text }}</p>
              </div>
            </div>
          </div>
        </div>
        <p v-else-if="meeting.status === 'done'" class="text-center text-gray-400 py-6">Aucune parole detectee dans l'enregistrement.</p>
      </template>
    </div>
  </div>
</template>

<script setup>
// Une reunion : suivi du traitement (sonde toutes les 3 s tant qu'il tourne), synthese,
// intervenants a nommer, transcription. apiClient direct : passer par le store `api`
// ferait clignoter l'etat de chargement global a chaque sondage.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import apiClient from '../../plugins/axios'
import { STEP_LABELS, formatDateTime, formatDuration, timecode, statusClass, statusLabel } from '../../utils/meetingFormat'

const props = defineProps({ id: { type: [String, Number], required: true } })

const POLL_INTERVAL = 3000
const RECORDING_POLL_INTERVAL = 10000
const COLORS = ['bg-blue-500', 'bg-emerald-500', 'bg-amber-500', 'bg-rose-500', 'bg-violet-500', 'bg-cyan-500', 'bg-lime-500', 'bg-orange-500']
const listSections = [
  { key: 'key_points', label: 'Points cles' },
  { key: 'decisions', label: 'Decisions' },
  { key: 'open_questions', label: 'Questions ouvertes' },
]

const router = useRouter()
const meeting = ref(null)
const notFound = ref(false)
const busy = ref(false)
const actionError = ref(null)
const editing = ref(false)
const infos = ref({})
const names = ref({})
const search = ref('')
const addedTasks = ref(new Set())
let timer = null

const summary = computed(() => (meeting.value?.summary && Object.keys(meeting.value.summary).length ? meeting.value.summary : null))

const filteredTurns = computed(() => {
  const turns = meeting.value?.turns || []
  const q = search.value.trim().toLowerCase()
  if (!q) return turns
  return turns.filter((t) => t.text.toLowerCase().includes(q) || labelOf(t.speaker).toLowerCase().includes(q))
})

const apply = (data) => {
  const wasRunning = meeting.value?.in_progress
  meeting.value = data
  // Les noms saisis ne sont pas ecrases par le sondage, sauf quand le traitement se termine
  // (la synthese a pu en deviner de nouveaux).
  if (!Object.keys(names.value).length || (wasRunning && !data.in_progress)) {
    names.value = Object.fromEntries((data.speakers || []).map((s) => [s.id, s.name || '']))
  }
  clearTimeout(timer)
  // Traitement : sondage rapide. Enregistrement en cours sur un autre appareil : plus lent.
  if (data.in_progress) timer = setTimeout(fetchMeeting, POLL_INTERVAL)
  else if (data.status === 'recording') timer = setTimeout(fetchMeeting, RECORDING_POLL_INTERVAL)
}

const fetchMeeting = async () => {
  try {
    const { data } = await apiClient.get(`/meetings/${props.id}`)
    apply(data)
  } catch (e) {
    if (e?.response?.status === 404) notFound.value = true
  }
}

const errorOf = (e) => e?.response?.data?.errors?.join(', ') || 'Operation impossible.'

const regenerate = async () => {
  busy.value = true
  actionError.value = null
  try {
    const { data } = await apiClient.post(`/meetings/${props.id}/regenerate`)
    apply(data)
  } catch (e) {
    actionError.value = errorOf(e)
  } finally {
    busy.value = false
  }
}

const finishRecording = async () => {
  if (!confirm('Terminer cet enregistrement et lancer la transcription ?')) return
  busy.value = true
  actionError.value = null
  try {
    const { data } = await apiClient.post(`/meetings/${props.id}/finish`)
    apply(data)
  } catch (e) {
    actionError.value = errorOf(e)
  } finally {
    busy.value = false
  }
}

const saveNamesAndRegenerate = async () => {
  busy.value = true
  actionError.value = null
  try {
    await apiClient.patch(`/meetings/${props.id}`, { meeting: { speaker_names: names.value } })
    const { data } = await apiClient.post(`/meetings/${props.id}/regenerate`)
    apply(data)
  } catch (e) {
    actionError.value = errorOf(e)
  } finally {
    busy.value = false
  }
}

const toggleEdit = () => {
  editing.value = !editing.value
  if (editing.value) {
    const { title, participants, context } = meeting.value
    infos.value = { title, participants: participants || '', context: context || '' }
  }
}

const saveInfos = async () => {
  busy.value = true
  actionError.value = null
  try {
    const { data } = await apiClient.patch(`/meetings/${props.id}`, { meeting: infos.value })
    apply(data)
    editing.value = false
  } catch (e) {
    actionError.value = errorOf(e)
  } finally {
    busy.value = false
  }
}

const remove = async () => {
  if (!confirm('Supprimer cette reunion ? Le compte rendu PDF reste dans vos documents.')) return
  await apiClient.delete(`/meetings/${props.id}`)
  router.push('/meetings')
}

const addTask = async (item, index) => {
  actionError.value = null
  try {
    const description = item.owner ? `${item.description} (${item.owner})` : item.description
    await apiClient.post('/tasks', { task: { description, deadline: item.due_date || null, priority: 3 } })
    addedTasks.value = new Set([...addedTasks.value, index])
  } catch (e) {
    actionError.value = errorOf(e)
  }
}

const stepState = (key) => {
  const order = Object.keys(STEP_LABELS)
  const current = order.indexOf(meeting.value?.step)
  const index = order.indexOf(key)
  if (current === -1) return 'todo'
  if (index < current) return 'done'
  return index === current ? 'current' : 'todo'
}

const speakerIndex = (id) => (meeting.value?.speakers || []).findIndex((s) => s.id === id)
const speakerColor = (id) => COLORS[Math.max(speakerIndex(id), 0) % COLORS.length]
// Apres une reprise d'enregistrement, les voix de la partie 2 sont numerotees a part (p2_speaker_1).
const defaultLabel = (id) => {
  const parted = String(id).match(/^p(\d+)_speaker_(\d+)$/)
  if (parted) return `Intervenant ${parted[2]} (partie ${parted[1]})`
  return `Intervenant ${String(id).match(/\d+/)?.[0] || id}`
}
const labelOf = (id) => (meeting.value?.speakers || []).find((s) => s.id === id)?.label || defaultLabel(id)

const paragraphs = (text) => (text || '').split(/\n{2,}/).filter(Boolean)

const formatDate = (value) => {
  const date = new Date(`${value}T12:00:00`)
  return Number.isNaN(date.getTime()) ? value : date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })
}

onMounted(fetchMeeting)
onBeforeUnmount(() => clearTimeout(timer))
</script>
