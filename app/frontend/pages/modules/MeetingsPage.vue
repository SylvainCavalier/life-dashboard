<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-4xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <div class="flex items-start justify-between gap-4 mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Reunions</h1>
          <p class="text-sm text-gray-500 mt-1">
            Un enregistrement devient une transcription par intervenant, une synthese et un compte rendu PDF range dans les documents.
            L'audio est supprime apres traitement.
          </p>
        </div>
        <div v-if="!showForm" class="flex flex-shrink-0 gap-2">
          <router-link to="/meetings/record" class="bg-red-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-red-700 transition">
            Enregistrer
          </router-link>
          <button class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition" @click="openForm">
            Importer
          </button>
        </div>
      </div>

      <!-- Import d'un enregistrement -->
      <form v-if="showForm" class="bg-white rounded-xl shadow-sm p-6 mb-6" @submit.prevent="submit">
        <h2 class="text-lg font-semibold mb-4">Importer un enregistrement</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Titre *</label>
            <input v-model="form.title" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Point avec le notaire, reunion client..." />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Date et heure</label>
            <input v-model="form.held_at" type="datetime-local" class="w-full border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Type</label>
            <select v-model="form.kind" class="w-full border rounded-lg px-3 py-2 text-sm bg-white">
              <option value="in_person">Presentiel</option>
              <option value="visio">Visio</option>
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Participants</label>
            <input v-model="form.participants" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Sylvain, Marie Dupont, Me Martin (separes par des virgules)" />
            <p class="text-xs text-gray-400 mt-1">Aide l'IA a mettre un nom sur chaque voix et a orthographier les noms propres.</p>
          </div>
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Contexte (optionnel)</label>
            <textarea v-model="form.context" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Objet de la reunion, enjeux, vocabulaire particulier..."></textarea>
          </div>
          <div class="md:col-span-2">
            <label class="block text-sm font-medium text-gray-700 mb-1">Enregistrement *</label>
            <input
              type="file"
              accept="audio/*,video/mp4,video/webm,video/quicktime,.m4a,.mp3,.wav,.webm"
              class="block w-full text-sm text-gray-600 file:mr-3 file:rounded-lg file:border-0 file:bg-gray-100 file:px-3 file:py-2 file:text-sm hover:file:bg-gray-200"
              @change="pickFile"
            />
            <p class="text-xs text-gray-400 mt-1">Dictaphone de l'iPhone (m4a), mp3, wav, webm, ou video mp4 (enregistrement Zoom). 500 Mo maximum.</p>
          </div>
        </div>

        <p class="text-xs text-amber-800 bg-amber-50 border border-amber-100 rounded-lg px-3 py-2 mb-4">
          Les participants doivent avoir ete prevenus de l'enregistrement et l'avoir accepte.
        </p>

        <div v-if="uploadProgress !== null" class="mb-4">
          <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
            <div class="h-full bg-gray-900 transition-all" :style="{ width: `${uploadProgress}%` }"></div>
          </div>
          <p class="text-xs text-gray-500 mt-1">Envoi de l'enregistrement : {{ uploadProgress }} %</p>
        </div>
        <p v-if="formError" class="text-sm text-red-600 mb-4">{{ formError }}</p>

        <div class="flex justify-end gap-2">
          <button type="button" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2" :disabled="submitting" @click="showForm = false">Annuler</button>
          <button type="submit" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40" :disabled="submitting || !form.title.trim() || !file">
            {{ submitting ? 'Envoi...' : 'Lancer la transcription' }}
          </button>
        </div>
      </form>

      <!-- Liste -->
      <div v-if="loaded && meetings.length === 0" class="text-center text-gray-400 py-12">Aucune reunion pour l'instant</div>

      <div class="space-y-3">
        <router-link
          v-for="meeting in meetings"
          :key="meeting.id"
          :to="`/meetings/${meeting.id}`"
          class="block bg-white rounded-xl shadow-sm p-5 hover:shadow-md transition"
        >
          <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
              <h3 class="font-semibold text-gray-900 truncate">{{ meeting.title }}</h3>
              <p class="text-xs text-gray-500 mt-0.5">
                {{ formatDateTime(meeting.held_at) }} · {{ meeting.kind === 'visio' ? 'Visio' : 'Presentiel' }}
                <span v-if="meeting.duration_seconds"> · {{ formatDuration(meeting.duration_seconds) }}</span>
              </p>
            </div>
            <span :class="['flex-shrink-0 text-xs px-2 py-0.5 rounded-full', statusClass(meeting)]">{{ statusLabel(meeting) }}</span>
          </div>
          <p v-if="meeting.overview" class="text-sm text-gray-600 mt-2 line-clamp-2">{{ meeting.overview }}</p>
          <p v-else-if="meeting.status === 'failed'" class="text-sm text-red-600 mt-2 line-clamp-2">{{ meeting.error }}</p>
          <p v-else-if="meeting.status === 'recording'" class="text-sm text-gray-500 mt-2">
            {{ meeting.recording?.chunks || 0 }} morceau(x) recu(s) : en cours ailleurs ou interrompu. Ouvrir pour reprendre ou terminer.
          </p>
        </router-link>
      </div>
    </div>
  </div>
