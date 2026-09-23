<template>
  <div>
    <h2 class="font-semibold text-gray-900 mb-4">Numéroter les pages</h2>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Position</label>
        <div class="grid grid-cols-3 gap-2 max-w-xs">
          <button
            v-for="p in NUMBER_POSITIONS"
            :key="p.value"
            @click="options.position = p.value"
            :title="p.label"
            class="h-10 rounded-lg border text-xs transition-colors"
            :class="options.position === p.value ? 'border-indigo-500 bg-indigo-50 text-indigo-700' : 'border-gray-200 text-gray-400 hover:bg-gray-50'"
          >
            {{ p.value.startsWith('top') ? '▔' : '▁' }}
          </button>
        </div>
        <p class="text-xs text-gray-400 mt-2">{{ NUMBER_POSITIONS.find(p => p.value === options.position).label }}</p>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Format</label>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="f in NUMBER_FORMATS"
            :key="f.value"
            @click="options.format = f.value"
            class="text-sm px-3 py-1.5 rounded-lg border transition-colors"
            :class="options.format === f.value ? 'border-indigo-500 bg-indigo-50 text-indigo-700' : 'border-gray-200 text-gray-600 hover:bg-gray-50'"
          >
            {{ f.label }}
          </button>
        </div>
      </div>

      <div class="grid grid-cols-3 gap-3">
        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Commencer à</span>
          <input v-model.number="options.start" type="number" min="1" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Taille</span>
          <input v-model.number="options.fontSize" type="number" min="6" max="40" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </label>
        <label class="block">
          <span class="block text-sm font-medium text-gray-700 mb-1">Marge</span>
          <input v-model.number="options.margin" type="number" min="5" max="150" class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm" />
        </label>
      </div>

      <div class="flex flex-col gap-3 justify-center">
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input v-model="options.skipFirst" type="checkbox" class="rounded border-gray-300" />
          Ne pas numéroter la première page (couverture)
        </label>
        <label class="flex items-center gap-2 text-sm text-gray-700">
          <input v-model="options.color" type="color" class="h-8 w-10 rounded border border-gray-200" />
          Couleur
        </label>
      </div>
    </div>

    <div class="mt-6 flex justify-end">
      <button
        @click="submit"
        :disabled="busy"
        class="text-sm px-4 py-2 rounded-lg bg-gray-900 text-white font-medium hover:bg-gray-700 disabled:opacity-50"
      >
        {{ busy ? 'Traitement...' : 'Numéroter' }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { reactive } from 'vue'
import { addPageNumbers, NUMBER_POSITIONS, NUMBER_FORMATS } from '../pdfOperations'

// Les autres outils recoivent aussi l'apercu, la page choisie... : pas en attributs HTML.
defineOptions({ inheritAttrs: false })

const props = defineProps({
  bytes: { type: Uint8Array, required: true },
  busy: { type: Boolean, default: false },
})

const emit = defineEmits(['apply'])

const options = reactive({
  position: 'bottom-center',
  format: '{n} / {total}',
  start: 1,
  fontSize: 10,
  margin: 28,
  skipFirst: false,
  color: '#333333',
})

const submit = () => {
  emit('apply', {
    label: 'numérotation',
    run: () => addPageNumbers(props.bytes, { ...options, start: options.start || 1 }),
  })
}
</script>
