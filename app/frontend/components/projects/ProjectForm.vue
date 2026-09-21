<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <h2 class="text-lg font-semibold mb-4">{{ initial ? 'Modifier le projet' : 'Nouveau projet' }}</h2>

    <ul v-if="errors.length" class="mb-4 text-sm text-red-600 list-disc list-inside">
      <li v-for="error in errors" :key="error">{{ error }}</li>
    </ul>

    <form @submit.prevent="submit">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Nom du projet *</label>
          <input v-model="form.name" type="text" required class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="Mon super projet" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Catégorie</label>
          <select v-model="form.category" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="c in projectCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Statut</label>
          <select v-model="form.status" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option v-for="s in projectStatuses" :key="s.value" :value="s.value">{{ s.label }}</option>
          </select>
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Importance</label>
          <div class="flex items-center gap-1 h-[38px]">
            <button
              v-for="star in 5"
              :key="star"
              type="button"
              @click="form.priority = form.priority === star ? 0 : star"
              class="text-2xl leading-none"
              :class="star <= form.priority ? 'text-yellow-400' : 'text-gray-300'"
            >
              ★
            </button>
          </div>
        </div>
        <div class="md:col-span-2">
          <label class="block text-sm font-medium text-gray-700 mb-1">Avancement (%)</label>
          <div class="flex items-center gap-3">
            <input v-model.number="form.progress" type="range" min="0" max="100" step="5" class="flex-1" />
            <span class="text-sm font-medium text-gray-700 w-10 text-right">{{ form.progress }}%</span>
          </div>
        </div>
        <div v-if="showGithub">
          <label class="block text-sm font-medium text-gray-700 mb-1">Lien GitHub</label>
          <input v-model="form.github_url" type="url" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="https://github.com/..." />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Lien principal (site, chaîne, page...)</label>
          <input v-model="form.site_url" type="url" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="https://..." />
        </div>
      </div>
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
        <textarea v-model="form.description" rows="2" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="L'objectif du projet en quelques mots..."></textarea>
      </div>
      <div class="flex justify-end gap-2">
        <button type="button" @click="$emit('cancel')" class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2">Annuler</button>
        <button type="submit" :disabled="saving" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-50">
          {{ initial ? 'Enregistrer' : 'Ajouter' }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue'
import { projectCategories, projectStatuses } from '../../composables/useProjects'

const props = defineProps({
  initial: { type: Object, default: null },
  defaultCategory: { type: String, default: 'developpement' },
  saving: { type: Boolean, default: false },
  errors: { type: Array, default: () => [] },
})
const emit = defineEmits(['submit', 'cancel'])

const form = ref({
  name: props.initial?.name || '',
  category: props.initial?.category || props.defaultCategory,
  status: props.initial?.status || 'en_cours',
  priority: props.initial?.priority || 0,
  progress: props.initial?.progress || 0,
  github_url: props.initial?.github_url || '',
  site_url: props.initial?.site_url || '',
  description: props.initial?.description || '',
})

// Le depot GitHub n'a de sens que pour du code, sauf s'il est deja renseigne.
const showGithub = computed(() =>
  ['developpement', 'jeu_video'].includes(form.value.category) || !!form.value.github_url
)

const submit = () => {
  if (!form.value.name.trim()) return
  emit('submit', { ...form.value, name: form.value.name.trim() })
}
</script>
