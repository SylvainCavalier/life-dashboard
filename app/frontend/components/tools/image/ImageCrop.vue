<template>
  <div>
    <div v-if="error" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mb-4">{{ error }}</div>

    <div class="grid grid-cols-1 lg:grid-cols-[1fr_300px] gap-6">
      <!-- Zone de recadrage -->
      <div>
        <div class="bg-white rounded-xl shadow-sm p-4">
          <div class="h-[520px] bg-gray-100 rounded">
            <img ref="image" :src="source.src" alt="" class="block max-w-full" />
          </div>

          <div class="flex flex-wrap items-center gap-2 mt-4">
            <span class="text-xs text-gray-400 mr-1">Ratio</span>
            <button
              v-for="r in RATIOS"
              :key="r.label"
              @click="setRatio(r)"
              class="text-xs px-3 py-1.5 rounded-lg transition-colors"
              :class="ratio === r.label ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            >
              {{ r.label }}
            </button>
            <span class="mx-2 h-5 border-l border-gray-200"></span>
            <button @click="cropper.rotate(-90)" title="Pivoter à gauche" class="text-sm px-2.5 py-1 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200">⟲</button>
            <button @click="cropper.rotate(90)" title="Pivoter à droite" class="text-sm px-2.5 py-1 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200">⟳</button>
            <button @click="flip('x')" title="Miroir horizontal" class="text-sm px-2.5 py-1 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200">⇆</button>
            <button @click="flip('y')" title="Miroir vertical" class="text-sm px-2.5 py-1 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200">⇅</button>
            <button @click="resetCrop" class="text-xs px-3 py-1.5 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200">Réinitialiser</button>
          </div>
        </div>
      </div>

      <!-- Reglages de sortie -->
      <div class="space-y-4">
        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-sm text-gray-600">
            Zone sélectionnée : <strong class="text-gray-900">{{ crop.width }} × {{ crop.height }} px</strong>
          </p>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-sm font-medium text-gray-700 mb-3">Taille de sortie</p>
          <div class="grid grid-cols-2 gap-3">
            <label class="block">
              <span class="block text-xs text-gray-500 mb-1">Largeur (px)</span>
              <input :value="output.width" @input="setWidth($event.target.value)" type="number" min="1" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
            </label>
            <label class="block">
              <span class="block text-xs text-gray-500 mb-1">Hauteur (px)</span>
              <input :value="output.height" @input="setHeight($event.target.value)" type="number" min="1" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
            </label>
          </div>
          <label class="flex items-center gap-2 text-xs text-gray-600 mt-3">
            <input v-model="keepRatio" type="checkbox" class="rounded border-gray-300" @change="keepRatio && setWidth(output.width)" />
            Conserver les proportions
          </label>
          <div class="flex flex-wrap gap-2 mt-3">
            <button
              v-for="percent in [25, 50, 75, 100]"
              :key="percent"
              @click="scaleTo(percent)"
              class="text-xs px-2 py-1 rounded bg-gray-100 text-gray-600 hover:bg-gray-200"
            >
              {{ percent }} %
            </button>
          </div>
          <p v-if="output.width > crop.width || output.height > crop.height" class="text-xs text-amber-600 mt-2">
            Agrandir au-delà de la zone sélectionnée dégrade la netteté.
          </p>
        </div>

        <div class="bg-white rounded-xl shadow-sm p-4">
          <p class="text-sm font-medium text-gray-700 mb-3">Format</p>
          <div class="flex flex-wrap gap-2">
            <button
              v-for="f in FORMATS"
              :key="f.type"
              @click="format = f.type"
              class="text-xs px-3 py-1.5 rounded-lg transition-colors"
              :class="format === f.type ? 'bg-gray-900 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            >
              {{ f.label }}
            </button>
          </div>
          <label v-if="format !== 'image/png'" class="block mt-3">
            <span class="block text-xs text-gray-500 mb-1">Qualité ({{ Math.round(quality * 100) }} %)</span>
            <input v-model.number="quality" type="range" min="0.4" max="1" step="0.05" class="w-full" />
          </label>
          <p v-if="format === 'image/jpeg' && source.type !== 'image/jpeg'" class="text-xs text-gray-400 mt-2">
            Le JPEG n'a pas de transparence : le fond sera blanc.
          </p>
        </div>

        <button
          @click="exportImage"
          :disabled="exporting || !output.width || !output.height"
          class="w-full text-sm px-4 py-3 rounded-lg bg-indigo-600 text-white font-medium hover:bg-indigo-700 disabled:opacity-50"
        >
          {{ exporting ? 'Préparation...' : 'Télécharger l\'image' }}
        </button>
        <p v-if="lastExport" class="text-xs text-gray-400 text-center">
          Dernier export : {{ lastExport.width }} × {{ lastExport.height }} px, {{ humanSize(lastExport.size) }}
        </p>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted, onBeforeUnmount } from 'vue'
