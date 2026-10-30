<template>
  <form @submit.prevent="submit" class="bg-white rounded-xl shadow-sm p-4 space-y-3">
    <h2 class="text-sm font-semibold text-gray-900">{{ initial ? 'Modifier le dossier' : 'Nouvelle chaîne ou compte' }}</h2>

    <ul v-if="errors.length" class="text-xs text-red-600 list-disc list-inside">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>

    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">Nom *</label>
      <input v-model="form.name" type="text" required maxlength="100" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Debunker des Étoiles, compte X perso..." />
    </div>
    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">Plateforme</label>
      <select v-model="form.platform" class="w-full border rounded-lg px-3 py-2 text-sm">
        <option v-for="p in platforms" :key="p.value" :value="p.value">{{ p.icon }} {{ p.label }}</option>
      </select>
    </div>
    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">Identifiant</label>
      <input v-model="form.handle" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="@moncompte" />
    </div>
    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">Lien</label>
      <input v-model="form.url" type="url" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="https://www.youtube.com/@..." />
    </div>
    <div>
      <label class="block text-xs font-medium text-gray-600 mb-1">Ligne éditoriale</label>
      <textarea v-model="form.description" rows="3" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Public, ton, formats, thèmes..."></textarea>
    </div>

    <div class="flex justify-end gap-2">
      <button type="button" @click="$emit('cancel')" class="text-sm px-3 py-1.5 rounded-lg text-gray-600 hover:bg-gray-100">Annuler</button>
      <button type="submit" :disabled="saving" class="text-sm px-3 py-1.5 rounded-lg bg-black text-white hover:bg-gray-800 disabled:opacity-50">
        {{ saving ? 'Enregistrement...' : 'Enregistrer' }}
      </button>
    </div>
  </form>
</template>

<script setup>
import { reactive } from 'vue'
import { platforms } from '../../composables/useScripts'

const props = defineProps({
  initial: { type: Object, default: null },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})
const emit = defineEmits(['submit', 'cancel'])

const form = reactive({
  name: props.initial?.name || '',
  platform: props.initial?.platform || 'youtube',
  handle: props.initial?.handle || '',
  url: props.initial?.url || '',
  description: props.initial?.description || '',
})

const submit = () => emit('submit', { ...form })
</script>
