<template>
  <div class="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-6">
    <!-- Apercu -->
    <div class="bg-white rounded-xl shadow-sm p-4">
      <div class="h-[520px] rounded flex items-center justify-center overflow-hidden" :style="backdropStyle">
        <canvas
          ref="canvas"
          class="max-w-full max-h-full cursor-crosshair"
          @click="pickColor"
        ></canvas>
      </div>
      <div class="flex flex-wrap items-center gap-2 mt-4">
        <span class="text-xs text-gray-400 mr-1">Fond d'aperçu</span>
        <button
          v-for="b in BACKDROPS"
          :key="b.key"
          @click="backdrop = b.key"
          class="text-xs px-3 py-1.5 rounded-lg transition-colors"
          :class="backdrop === b.key ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
        >
          {{ b.label }}
        </button>
        <label class="flex items-center gap-2 text-xs text-gray-600 ml-auto">
          <input v-model="showOriginal" type="checkbox" class="rounded border-gray-300" />
          Voir l'original
        </label>
      </div>
      <p class="text-xs text-gray-400 mt-2">Cliquez sur le fond dans l'aperçu pour en prélever la couleur.</p>
    </div>

    <!-- Reglages -->
    <div class="space-y-4">
      <div class="bg-white rounded-xl shadow-sm p-4 space-y-4">
        <div>
          <p class="text-sm font-medium text-gray-700 mb-2">Couleur du fond</p>
          <div class="flex items-center gap-2">
            <input v-model="colorHex" type="color" class="h-9 w-12 rounded border border-gray-200" />
            <span class="text-sm text-gray-600 font-mono">{{ colorHex }}</span>
            <button @click="autoDetect" class="text-xs px-2 py-1 rounded bg-gray-100 text-gray-600 hover:bg-gray-200 ml-auto">Détecter</button>
          </div>
        </div>

        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Tolérance ({{ tolerance }})</span>
          <input v-model.number="tolerance" type="range" min="0" max="60" class="w-full" />
          <span class="block text-xs text-gray-400">À augmenter si des traces de fond subsistent (JPEG compressé, léger dégradé).</span>
        </label>

        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Adoucissement ({{ softness }})</span>
          <input v-model.number="softness" type="range" min="0" max="40" class="w-full" />
          <span class="block text-xs text-gray-400">Transition progressive pour les ombres et reflets proches du fond.</span>
        </label>

        <div>
          <p class="text-sm font-medium text-gray-700 mb-2">Zones retirées</p>
          <label class="flex items-start gap-2 text-sm text-gray-700 mb-1">
            <input v-model="mode" type="radio" value="connected" class="mt-1" />
            <span>Le fond autour du sujet <span class="block text-xs text-gray-400">garde les zones de même couleur à l'intérieur (blanc d'un œil, creux d'une lettre)</span></span>
          </label>
          <label class="flex items-start gap-2 text-sm text-gray-700">
            <input v-model="mode" type="radio" value="global" class="mt-1" />
            <span>Toute cette couleur, partout</span>
          </label>
        </div>

        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input v-model="smoothEdges" type="checkbox" class="rounded border-gray-300" />
          Lisser les contours (évite le liseré)
        </label>
      </div>

      <div v-if="error" class="text-xs text-red-600">{{ error }}</div>

      <button
        @click="exportPng"
        :disabled="exporting || !preview"
        class="w-full text-sm px-4 py-3 rounded-lg bg-indigo-600 text-white font-medium hover:bg-indigo-700 disabled:opacity-50"
      >
        {{ exporting ? 'Préparation...' : 'Télécharger le PNG' }}
      </button>
      <button
        @click="continueWithCrop"
        :disabled="exporting || !preview"
        class="w-full text-sm px-4 py-2 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50 disabled:opacity-50"
      >
        Recadrer / redimensionner ce résultat
      </button>
      <p v-if="scaled" class="text-xs text-gray-400 text-center">
        Aperçu réduit ; le PNG est calculé en taille réelle ({{ source.width }} × {{ source.height }} px).
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, shallowRef, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { detectBackground, removeBackground, toHex, fromHex } from '../imageTransparency'
import { readPixels } from './imageSource'
import { downloadBlob, baseName } from '../files'

