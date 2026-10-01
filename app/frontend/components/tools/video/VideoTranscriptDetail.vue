<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <p v-if="!transcript" class="text-sm text-gray-400">Chargement...</p>

    <template v-else>
      <!-- En-tete -->
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0">
          <h2 class="text-lg font-semibold text-gray-900">{{ transcript.title }}</h2>
          <p class="text-xs text-gray-500 mt-0.5">
            {{ transcript.source }} · {{ transcript.language_label }}
            <span v-if="transcript.duration_seconds"> · {{ formatDuration(transcript.duration_seconds) }}</span>
            · {{ formatDateTime(transcript.created_at) }}
          </p>
          <p v-if="transcript.source_citation" class="text-xs text-gray-400 mt-1">{{ transcript.source_citation }}</p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <span :class="['text-xs px-2 py-0.5 rounded-full', statusClass(transcript)]">{{ statusLabel(transcript) }}</span>
          <button class="text-gray-400 hover:text-gray-600 text-lg leading-none px-1" title="Fermer" @click="$emit('close')">&times;</button>
        </div>
      </div>

      <!-- Traitement en cours -->
      <div v-if="transcript.in_progress" class="mt-4 flex items-center gap-3 text-sm text-blue-700 bg-blue-50 rounded-lg px-4 py-3">
        <span class="inline-block w-4 h-4 border-2 border-blue-300 border-t-blue-700 rounded-full animate-spin"></span>
        <span>
          {{ transcript.step ? STEP_LABELS[transcript.step] : 'En attente' }} en cours... Une heure de vidéo se traite en quelques minutes ;
          vous pouvez quitter la page, le traitement continue.
        </span>
      </div>
      <div v-else-if="transcript.status === 'failed'" class="mt-4 text-sm text-red-700 bg-red-50 rounded-lg px-4 py-3">
        <p>{{ transcript.error }}</p>
        <button class="mt-2 text-xs px-3 py-1.5 rounded-lg bg-white border border-red-200 hover:bg-red-50" :disabled="busy" @click="regenerate">
          Relancer
        </button>
      </div>

      <!-- Actions -->
      <div v-if="transcript.transcribed" class="mt-4 flex flex-wrap items-center gap-2">
        <a :href="transcript.pdf_url" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">Télécharger le PDF</a>
        <button
          class="text-sm px-4 py-2 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50 disabled:opacity-40"
          :disabled="busy || transcript.in_progress"
          @click="saveToDocuments"
        >
          {{ transcript.document ? 'Mettre à jour dans les documents' : 'Ajouter aux documents' }}
        </button>
        <span v-if="transcript.document" class="text-xs text-gray-500">
          Rangé dans <router-link to="/documents" class="text-indigo-600 hover:underline">Documents › Transcriptions</router-link>
        </span>
        <span v-if="notice" class="text-xs text-emerald-700">{{ notice }}</span>
        <button class="ml-auto text-xs text-gray-400 hover:text-red-600" :disabled="busy" @click="remove">Supprimer</button>
      </div>
      <div v-else-if="!transcript.in_progress" class="mt-4 flex justify-end">
        <button class="text-xs text-gray-400 hover:text-red-600" :disabled="busy" @click="remove">Supprimer</button>
      </div>
      <p v-if="actionError" class="text-sm text-red-600 mt-3">{{ actionError }}</p>

      <!-- Resume -->
      <div v-if="summary" class="mt-6">
        <h3 class="text-base font-semibold mb-2">Résumé</h3>
        <p v-for="(paragraph, i) in paragraphs(summary.overview)" :key="i" class="text-sm text-gray-700 mb-3 whitespace-pre-line">{{ paragraph }}</p>

        <div v-if="summary.chapters?.length" class="mt-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-2">Déroulé</h4>
          <ol class="space-y-2">
            <li v-for="(chapter, i) in summary.chapters" :key="i" class="flex gap-3 text-sm">
              <span class="text-gray-400 tabular-nums flex-shrink-0">{{ chapter.start }}</span>
              <span class="text-gray-700"><span class="font-medium text-gray-900">{{ chapter.title }}</span> — {{ chapter.summary }}</span>
            </li>
          </ol>
        </div>

        <div v-if="summary.key_points?.length" class="mt-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-1">Points clés</h4>
          <ul class="list-disc pl-5 space-y-1">
            <li v-for="(item, i) in summary.key_points" :key="i" class="text-sm text-gray-700">{{ item }}</li>
          </ul>
        </div>

        <div v-if="summary.claims?.length" class="mt-4">
          <h4 class="text-sm font-semibold text-gray-900 mb-1">Affirmations notables</h4>
          <ul class="space-y-1">
            <li v-for="(claim, i) in summary.claims" :key="i" class="text-sm text-gray-700 flex gap-3">
              <span class="text-gray-400 tabular-nums flex-shrink-0">{{ claim.timecode }}</span>
              <span><span v-if="claim.speaker" class="font-medium text-gray-900">{{ labelOf(claim.speaker) }} : </span>{{ claim.statement }}</span>
            </li>
          </ul>
        </div>
        <p v-if="transcript.summary_model" class="text-xs text-gray-300 mt-4">Résumé : {{ transcript.summary_model }}</p>
      </div>

      <!-- Intervenants -->
      <div v-if="transcript.speakers?.length && !transcript.in_progress" class="mt-6">
        <h3 class="text-base font-semibold mb-1">Intervenants</h3>
        <p class="text-xs text-gray-500 mb-3">
          Les voix sont distinguées automatiquement. Les noms saisis s'appliquent tout de suite au PDF ;
          refaites le résumé pour qu'il les reprenne aussi (sans repayer la transcription).
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
          <label v-for="speaker in transcript.speakers" :key="speaker.id" class="flex items-center gap-2">
            <span :class="['w-2.5 h-2.5 rounded-full flex-shrink-0', speakerColor(speaker.id)]"></span>
            <span class="text-xs text-gray-400 w-24 flex-shrink-0">{{ defaultLabel(speaker.id) }}</span>
            <input v-model="names[speaker.id]" type="text" class="flex-1 min-w-0 border rounded-lg px-3 py-1.5 text-sm" placeholder="Nom" />
          </label>
        </div>
        <div class="flex justify-end gap-2">
          <button class="text-sm px-4 py-2 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50 disabled:opacity-40" :disabled="busy" @click="saveNames(false)">
            Enregistrer les noms
          </button>
          <button
            v-if="canSummarize"
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
            :disabled="busy"
            @click="saveNames(true)"
          >
            Enregistrer et refaire le résumé
          </button>
        </div>
      </div>

      <!-- Transcription -->
      <div v-if="transcript.turns?.length" class="mt-6">
        <div class="flex items-center justify-between gap-3 mb-3">
          <h3 class="text-base font-semibold">Transcription</h3>
          <input v-model="search" type="text" placeholder="Rechercher..." class="border rounded-lg px-3 py-1.5 text-sm w-40 sm:w-56" />
        </div>
        <div class="space-y-3 max-h-[32rem] overflow-y-auto pr-1">
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
      <p v-else-if="transcript.status === 'done'" class="text-center text-gray-400 py-6">Aucune parole détectée dans la vidéo.</p>
    </template>
  </div>
