<template>
  <select
    :value="modelValue ?? ''"
    class="w-full border rounded-lg px-3 py-2 text-sm bg-white"
    @change="$emit('update:modelValue', $event.target.value ? Number($event.target.value) : null)"
  >
    <option value="">{{ placeholder }}</option>
    <optgroup v-if="active.length" label="Projets en cours">
      <option v-for="p in active" :key="p.id" :value="p.id">{{ p.name }}</option>
    </optgroup>
    <optgroup v-if="others.length" label="Autres projets">
      <option v-for="p in others" :key="p.id" :value="p.id">{{ p.name }}</option>
    </optgroup>
  </select>
</template>

<script>
// Requete partagee par les listes ouvertes en meme temps, renouvelee apres une minute
// (un projet cree entre-temps apparait sans recharger la page).
let cache = null
let cachedAt = 0
</script>

<script setup>
// Choix du projet d'un rendez-vous ou d'une reunion : son journal de bord le consignera.
import { ref, computed, onMounted } from 'vue'
import apiClient from '../../plugins/axios'

defineProps({
  modelValue: { type: Number, default: null },
  placeholder: { type: String, default: '— Aucun projet —' },
})
defineEmits(['update:modelValue'])

const projects = ref([])

const ACTIVE = ['en_cours', 'en_attente']
const byName = (a, b) => a.name.localeCompare(b.name, 'fr')
const active = computed(() => projects.value.filter(p => ACTIVE.includes(p.status)).sort(byName))
const others = computed(() => projects.value.filter(p => !ACTIVE.includes(p.status)).sort(byName))

onMounted(async () => {
  try {
    if (!cache || Date.now() - cachedAt > 60_000) {
      cachedAt = Date.now()
      cache = apiClient.get('/projects').then(({ data }) => data.map(({ id, name, status }) => ({ id, name, status })))
    }
    projects.value = await cache
  } catch {
    cache = null
    projects.value = []
  }
})
</script>
