<template>
  <div>
    <h2 class="font-semibold text-gray-900 mb-4">Diviser le PDF</h2>

    <div class="space-y-3">
      <label class="flex items-center gap-2 text-sm text-gray-700">
        <input v-model="mode" type="radio" value="ranges" />
        Selon des plages
        <input
          v-model="rangesInput"
          @focus="mode = 'ranges'"
          type="text"
          placeholder="1-3, 4-10, 11-"
          class="ml-2 border border-gray-200 rounded-lg px-3 py-1.5 text-sm w-56"
        />
      </label>
      <label class="flex items-center gap-2 text-sm text-gray-700">
        <input v-model="mode" type="radio" value="every" />
        Toutes les
        <input
          v-model.number="every"
          @focus="mode = 'every'"
          type="number"
          min="1"
          :max="pageCount"
          class="border border-gray-200 rounded-lg px-3 py-1.5 text-sm w-20"
        />
        pages
      </label>
      <label class="flex items-center gap-2 text-sm text-gray-700">
        <input v-model="mode" type="radio" value="single" />
        Une page par fichier ({{ pageCount }} fichiers)
      </label>
      <p class="text-xs text-gray-400">
        Une plage ouverte (« 11- ») va jusqu'à la fin. Une plage peut aussi servir à extraire quelques pages : « 2-4 » seul donne un fichier des pages 2 à 4.
        Les modifications déjà appliquées (numérotation, signature...) sont conservées dans les parties.
      </p>
    </div>

    <div v-if="localError" class="text-sm text-red-600 mt-3">{{ localError }}</div>

    <div class="mt-4 flex justify-end">
      <button
        @click="submit"
        :disabled="working"
        class="text-sm px-4 py-2 rounded-lg bg-gray-900 text-white font-medium hover:bg-gray-700 disabled:opacity-50"
      >
        {{ working ? 'Découpage...' : 'Diviser' }}
      </button>
    </div>

    <div v-if="parts.length" class="mt-6 border-t border-gray-100 pt-4">
      <div class="flex items-center justify-between mb-3">
        <p class="text-sm font-medium text-gray-700">{{ parts.length }} fichier{{ parts.length > 1 ? 's' : '' }}</p>
        <button v-if="parts.length > 1" @click="downloadAll" class="text-sm text-indigo-600 hover:underline">Tout télécharger</button>
      </div>
      <ul class="divide-y divide-gray-100">
        <li v-for="(part, index) in parts" :key="index" class="flex items-center justify-between py-2 text-sm">
          <span class="text-gray-700">{{ part.label }} <span class="text-gray-400">· {{ humanSize(part.bytes.length) }}</span></span>
          <button @click="download(part)" class="text-indigo-600 hover:underline">Télécharger</button>
        </li>
      </ul>
    </div>
  </div>
</template>

<script setup>
import { ref, shallowRef, watch } from 'vue'
import { splitPdf, parseRanges, rangesEvery } from '../pdfOperations'
import { downloadPdf, humanSize } from '../files'

defineOptions({ inheritAttrs: false })

const props = defineProps({
  bytes: { type: Uint8Array, required: true },
  pageCount: { type: Number, required: true },
  fileBase: { type: String, required: true },
})

const mode = ref('ranges')
const rangesInput = ref('')
const every = ref(1)
const parts = shallowRef([])
const working = ref(false)
const localError = ref(null)

// Le decoupage porte sur une version du document : il devient caduc si elle change.
watch(() => props.bytes, () => { parts.value = [] })

const submit = async () => {
  localError.value = null
  working.value = true
  try {
    const ranges = mode.value === 'ranges' ? parseRanges(rangesInput.value, props.pageCount)
      : rangesEvery(mode.value === 'every' ? Math.max(1, every.value || 1) : 1, props.pageCount)
    parts.value = await splitPdf(props.bytes, ranges)
  } catch (e) {
    localError.value = e.message
  } finally {
    working.value = false
  }
}

const download = (part) => downloadPdf(part.bytes, `${props.fileBase}-${part.suffix}.pdf`)

// Le navigateur demande une fois l'autorisation des telechargements multiples.
const downloadAll = async () => {
  for (const part of parts.value) {
    download(part)
    await new Promise(resolve => setTimeout(resolve, 300))
  }
}
</script>
