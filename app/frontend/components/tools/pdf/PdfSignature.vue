<template>
  <div>
    <h2 class="font-semibold text-gray-900 mb-4">Signer le document</h2>

    <div class="grid grid-cols-1 lg:grid-cols-[1fr_260px] gap-6">
      <!-- Page a signer, avec la signature deplacable -->
      <div>
        <div class="flex items-center justify-between mb-2 max-w-2xl">
          <button
            @click="emit('select-page', selectedPage - 1)"
            :disabled="selectedPage === 0"
            class="text-sm px-3 py-1 rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-30"
          >
            ←
          </button>
          <span class="text-sm text-gray-600">Page {{ selectedPage + 1 }} / {{ pageCount }}</span>
          <button
            @click="emit('select-page', selectedPage + 1)"
            :disabled="selectedPage >= pageCount - 1"
            class="text-sm px-3 py-1 rounded-lg border border-gray-200 text-gray-600 hover:bg-gray-50 disabled:opacity-30"
          >
            →
          </button>
        </div>

        <div
          ref="stage"
          class="relative max-w-2xl bg-gray-100 border border-gray-200 select-none touch-none"
          :style="{ aspectRatio: page.ratio }"
        >
          <img v-if="page.src" :src="page.src" alt="" class="absolute inset-0 w-full h-full" draggable="false" />
          <div v-else class="absolute inset-0 flex items-center justify-center text-sm text-gray-400">Chargement de la page...</div>

          <div
            v-if="signature"
            class="absolute cursor-move outline outline-2 outline-dashed outline-indigo-400 bg-indigo-50/10"
            :style="{
              left: `${box.x * 100}%`,
              top: `${box.y * 100}%`,
              width: `${box.width * 100}%`,
              aspectRatio: signature.width / signature.height,
            }"
            @pointerdown.prevent="startDrag($event, 'move')"
          >
            <img :src="signature.src" alt="Signature" class="w-full h-full" draggable="false" />
            <span
              class="absolute -right-2 -bottom-2 w-4 h-4 bg-indigo-500 rounded-full cursor-nwse-resize border-2 border-white"
              @pointerdown.stop.prevent="startDrag($event, 'resize')"
            ></span>
          </div>
        </div>
      </div>

      <!-- Reglages -->
      <div class="space-y-5">
        <div>
          <p class="text-sm font-medium text-gray-700 mb-2">Signature</p>
          <div class="h-20 border border-gray-200 rounded-lg flex items-center justify-center bg-gray-50 mb-2">
            <img v-if="signature" :src="signature.src" alt="Signature" class="max-h-full max-w-full object-contain p-2" />
            <span v-else-if="loadingProfile" class="text-xs text-gray-400">Chargement...</span>
            <span v-else class="text-xs text-gray-400 text-center px-2">
              Aucune signature dans
              <router-link to="/profile" class="text-indigo-600 hover:underline">Mon profil</router-link>
            </span>
          </div>
          <div class="flex flex-wrap gap-2 text-xs">
            <button @click="fileInput.click()" class="px-2 py-1 rounded bg-gray-100 text-gray-600 hover:bg-gray-200">
              Utiliser une autre image
            </button>
            <button
              v-if="profileSignature && signature?.src !== profileSignature"
              @click="useSignature(profileSignature)"
              class="px-2 py-1 rounded bg-gray-100 text-gray-600 hover:bg-gray-200"
            >
              Revenir à ma signature
            </button>
          </div>
          <input ref="fileInput" type="file" accept="image/png,image/jpeg" class="hidden" @change="onFile" />
          <p class="text-xs text-gray-400 mt-2">PNG transparent de préférence. Déplacez-la sur la page, la pastille bleue la redimensionne.</p>
        </div>

        <div>
          <p class="text-sm font-medium text-gray-700 mb-2">Pages</p>
          <label class="flex items-center gap-2 text-sm text-gray-700 mb-1">
            <input v-model="scope" type="radio" value="page" /> Cette page uniquement
          </label>
          <label class="flex items-center gap-2 text-sm text-gray-700">
            <input v-model="scope" type="radio" value="all" /> Toutes les pages (même position)
          </label>
        </div>

        <div v-if="localError" class="text-xs text-red-600">{{ localError }}</div>

        <button
          @click="submit"
          :disabled="busy || !signature"
          class="w-full text-sm px-4 py-2 rounded-lg bg-gray-900 text-white font-medium hover:bg-gray-700 disabled:opacity-50"
        >
          {{ busy ? 'Traitement...' : 'Apposer la signature' }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, watch, onMounted, onBeforeUnmount } from 'vue'
