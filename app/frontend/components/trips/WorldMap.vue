<template>
  <div class="bg-white rounded-xl shadow-sm p-4">
    <div class="flex items-center justify-between mb-2">
      <h2 class="text-sm font-semibold text-gray-700">Carte des voyages</h2>
      <div class="flex items-center gap-4 text-xs text-gray-500">
        <span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded-sm bg-indigo-600"></span> Visité ({{ visited.length }})</span>
        <span class="flex items-center gap-1"><span class="inline-block w-3 h-3 rounded-sm bg-indigo-300"></span> Prévu ({{ planned.length }})</span>
      </div>
    </div>
    <!-- Carte : @svg-maps/world (Victor Cazanave, CC BY 4.0) -->
    <svg :viewBox="world.viewBox" class="w-full h-auto" role="img" aria-label="Carte du monde des pays visités">
      <path
        v-for="location in world.locations"
        :key="location.id"
        :d="location.path"
        :class="classFor(location.id)"
        class="stroke-white cursor-pointer transition-colors"
        stroke-width="0.4"
        @click="emit('select', location.id)"
      >
        <title>{{ countryName(location.id) }}</title>
      </path>
    </svg>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useCountries } from '../../composables/useCountries'

const props = defineProps({
  visited: { type: Array, default: () => [] },
  planned: { type: Array, default: () => [] },
  selected: { type: String, default: null },
})
const emit = defineEmits(['select'])

const { world, countryName } = useCountries()

const visitedSet = computed(() => new Set(props.visited))
const plannedSet = computed(() => new Set(props.planned))

const classFor = (code) => {
  if (visitedSet.value.has(code)) return 'fill-indigo-600 hover:fill-indigo-700'
  if (plannedSet.value.has(code)) return 'fill-indigo-300 hover:fill-indigo-400'
  if (props.selected === code) return 'fill-amber-400'
  return 'fill-gray-200 hover:fill-gray-300'
}
</script>
