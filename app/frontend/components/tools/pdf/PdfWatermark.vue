<template>
  <div>
    <h2 class="font-semibold text-gray-900 mb-4">Ajouter un filigrane</h2>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Texte</label>
        <input v-model="options.text" type="text" maxlength="80" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        <div class="flex flex-wrap gap-2 mt-2">
          <button
            v-for="preset in PRESETS"
            :key="preset"
            @click="options.text = preset"
            class="text-xs px-2 py-1 rounded bg-gray-100 text-gray-600 hover:bg-gray-200"
          >
            {{ preset }}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Taille ({{ options.fontSize }})</span>
          <input v-model.number="options.fontSize" type="range" min="16" max="140" class="w-full" />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Opacité ({{ Math.round(options.opacity * 100) }} %)</span>
          <input v-model.number="options.opacity" type="range" min="0.05" max="1" step="0.05" class="w-full" />
        </label>
        <div>
          <span class="block text-sm font-medium text-gray-700 mb-1">Orientation</span>
          <div class="flex gap-2">
            <button
              v-for="a in ANGLES"
              :key="a.value"
              @click="options.angle = a.value"
              class="text-sm px-3 py-1.5 rounded-lg border transition-colors"
              :class="options.angle === a.value ? 'border-indigo-500 bg-indigo-50 text-indigo-700' : 'border-gray-200 text-gray-600 hover:bg-gray-50'"
            >
              {{ a.label }}
            </button>
          </div>
        </div>
        <label class="flex items-end gap-2 text-sm text-gray-700">
          <input v-model="options.color" type="color" class="h-8 w-10 rounded border border-gray-200" />
          Couleur
        </label>
      </div>
    </div>

    <!-- Apercu indicatif sur une page A4 -->
    <div class="mt-6 flex items-end justify-between gap-6">
      <div class="w-28 aspect-[210/297] bg-white border border-gray-200 rounded shadow-sm relative overflow-hidden flex items-center justify-center">
        <span
          class="font-bold whitespace-nowrap"
          :style="{
            color: options.color,
            opacity: options.opacity,
            fontSize: `${options.fontSize * 112 / 595}px`,
            transform: `rotate(${-options.angle}deg)`,
          }"
        >{{ options.text }}</span>
      </div>
      <button
        @click="submit"
        :disabled="busy || !options.text.trim()"
        class="text-sm px-4 py-2 rounded-lg bg-gray-900 text-white font-medium hover:bg-gray-700 disabled:opacity-50"
      >
        {{ busy ? 'Traitement...' : 'Appliquer le filigrane' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { reactive } from 'vue'
import { addWatermark } from '../pdfOperations'

// Les autres outils recoivent aussi l'apercu, la page choisie... : pas en attributs HTML.
defineOptions({ inheritAttrs: false })

const props = defineProps({
  bytes: { type: Uint8Array, required: true },
  busy: { type: Boolean, default: false },
})

const emit = defineEmits(['apply'])

const PRESETS = ['CONFIDENTIEL', 'COPIE', 'BROUILLON', 'PROJET', 'SPÉCIMEN']
const ANGLES = [
  { value: 45, label: 'Diagonale' },
  { value: 0, label: 'Horizontale' },
]

const options = reactive({
  text: 'CONFIDENTIEL',
  fontSize: 60,
  opacity: 0.2,
  angle: 45,
  color: '#9ca3af',
})

const submit = () => {
  emit('apply', {
    label: 'filigrane',
    run: () => addWatermark(props.bytes, { ...options, text: options.text.trim() }),
  })
}
</script>