import { useApi } from '../../../composables/useApi'
import { addImage } from '../pdfOperations'
import { renderPage } from '../pdfRender'
import { readAsDataUrl } from '../files'

defineOptions({ inheritAttrs: false })

const props = defineProps({
  bytes: { type: Uint8Array, required: true },
  pageCount: { type: Number, required: true },
  preview: { type: Object, default: null },
  selectedPage: { type: Number, default: 0 },
  busy: { type: Boolean, default: false },
})

const emit = defineEmits(['apply', 'select-page'])

const { get } = useApi()

const stage = ref(null)
const fileInput = ref(null)
const page = reactive({ src: null, ratio: 210 / 297 })
const profileSignature = ref(null)
const loadingProfile = ref(true)
// { src, width, height } : dimensions naturelles pour garder les proportions
const signature = ref(null)
// Position en fractions de la page affichee (coin haut gauche + largeur)
const box = reactive({ x: 0.6, y: 0.75, width: 0.28 })
const scope = ref('page')
const localError = ref(null)

const heightFraction = () => box.width * (signature.value.height / signature.value.width) * page.ratio

const clamp = () => {
  box.width = Math.min(Math.max(box.width, 0.03), 1)
  box.x = Math.min(Math.max(box.x, 0), 1 - box.width)
  box.y = Math.min(Math.max(box.y, 0), Math.max(1 - heightFraction(), 0))
}

const useSignature = (src) => new Promise((resolve) => {
  const image = new Image()
  image.onload = () => {
    signature.value = { src, width: image.naturalWidth, height: image.naturalHeight }
    clamp()
    resolve()
  }
  image.onerror = () => {
    localError.value = 'Image illisible.'
    resolve()
  }
  image.src = src
})

const onFile = async (event) => {
  const file = event.target.files[0]
  event.target.value = ''
  if (!file) return
  localError.value = null
  if (!['image/png', 'image/jpeg'].includes(file.type)) {
    localError.value = 'Seuls les formats PNG et JPEG sont acceptés.'
    return
  }
  await useSignature(await readAsDataUrl(file))
}

// --- Deplacement / redimensionnement a la souris (ou au doigt) ---
let drag = null

const startDrag = (event, mode) => {
  const rect = stage.value.getBoundingClientRect()
  drag = { mode, startX: event.clientX, startY: event.clientY, rect, origin: { ...box } }
  window.addEventListener('pointermove', onDrag)
  window.addEventListener('pointerup', stopDrag)
}

const onDrag = (event) => {
  if (!drag) return
  const dx = (event.clientX - drag.startX) / drag.rect.width
  const dy = (event.clientY - drag.startY) / drag.rect.height
  if (drag.mode === 'move') {
    box.x = drag.origin.x + dx
    box.y = drag.origin.y + dy
  } else {
    box.width = drag.origin.width + dx
  }
  clamp()
}

const stopDrag = () => {
  drag = null
  window.removeEventListener('pointermove', onDrag)
  window.removeEventListener('pointerup', stopDrag)
}

// --- Rendu de la page choisie ---
let renderToken = 0

watch(() => [props.preview, props.selectedPage], async ([pdf, index]) => {
  const token = ++renderToken
  page.src = null
  if (!pdf) return
  try {
    const result = await renderPage(pdf, index + 1, 700)
    if (token !== renderToken) return
    Object.assign(page, result)
    if (signature.value) clamp()
  } catch {
    // apercu indisponible : la page reste grisee, la signature reste possible
  }
}, { immediate: true })

const submit = () => {
  const pageIndexes = scope.value === 'all'
    ? Array.from({ length: props.pageCount }, (_, i) => i)
    : [props.selectedPage]

  emit('apply', {
    label: scope.value === 'all' ? 'signature (toutes les pages)' : `signature p. ${props.selectedPage + 1}`,
    run: () => addImage(props.bytes, { dataUrl: signature.value.src, pageIndexes, box: { ...box } }),
  })
}

onMounted(async () => {
  try {
    const profile = await get('/personal_profile')
    profileSignature.value = profile?.signature_data_url || null
    if (profileSignature.value && !signature.value) await useSignature(profileSignature.value)
  } catch {
    profileSignature.value = null
  } finally {
    loadingProfile.value = false
  }
})

onBeforeUnmount(stopDrag)
</script>
