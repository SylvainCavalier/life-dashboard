<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-2xl mx-auto">
      <router-link v-if="!active" to="/meetings" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Toutes les reunions</router-link>

      <!-- Preparation -->
      <div v-if="phase === 'setup'" class="bg-white rounded-xl shadow-sm p-6">
        <h1 class="text-xl font-bold text-gray-900 mb-1">{{ resumeMeeting ? 'Reprendre l\'enregistrement' : 'Enregistrer une reunion' }}</h1>
        <p v-if="resumeMeeting" class="text-sm text-gray-500 mb-4">
          {{ resumeMeeting.title }} · {{ resumeMeeting.recording?.chunks || 0 }} morceau(x) deja recu(s). La suite sera ajoutee a la meme reunion.
        </p>
        <p v-else class="text-sm text-gray-500 mb-4">A la fin, la transcription, la synthese et le compte rendu PDF sont produits automatiquement.</p>

        <!-- Mode -->
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-5">
          <button
            v-for="option in modes"
            :key="option.value"
            type="button"
            :disabled="option.disabled"
            :class="[
              'text-left rounded-xl border-2 p-4 transition disabled:opacity-40 disabled:cursor-not-allowed',
              mode === option.value ? 'border-gray-900 bg-gray-50' : 'border-gray-200 hover:border-gray-300',
            ]"
            @click="mode = option.value"
          >
            <p class="font-semibold text-gray-900 text-sm">{{ option.label }}</p>
            <p class="text-xs text-gray-500 mt-1">{{ option.help }}</p>
          </button>
        </div>

        <template v-if="!resumeMeeting">
          <div class="space-y-3 mb-5">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Titre</label>
              <input v-model="form.title" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Facultatif (par defaut : « Reunion du ... »)" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Participants</label>
              <input v-model="form.participants" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Sylvain, Marie Dupont... (aide a nommer les voix)" />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Contexte (optionnel)</label>
              <textarea v-model="form.context" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Objet de la reunion, vocabulaire particulier..."></textarea>
            </div>
          </div>
        </template>

        <ul class="text-xs text-gray-600 bg-gray-50 rounded-lg p-3 mb-4 space-y-1">
          <li v-if="mode === 'in_person'">Posez l'appareil au centre de la table, ecran allume. Sur iPhone, restez sur cette page : Safari coupe le micro des qu'on change d'application ou qu'on verrouille.</li>
          <li v-else>Chrome va vous demander quoi partager : choisissez l'onglet de la visio et cochez « Partager aussi l'audio de l'onglet ». Gardez votre casque : votre voix est prise par le micro, celle des autres par l'onglet.</li>
          <li>L'audio part sur le serveur toutes les 30 s : une coupure ne fait perdre que les dernieres secondes.</li>
        </ul>
        <p class="text-xs text-amber-800 bg-amber-50 border border-amber-100 rounded-lg px-3 py-2 mb-4">
          Les participants doivent avoir ete prevenus de l'enregistrement et l'avoir accepte.
        </p>

        <p v-if="!micSupported" class="text-sm text-red-600 mb-4">
          Ce navigateur ne peut pas enregistrer ici (HTTPS obligatoire, ou localhost en developpement).
        </p>
        <p v-if="error" class="text-sm text-red-600 mb-4">{{ error }}</p>

        <button
          class="w-full bg-red-600 text-white font-medium px-4 py-3 rounded-xl hover:bg-red-700 transition disabled:opacity-40"
          :disabled="!micSupported || state === 'starting'"
          @click="begin"
        >
          {{ state === 'starting' ? 'Demarrage...' : 'Demarrer l\'enregistrement' }}
        </button>
      </div>

      <!-- Enregistrement en cours / interrompu / envoi final -->
      <div v-else class="bg-gray-900 text-white rounded-2xl shadow-lg p-6 sm:p-8">
        <p class="text-sm text-gray-400 truncate">{{ title }}</p>

        <div class="flex items-center gap-3 mt-4">
          <span :class="['w-3 h-3 rounded-full', state === 'recording' ? 'bg-red-500 animate-pulse' : 'bg-gray-500']"></span>
          <span class="text-sm font-medium">{{ phaseLabel }}</span>
        </div>
        <p class="text-5xl font-light tabular-nums mt-3">{{ clock }}</p>

        <!-- Niveaux : la preuve que le son arrive, surtout celui de l'onglet en visio -->
        <div v-if="state === 'recording'" class="mt-6 space-y-3">
          <div>
            <p class="text-xs text-gray-400 mb-1">Micro</p>
            <div class="h-2 bg-gray-700 rounded-full overflow-hidden">
              <div class="h-full bg-emerald-400 transition-[width] duration-75" :style="{ width: `${Math.round(micLevel * 100)}%` }"></div>
            </div>
          </div>
          <div v-if="mode === 'visio'">
            <p class="text-xs text-gray-400 mb-1">Visio (audio de l'onglet)</p>
            <div class="h-2 bg-gray-700 rounded-full overflow-hidden">
              <div class="h-full bg-sky-400 transition-[width] duration-75" :style="{ width: `${Math.round(tabLevel * 100)}%` }"></div>
            </div>
          </div>
        </div>

        <div class="mt-6 text-xs text-gray-400 space-y-1">
          <p>{{ sent }} morceau(x) envoye(s)<span v-if="pending"> · {{ pending }} en attente</span></p>
          <p v-if="retrying" class="text-amber-300">Reseau indisponible : l'audio est garde et renvoye des que possible. Ne fermez pas la page.</p>
          <p v-if="state === 'recording'">{{ wakeLockActive ? 'Ecran maintenu allume.' : 'Gardez l\'ecran allume et la page ouverte.' }}</p>
        </div>

        <div v-if="halted" class="mt-6 bg-gray-800 rounded-xl p-4">
          <p class="text-sm text-amber-300">{{ notice || 'Enregistrement interrompu.' }}</p>
          <p class="text-xs text-gray-400 mt-1">Ce qui a ete enregistre est conserve. Reprenez pour continuer dans la meme reunion, ou terminez pour lancer la transcription.</p>
        </div>
        <p v-if="error" class="text-sm text-red-300 mt-4">{{ error }}</p>

        <div class="flex flex-wrap gap-3 mt-8">
          <button
            v-if="halted"
            class="flex-1 bg-white text-gray-900 font-medium px-4 py-3 rounded-xl hover:bg-gray-100"
            @click="resume"
          >
            Reprendre
          </button>
          <button
            v-if="state === 'recording' || halted"
            class="flex-1 bg-red-600 font-medium px-4 py-3 rounded-xl hover:bg-red-700"
            @click="stop"
          >
            Terminer et transcrire
          </button>
          <button
            v-if="state === 'recording' || halted"
            class="px-4 py-3 text-sm text-gray-400 hover:text-white"
            @click="abandon"
          >
            Annuler
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
// Enregistrement en direct d'une reunion (presentiel : micro ; visio : onglet + micro).
// La reunion est creee au premier clic, apres l'acces au micro et a l'onglet (le partage
// d'onglet exige un geste utilisateur tout frais). `?resume=ID` reprend une reunion
// interrompue dans une nouvelle partie.
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router'
import apiClient from '../../plugins/axios'
import { useMeetingRecorder, canRecordMic, canCaptureTab } from '../../composables/useMeetingRecorder'
import { timecode } from '../../utils/meetingFormat'

const route = useRoute()
const router = useRouter()
const recorder = useMeetingRecorder()
const { state, notice, elapsed, micLevel, tabLevel, sent, pending, retrying, wakeLockActive } = recorder

const micSupported = canRecordMic()
const tabSupported = canCaptureTab()
const mode = ref('in_person')
const form = ref({ title: '', participants: '', context: '' })
const resumeMeeting = ref(null)
const meetingId = ref(null)
const title = ref('')
const localError = ref(null)

const error = computed(() => localError.value || recorder.error.value)
const phase = computed(() => (['idle', 'starting', 'error'].includes(state.value) && !meetingId.value ? 'setup' : 'live'))
const active = computed(() => ['starting', 'recording', 'stopping'].includes(state.value))
const clock = computed(() => timecode(elapsed.value))
// Interrompu, ou echec d'une reprise : on peut reprendre ou terminer avec ce qui est deja envoye.
const halted = computed(() => ['interrupted', 'error'].includes(state.value))

const phaseLabel = computed(() => ({
  starting: 'Demarrage...',
  recording: mode.value === 'visio' ? 'Enregistrement de la visio' : 'Enregistrement',
  interrupted: 'Interrompu',
  stopping: pending.value ? `Envoi des derniers morceaux (${pending.value})...` : 'Lancement de la transcription...',
  error: 'Erreur',
}[state.value] || ''))

const modes = [
  { value: 'in_person', label: 'Presentiel', help: 'Micro de cet appareil (iPhone ou ordinateur).', disabled: false },
  {
    value: 'visio',
    label: 'Visio',
    help: tabSupported ? 'Son de l\'onglet de la visio + votre micro.' : 'Chrome ou Edge sur ordinateur uniquement.',
    disabled: !tabSupported,
  },
]

const createMeeting = async () => {
  const { data } = await apiClient.post('/meetings', {
    recording: true,
    meeting: { ...form.value, kind: mode.value, held_at: new Date().toISOString() },
  })
  title.value = data.title
  return data.id
}

const begin = async () => {
  localError.value = null
  const resuming = resumeMeeting.value
  const id = await recorder.start({
    mode: mode.value,
    ensureMeeting: resuming ? async () => resuming.id : createMeeting,
    part: resuming ? resuming.recording?.next_part || 1 : 1,
    alreadyRecorded: resuming ? (resuming.recording?.chunks || 0) * 30 : 0,
  })
  if (id) {
    meetingId.value = id
    if (resuming) title.value = resuming.title
  }
}

// Reprise sur la meme page apres une interruption : partie suivante.
const resume = async () => {
  localError.value = null
  await recorder.start({
    mode: mode.value,
    ensureMeeting: async () => meetingId.value,
    part: recorder.currentPart() + 1,
    alreadyRecorded: elapsed.value,
  })
}

const stop = async () => {
  if (!confirm('Terminer l\'enregistrement et lancer la transcription ?')) return
  const data = await recorder.finish()
  if (data) router.push(`/meetings/${data.id}`)
}

const abandon = async () => {
  if (!confirm('Annuler et supprimer cet enregistrement ? Rien ne sera conserve.')) return
  await recorder.cancel()
  if (meetingId.value) await apiClient.delete(`/meetings/${meetingId.value}`).catch(() => {})
  router.push('/meetings')
}

const loadResume = async () => {
  const id = route.query.resume
  if (!id) return
  try {
    const { data } = await apiClient.get(`/meetings/${id}`)
    if (data.status !== 'recording') {
      router.replace(`/meetings/${id}`)
      return
    }
    resumeMeeting.value = data
    mode.value = data.kind === 'visio' && tabSupported ? 'visio' : 'in_person'
  } catch {
    localError.value = 'Reunion introuvable.'
  }
}

const warnBeforeUnload = (event) => {
  if (!active.value && state.value !== 'interrupted') return
  event.preventDefault()
  event.returnValue = ''
}

onBeforeRouteLeave(() => {
  if (!active.value) return true
  return confirm('Un enregistrement est en cours. Quitter la page l\'interrompt (ce qui a ete envoye est garde). Quitter quand meme ?')
})

onMounted(() => {
  window.addEventListener('beforeunload', warnBeforeUnload)
  loadResume()
})
onBeforeUnmount(() => window.removeEventListener('beforeunload', warnBeforeUnload))
</script>
