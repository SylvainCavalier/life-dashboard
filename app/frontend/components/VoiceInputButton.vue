<template>
  <div v-if="supported" class="relative inline-flex items-center gap-1.5">
    <span v-if="state === 'recording'" class="text-xs tabular-nums text-red-600">{{ clock }}</span>
    <button
      v-if="state === 'recording'"
      type="button"
      class="text-xs text-gray-400 hover:text-gray-600"
      title="Annuler sans transcrire"
      @click="cancel"
    >
      Annuler
    </button>
    <button
      type="button"
      :class="[
        'flex-shrink-0 flex items-center justify-center rounded-full transition disabled:opacity-40',
        size === 'sm' ? 'h-8 w-8' : 'h-9 w-9',
        state === 'recording' ? 'bg-red-600 text-white animate-pulse' : 'bg-gray-100 text-gray-600 hover:bg-gray-200',
      ]"
      :disabled="disabled || state === 'transcribing'"
      :title="title"
      :aria-label="title"
      :aria-pressed="state === 'recording'"
      @click="toggle"
    >
      <svg v-if="state === 'transcribing'" class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="2" opacity="0.25" />
        <path d="M21 12a9 9 0 0 0-9-9" stroke="currentColor" stroke-width="2" stroke-linecap="round" />
      </svg>
      <svg v-else-if="state === 'recording'" class="w-3.5 h-3.5" fill="currentColor" viewBox="0 0 24 24">
        <rect x="6" y="6" width="12" height="12" rx="2" />
      </svg>
      <svg v-else class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
        <rect x="9" y="3" width="6" height="11" rx="3" />
        <path stroke-linecap="round" d="M5 11a7 7 0 0 0 14 0M12 18v3" />
      </svg>
    </button>
    <p
      v-if="error"
      class="absolute right-0 bottom-full mb-1 z-10 w-56 rounded-lg bg-red-50 border border-red-100 px-2 py-1 text-xs text-red-700"
      role="alert"
      @click="error = null"
    >
      {{ error }}
    </p>
  </div>
</template>

<script setup>
// Bouton de dictee reutilisable : enregistre, fait transcrire, emet `transcribed`
// avec le texte. Au parent de l'inserer (voir insertAtCursor). Invisible si le
// navigateur ne sait pas enregistrer (ou hors HTTPS).
import { computed } from 'vue'
import { useVoiceRecorder, voiceSupported } from '../composables/useVoiceRecorder'

const props = defineProps({
  maxSeconds: { type: Number, default: 300 },
  size: { type: String, default: 'md' },
  disabled: { type: Boolean, default: false },
})
const emit = defineEmits(['transcribed'])

const supported = voiceSupported()
const { state, clock, error, toggle, cancel } = useVoiceRecorder({
  maxSeconds: props.maxSeconds,
  onText: (text) => emit('transcribed', text),
})

const title = computed(() => {
  if (state.value === 'recording') return 'Arreter et transcrire'
  if (state.value === 'transcribing') return 'Transcription en cours...'
  return 'Dicter'
})
</script>
