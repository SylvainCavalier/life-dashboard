<template>
  <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="$emit('close')">
    <div class="bg-white rounded-xl shadow-xl w-full max-h-[90vh] overflow-y-auto m-4 p-6" :class="maxWidthClass">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-lg font-bold text-gray-900">{{ title }}</h2>
        <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
        </button>
      </div>
      <slot />
    </div>
  </div>
</template>

<script setup>
defineProps({
  title: { type: String, default: '' },
  maxWidthClass: { type: String, default: 'max-w-3xl' },
})
defineEmits(['close'])
</script>
