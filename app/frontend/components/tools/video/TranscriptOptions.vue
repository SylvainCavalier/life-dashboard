<template>
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Titre</label>
      <input
        :value="title"
        type="text"
        class="w-full border rounded-lg px-3 py-2 text-sm"
        placeholder="Titre de la vidéo"
        @input="$emit('update:title', $event.target.value)"
      />
    </div>
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-1">Langue de la vidéo</label>
      <select
        :value="language"
        class="w-full border rounded-lg px-3 py-2 text-sm bg-white"
        @change="$emit('update:language', $event.target.value)"
      >
        <option v-for="l in languages" :key="l.code" :value="l.code">{{ l.label }}</option>
      </select>
      <p class="text-xs text-gray-400 mt-1">La transcription reste dans la langue de la vidéo ; le résumé est toujours en français.</p>
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, required: true },
  language: { type: String, required: true },
  languages: { type: Array, required: true },
})

defineEmits(['update:title', 'update:language'])
</script>