import Cropper from 'cropperjs'
import 'cropperjs/dist/cropper.css'
import { FORMATS } from './imageSource'
import { downloadBlob, baseName, humanSize } from '../files'

// L'image arrive deja chargee (ImageTool) ; le composant est recree a chaque nouvelle image.
const props = defineProps({
  source: { type: Object, required: true },
})

const RATIOS = [
  { label: 'Libre', value: NaN },
  { label: '1:1', value: 1 },
  { label: '4:3', value: 4 / 3 },
  { label: '3:2', value: 3 / 2 },
  { label: '16:9', value: 16 / 9 },
  { label: '9:16', value: 9 / 16 },
  { label: '3:4', value: 3 / 4 },
]

const image = ref(null)
const error = ref(null)
const ratio = ref('Libre')
const crop = reactive({ width: 0, height: 0 })
const output = reactive({ width: 0, height: 0 })
const keepRatio = ref(true)
// La taille de sortie suit le cadre tant qu'on ne l'a pas saisie a la main.
const customSize = ref(false)
const format = ref(FORMATS.some(f => f.type === props.source.type) ? props.source.type : 'image/png')
const quality = ref(0.9)
const exporting = ref(false)
const lastExport = ref(null)

let cropper = null

const destroyCropper = () => {
  cropper?.destroy()
  cropper = null
}

const initCropper = () => {
  cropper = new Cropper(image.value, {
    viewMode: 1,
    autoCropArea: 1,
    responsive: true,
    background: true,
    crop: (event) => {
      crop.width = Math.round(event.detail.width)
      crop.height = Math.round(event.detail.height)
      if (!customSize.value) {
        output.width = crop.width
        output.height = crop.height
      } else if (keepRatio.value) {
        setWidth(output.width, true)
      }
    },
  })
}

const setRatio = (r) => {
  ratio.value = r.label
  cropper?.setAspectRatio(r.value)
}

const flip = (axis) => {
  const data = cropper.getData()
  if (axis === 'x') cropper.scaleX(-(data.scaleX || 1))
  else cropper.scaleY(-(data.scaleY || 1))
}

const resetCrop = () => {
  cropper?.reset()
  setRatio(RATIOS[0])
  customSize.value = false
}

const setWidth = (value, keepCustom = false) => {
  const width = Math.max(parseInt(value, 10) || 0, 0)
  output.width = width
  if (keepRatio.value && crop.width) output.height = Math.max(Math.round(width * crop.height / crop.width), 1)
  if (!keepCustom) customSize.value = true
}

const setHeight = (value) => {
  const height = Math.max(parseInt(value, 10) || 0, 0)
  output.height = height
  if (keepRatio.value && crop.height) output.width = Math.max(Math.round(height * crop.width / crop.height), 1)
  customSize.value = true
}

const scaleTo = (percent) => {
  output.width = Math.max(Math.round(crop.width * percent / 100), 1)
  output.height = Math.max(Math.round(crop.height * percent / 100), 1)
  customSize.value = percent !== 100
}

// Reduction par paliers de moitie : un seul drawImage d'un facteur eleve crenelle l'image.
const resample = (canvas, width, height) => {
  let current = canvas
  while (current.width / 2 >= width && current.height / 2 >= height) {
    current = drawInto(current, Math.round(current.width / 2), Math.round(current.height / 2))
  }
  return current.width === width && current.height === height ? current : drawInto(current, width, height)
}

const drawInto = (canvas, width, height) => {
  const target = document.createElement('canvas')
  target.width = width
  target.height = height
  const context = target.getContext('2d')
  context.imageSmoothingEnabled = true
  context.imageSmoothingQuality = 'high'
  context.drawImage(canvas, 0, 0, width, height)
  return target
}

const exportImage = async () => {
  if (!cropper) return
  exporting.value = true
  try {
    const cropped = cropper.getCroppedCanvas({
      fillColor: format.value === 'image/jpeg' ? '#ffffff' : 'transparent',
      imageSmoothingEnabled: true,
      imageSmoothingQuality: 'high',
    })
    const canvas = resample(cropped, output.width, output.height)
    const blob = await new Promise(resolve => canvas.toBlob(resolve, format.value, quality.value))
    if (!blob) throw new Error('Export impossible (image trop grande pour le navigateur ?)')

    const extension = FORMATS.find(f => f.type === format.value).extension
    downloadBlob(blob, `${baseName(props.source.name)}-${canvas.width}x${canvas.height}.${extension}`)
    lastExport.value = { width: canvas.width, height: canvas.height, size: blob.size }
  } catch (e) {
    error.value = e.message
  } finally {
    exporting.value = false
  }
}

onMounted(initCropper)
onBeforeUnmount(destroyCropper)
</script>