</template>

<script setup>
// Une transcription de video : suivi du traitement (sonde toutes les 3 s tant qu'il
// tourne), resume, intervenants a nommer, transcription, PDF et rangement dans les documents.
import { ref, computed, onMounted, onBeforeUnmount, onActivated, onDeactivated } from 'vue'
import apiClient from '../../../plugins/axios'
import { STEP_LABELS, errorOf, formatDateTime, formatDuration, statusClass, statusLabel, timecode } from './videoTranscriptFormat'

const props = defineProps({ id: { type: Number, required: true } })
const emit = defineEmits(['changed', 'close', 'deleted'])

const POLL_INTERVAL = 3000
const COLORS = ['bg-blue-500', 'bg-emerald-500', 'bg-amber-500', 'bg-rose-500', 'bg-violet-500', 'bg-cyan-500', 'bg-lime-500', 'bg-orange-500']

const transcript = ref(null)
const busy = ref(false)
const actionError = ref(null)
const notice = ref(null)
const names = ref({})
const search = ref('')
let timer = null
let active = true

const summary = computed(() => (transcript.value?.summary && Object.keys(transcript.value.summary).length ? transcript.value.summary : null))
const canSummarize = computed(() => transcript.value?.turns?.length > 0)

const filteredTurns = computed(() => {
  const turns = transcript.value?.turns || []
  const q = search.value.trim().toLowerCase()
  if (!q) return turns
  return turns.filter((t) => t.text.toLowerCase().includes(q) || labelOf(t.speaker).toLowerCase().includes(q))
})

