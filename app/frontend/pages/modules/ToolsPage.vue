<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">← Retour au dashboard</router-link>

      <div class="flex items-center gap-3 mb-6">
        <span class="text-3xl">🧰</span>
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Outils</h1>
          <p class="text-sm text-gray-400">Petits utilitaires, tout se passe dans le navigateur</p>
        </div>
      </div>

      <div class="flex border-b border-gray-200 mb-6 overflow-x-auto">
        <router-link
          v-for="t in TABS"
          :key="t.key"
          :to="`/tools/${t.key}`"
          class="px-5 py-3 text-sm font-medium whitespace-nowrap transition-colors"
          :class="t.key === current.key
            ? 'text-indigo-600 border-b-2 border-indigo-600'
            : 'text-gray-500 hover:text-gray-700'"
        >
          <span class="mr-1">{{ t.icon }}</span>{{ t.label }}
        </router-link>
      </div>

      <!-- KeepAlive : passer d'un onglet a l'autre ne perd pas le fichier en cours -->
      <KeepAlive>
        <component :is="current.component" :key="current.key" />
      </KeepAlive>
    </div>
  </div>
</template>

<script setup>
import { computed, defineAsyncComponent } from 'vue'

const props = defineProps({
  tab: { type: String, default: null },
})

// Un onglet = une entree ici : ajouter un outil ne touche pas aux autres.
const TABS = [
  { key: 'pdf', label: 'PDF', icon: '📄', component: defineAsyncComponent(() => import('../../components/tools/PdfTool.vue')) },
  { key: 'images', label: 'Images', icon: '🖼️', component: defineAsyncComponent(() => import('../../components/tools/ImageTool.vue')) },
]

const current = computed(() => TABS.find(t => t.key === props.tab) || TABS[0])
</script>