const props = defineProps({
  source: { type: Object, required: true },
})

const emit = defineEmits(['replace'])

// L'apercu travaille sur une version reduite pour rester fluide sur les curseurs.
const PREVIEW_MAX_SIDE = 1000

const BACKDROPS = [
  { key: 'checker', label: 'Damier' },
  { key: 'dark', label: 'Sombre' },
  { key: 'light', label: 'Clair' },
]

const canvas = ref(null)
const preview = shallowRef(null)
const colorHex = ref('#ffffff')
const tolerance = ref(12)
const softness = ref(8)
const mode = ref('connected')
const smoothEdges = ref(true)
const backdrop = ref('checker')
const showOriginal = ref(false)
const exporting = ref(false)
const error = ref(null)

const scaled = computed(() => preview.value && preview.value.width < props.source.width)

const backdropStyle = computed(() => {
  if (backdrop.value === 'dark') return { background: '#1f2937' }
  if (backdrop.value === 'light') return { background: '#ffffff' }
  return {
    backgroundColor: '#ffffff',
    backgroundImage: 'conic-gradient(#e5e7eb 25%, transparent 0 50%, #e5e7eb 0 75%, transparent 0)',
    backgroundSize: '20px 20px',
  }
})

const options = () => ({
  color: fromHex(colorHex.value),
  tolerance: tolerance.value,
  softness: softness.value,
  mode: mode.value,
  decontaminate: smoothEdges.value,
})

let timer = null

const render = () => {
  if (!preview.value || !canvas.value) return
  const data = showOriginal.value ? preview.value : removeBackground(preview.value, options())
  canvas.value.width = data.width
  canvas.value.height = data.height
  canvas.value.getContext('2d').putImageData(data, 0, 0)
}

const scheduleRender = () => {
  clearTimeout(timer)
  timer = setTimeout(render, 60)
}

watch([colorHex, tolerance, softness, mode, smoothEdges, showOriginal], scheduleRender)

const autoDetect = () => {
  colorHex.value = toHex(detectBackground(preview.value))
}

const pickColor = (event) => {
  if (!preview.value) return
  const rect = canvas.value.getBoundingClientRect()
  const x = Math.floor((event.clientX - rect.left) / rect.width * preview.value.width)
  const y = Math.floor((event.clientY - rect.top) / rect.height * preview.value.height)
  const offset = (y * preview.value.width + x) * 4
  const data = preview.value.data
  colorHex.value = toHex({ r: data[offset], g: data[offset + 1], b: data[offset + 2] })
}

// Calcul en taille reelle, uniquement a l'export.
const buildPng = async () => {
  const full = await readPixels(props.source)
  const result = removeBackground(full, options())
  const output = document.createElement('canvas')
  output.width = result.width
  output.height = result.height
  output.getContext('2d').putImageData(result, 0, 0)
  const blob = await new Promise(resolve => output.toBlob(resolve, 'image/png'))
  if (!blob) throw new Error('Export impossible (image trop grande pour le navigateur ?)')
  return blob
}

const run = async (action) => {
  error.value = null
  exporting.value = true
  try {
    const blob = await buildPng()
    action(blob, `${baseName(props.source.name)}-transparent.png`)
  } catch (e) {
    error.value = e.message
  } finally {
    exporting.value = false
  }
}

const exportPng = () => run((blob, name) => downloadBlob(blob, name))

const continueWithCrop = () => run((blob, name) => {
  emit('replace', { file: new File([blob], name, { type: 'image/png' }), tool: 'crop' })
})

onMounted(async () => {
  try {
    preview.value = await readPixels(props.source, PREVIEW_MAX_SIDE)
    autoDetect()
    render()
  } catch (e) {
    error.value = e.message
  }
})

onBeforeUnmount(() => clearTimeout(timer))
</script>