</template>

<script setup>
// Liste des reunions et import d'un enregistrement. L'audio part en direct upload
// vers le bucket (pas de delai serveur), puis la reunion est creee avec le signed_id.
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useRouter } from 'vue-router'
import apiClient from '../../plugins/axios'
import { useDirectUpload } from '../../composables/useDirectUpload'
import { formatDateTime, formatDuration, statusClass, statusLabel } from '../../utils/meetingFormat'

const POLL_INTERVAL = 3000

const router = useRouter()
const { uploadFile } = useDirectUpload()

const meetings = ref([])
const loaded = ref(false)
const showForm = ref(false)
const submitting = ref(false)
const uploadProgress = ref(null)
const formError = ref(null)
const file = ref(null)
let timer = null

// datetime-local attend l'heure locale sans fuseau.
const nowLocal = () => {
  const d = new Date()
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset())
  return d.toISOString().slice(0, 16)
}

const defaultForm = () => ({ title: '', held_at: nowLocal(), kind: 'in_person', participants: '', context: '' })
const form = ref(defaultForm())

const fetchMeetings = async () => {
  const { data } = await apiClient.get('/meetings')
  meetings.value = data
  loaded.value = true
  schedule()
}

// Sondage tant qu'un traitement est en cours.
const schedule = () => {
  clearTimeout(timer)
  if (meetings.value.some((m) => m.in_progress)) timer = setTimeout(fetchMeetings, POLL_INTERVAL)
}

const openForm = () => {
  form.value = defaultForm()
  file.value = null
  formError.value = null
  uploadProgress.value = null
  showForm.value = true
}

const pickFile = (event) => {
  file.value = event.target.files?.[0] || null
  // Titre propose a partir du nom du fichier s'il est vide.
  if (file.value && !form.value.title.trim()) form.value.title = file.value.name.replace(/\.[^.]+$/, '')
}

const submit = async () => {
  if (!file.value || !form.value.title.trim()) return
  submitting.value = true
  formError.value = null
  try {
    uploadProgress.value = 0
    const blob = await uploadFile(file.value, (p) => { uploadProgress.value = p })
    const { data } = await apiClient.post('/meetings', {
      meeting: { ...form.value, held_at: new Date(form.value.held_at).toISOString() },
      audio: blob.signed_id,
    })
    showForm.value = false
    router.push(`/meetings/${data.id}`)
  } catch (e) {
    formError.value = e?.response?.data?.errors?.join(', ') || e?.message || "L'import a echoue."
  } finally {
    submitting.value = false
    uploadProgress.value = null
  }
}

onMounted(fetchMeetings)
onBeforeUnmount(() => clearTimeout(timer))
</script>
