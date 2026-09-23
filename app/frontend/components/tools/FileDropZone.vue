<template>
  <div
    class="border-2 border-dashed rounded-xl p-12 text-center cursor-pointer transition-colors bg-white"
    :class="dragging ? 'border-indigo-400 bg-indigo-50' : 'border-gray-200 hover:border-indigo-300'"
    @click="input.click()"
    @dragover.prevent="dragging = true"
    @dragleave.prevent="dragging = false"
    @drop.prevent="onDrop"
  >
    <div class="text-4xl mb-3">{{ icon }}</div>
    <p class="text-sm text-gray-700 font-medium">{{ label }}</p>
    <p class="text-xs text-gray-400 mt-1">{{ hint }}</p>
    <p class="text-xs text-gray-400 mt-3">Traitement dans le navigateur : le fichier n'est envoyé nulle part.</p>
    <input ref="input" type="file" :accept="accept" class="hidden" @change="onSelect" />
  </div>
</template>

<script setup>
import { ref } from 'vue'

defineProps({
  accept: { type: String, required: true },
  icon: { type: String, default: '📂' },
  label: { type: String, default: 'Cliquez ou glissez un fichier ici' },
  hint: { type: String, default: '' },
})

const emit = defineEmits(['file'])

const input = ref(null)
const dragging = ref(false)

const onSelect = (event) => {
  const file = event.target.files[0]
  if (file) emit('file', file)
  event.target.value = ''
}

const onDrop = (event) => {
  dragging.value = false
  const file = event.dataTransfer.files[0]
  if (file) emit('file', file)
}
</script>