const defaultLabel = (id) => `Intervenant ${id.match(/\d+/)?.[0] || id}`
const labelOf = (id) => transcript.value?.speakers?.find((s) => s.id === id)?.label || defaultLabel(id)
const speakerColor = (id) => {
  const index = (transcript.value?.speakers || []).findIndex((s) => s.id === id)
  return COLORS[(index < 0 ? 0 : index) % COLORS.length]
}
const paragraphs = (text) => (text || '').split(/\n{2,}/).filter(Boolean)

const apply = (data) => {
  const wasRunning = transcript.value?.in_progress
  transcript.value = data
  // Les noms saisis ne sont pas ecrases par le sondage, sauf quand le traitement se termine
  // (le resume a pu en deviner de nouveaux).
  if (!Object.keys(names.value).length || (wasRunning && !data.in_progress)) {
    names.value = Object.fromEntries((data.speakers || []).map((s) => [s.id, s.name || '']))
  }
  if (wasRunning && !data.in_progress) emit('changed')
  schedule()
}

const schedule = () => {
  clearTimeout(timer)
  if (active && transcript.value?.in_progress) timer = setTimeout(fetchTranscript, POLL_INTERVAL)
}

const fetchTranscript = async () => {
  try {
    const { data } = await apiClient.get(`/video_transcripts/${props.id}`)
    apply(data)
  } catch (e) {
    if (e?.response?.status === 404) emit('deleted', props.id)
  }
}

const run = async (action, successNotice = null) => {
  busy.value = true
  actionError.value = null
  notice.value = null
  try {
    apply(await action())
    notice.value = successNotice
    emit('changed')
  } catch (e) {
    actionError.value = errorOf(e)
  } finally {
    busy.value = false
  }
}

const regenerate = () => run(async () => (await apiClient.post(`/video_transcripts/${props.id}/regenerate`)).data)

const saveToDocuments = () => run(
  async () => (await apiClient.post(`/video_transcripts/${props.id}/save_to_documents`)).data,
  transcript.value.document ? 'Document mis à jour.' : 'Ajouté aux documents.',
)

const saveNames = (resummarize) => run(async () => {
  const { data } = await apiClient.patch(`/video_transcripts/${props.id}`, { video_transcript: { speaker_names: names.value } })
  if (!resummarize) return data
  return (await apiClient.post(`/video_transcripts/${props.id}/regenerate`)).data
}, resummarize ? null : 'Noms enregistrés.')

const remove = async () => {
  const kept = transcript.value.document ? ' Le PDF rangé dans les documents est conservé.' : ''
  if (!confirm(`Supprimer cette transcription ?${kept}`)) return
  busy.value = true
  try {
    await apiClient.delete(`/video_transcripts/${props.id}`)
    emit('deleted', props.id)
  } catch (e) {
    actionError.value = errorOf(e)
    busy.value = false
  }
}

onMounted(fetchTranscript)
onActivated(() => { active = true; schedule() })
onDeactivated(() => { active = false; clearTimeout(timer) })
onBeforeUnmount(() => clearTimeout(timer))
</script>
