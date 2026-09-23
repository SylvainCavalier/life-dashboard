<template>
  <div>
    <FileDropZone
      v-if="!bytes"
      accept="application/pdf,.pdf"
      icon="📄"
      label="Cliquez ou glissez un PDF ici"
      hint="Numérotation, filigrane, signature, découpage"
      @file="loadFile"
    />

    <template v-else>
      <!-- Fichier en cours -->
      <div class="bg-white rounded-xl shadow-sm p-4 mb-4 flex flex-wrap items-center gap-4">
        <div class="min-w-0 flex-1">
          <p class="font-semibold text-gray-900 truncate">{{ fileName }}</p>
          <p class="text-xs text-gray-400">
            {{ pageCount }} page{{ pageCount > 1 ? 's' : '' }} · {{ humanSize(bytes.length) }}
            <template v-if="history.length"> · {{ history.map(h => h.label).join(', ') }}</template>
          </p>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <button
            v-if="history.length"
            @click="undo"
            :disabled="busy"
            class="text-sm px-3 py-2 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            Annuler « {{ history[history.length - 1].label }} »
          </button>
          <button
            @click="reset"
            :disabled="busy"
            class="text-sm px-3 py-2 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50 disabled:opacity-50"
          >
            Autre fichier
          </button>
          <button
            @click="downloadCurrent"
            :disabled="busy"
            class="text-sm px-4 py-2 rounded-lg bg-indigo-600 text-white font-medium hover:bg-indigo-700 disabled:opacity-50"
          >
            Télécharger le PDF
          </button>
        </div>
      </div>

      <!-- Choix de l'outil -->
      <div class="flex flex-wrap gap-2 mb-4">
        <button
          v-for="tool in TOOLS"
          :key="tool.key"
          @click="activeTool = tool.key"
          class="text-sm px-4 py-2 rounded-lg transition-colors"
          :class="activeTool === tool.key ? 'bg-gray-900 text-white' : 'bg-white text-gray-600 shadow-sm hover:bg-gray-100'"
        >
          <span class="mr-1">{{ tool.icon }}</span>{{ tool.label }}
        </button>
      </div>

      <div v-if="error" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mb-4">{{ error }}</div>

      <div class="bg-white rounded-xl shadow-sm p-5 mb-6 relative">
        <component
          :is="currentTool.component"
          :bytes="bytes"
          :page-count="pageCount"
          :preview="preview"
          :selected-page="selectedPage"
          :file-base="baseName(fileName)"
          :busy="busy"
          @apply="apply"
          @select-page="selectedPage = $event"
        />
      </div>

      <!-- Vignettes -->
      <div>
        <p class="text-xs text-gray-400 mb-2">
          Aperçu du document
          <template v-if="activeTool === 'signature'"> · cliquez sur une page pour la signer</template>
        </p>
        <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 lg:grid-cols-8 gap-3">
          <button
            v-for="(thumb, index) in thumbnails"
            :key="index"
            @click="selectedPage = index"
            class="group text-left"
          >
            <div
              class="bg-white rounded shadow-sm overflow-hidden ring-2 transition"
              :class="index === selectedPage && activeTool === 'signature' ? 'ring-indigo-500' : 'ring-transparent group-hover:ring-gray-200'"
            >
              <img v-if="thumb" :src="thumb" :alt="`Page ${index + 1}`" class="w-full block" />
              <div v-else class="aspect-[3/4] bg-gray-100 animate-pulse"></div>
            </div>
            <p class="text-xs text-gray-400 text-center mt-1">{{ index + 1 }}</p>
          </button>
        </div>
      </div>
    </template>

    <div v-if="!bytes && error" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mt-4">{{ error }}</div>
  </div>
</template>

<script setup>
import { ref, shallowRef, computed, markRaw, onBeforeUnmount } from 'vue'
import FileDropZone from './FileDropZone.vue'
import PdfNumbering from './pdf/PdfNumbering.vue'
import PdfWatermark from './pdf/PdfWatermark.vue'
import PdfSignature from './pdf/PdfSignature.vue'
import PdfSplit from './pdf/PdfSplit.vue'
import { loadPdf } from './pdfOperations'
import { openPdfPreview, renderPage } from './pdfRender'
import { downloadPdf, baseName, humanSize } from './files'

const TOOLS = [
  { key: 'numbers', label: 'Numéroter les pages', icon: '🔢', component: PdfNumbering },
  { key: 'watermark', label: 'Filigrane', icon: '💧', component: PdfWatermark },
  { key: 'signature', label: 'Signer', icon: '✍️', component: PdfSignature },
  { key: 'split', label: 'Diviser', icon: '✂️', component: PdfSplit },
]

const THUMB_WIDTH = 160

const fileName = ref('')
// Octets du PDF courant ; chaque modification empile la version precedente.
const bytes = shallowRef(null)
const history = ref([])
const pageCount = ref(0)
const preview = shallowRef(null)
const thumbnails = ref([])
const selectedPage = ref(0)
const activeTool = ref('numbers')
const busy = ref(false)
const error = ref(null)

const currentTool = computed(() => TOOLS.find(t => t.key === activeTool.value))

// Jeton de rendu : un rendu de vignettes perime (document modifie entre-temps) s'arrete.
let renderToken = 0

const refreshPreview = async () => {
  const token = ++renderToken
  preview.value?.destroy()
  preview.value = null
  thumbnails.value = Array(pageCount.value).fill(null)

  const pdf = markRaw(await openPdfPreview(bytes.value))
  if (token !== renderToken) return pdf.destroy()
  preview.value = pdf

  for (let number = 1; number <= pdf.numPages; number++) {
    try {
      const { src } = await renderPage(pdf, number, THUMB_WIDTH)
      if (token !== renderToken) return
      thumbnails.value[number - 1] = src
    } catch {
      if (token !== renderToken) return
    }
  }
}

const setDocument = async (newBytes) => {
  const doc = await loadPdf(newBytes)
  bytes.value = markRaw(newBytes)
  pageCount.value = doc.getPageCount()
  selectedPage.value = Math.min(selectedPage.value, pageCount.value - 1)
  refreshPreview()
}

const loadFile = async (file) => {
  error.value = null
  if (file.type !== 'application/pdf' && !/\.pdf$/i.test(file.name)) {
    error.value = 'Ce fichier n\'est pas un PDF.'
    return
  }
  try {
    busy.value = true
    const data = new Uint8Array(await file.arrayBuffer())
    history.value = []
    selectedPage.value = 0
    await setDocument(data)
    fileName.value = file.name
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

// Les outils emettent { label, run } : run() produit les octets du nouveau PDF.
const apply = async ({ label, run }) => {
  error.value = null
  busy.value = true
  try {
    const previous = bytes.value
    const result = await run()
    await setDocument(result)
    history.value.push({ label, bytes: markRaw(previous) })
  } catch (e) {
    error.value = e.message
  } finally {
    busy.value = false
  }
}

const undo = async () => {
  const last = history.value.pop()
  if (last) await setDocument(last.bytes)
}

const reset = () => {
  renderToken++
  preview.value?.destroy()
  preview.value = null
  bytes.value = null
  history.value = []
  thumbnails.value = []
  pageCount.value = 0
  error.value = null
}

const downloadCurrent = () => {
  const suffix = history.value.length ? '-modifie' : ''
  downloadPdf(bytes.value, `${baseName(fileName.value)}${suffix}.pdf`)
}

onBeforeUnmount(() => {
  renderToken++
  preview.value?.destroy()
})
</script>
