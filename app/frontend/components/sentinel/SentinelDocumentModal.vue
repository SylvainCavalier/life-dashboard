<template>
  <BaseModal :title="doc ? (doc.display_title || doc.title) : 'Document'" max-width-class="max-w-3xl" @close="$emit('close')">
    <div v-if="!doc" class="text-center text-gray-400 py-12">Chargement...</div>

    <template v-else>
      <p v-if="doc.display_title" class="text-sm text-gray-400 -mt-4 mb-4">{{ doc.title }}</p>

      <div class="flex flex-wrap items-center gap-2 text-xs text-gray-500 mb-5">
        <span v-if="doc.relevant" class="px-2 py-0.5 rounded-full font-medium" :class="importanceBadge(doc.importance)">
          {{ importanceLabel(doc.importance) }}
        </span>
        <span v-else class="px-2 py-0.5 rounded-full font-medium bg-gray-100 text-gray-500">Hors champ</span>
        <span class="px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">{{ domain?.kinds?.[doc.kind] || doc.kind }}</span>
        <span>{{ doc.source_name }}</span>
        <span v-if="doc.published_at">· {{ formatDateTime(doc.published_at) }}</span>
        <span v-if="doc.author">· {{ doc.author }}</span>
        <a v-if="doc.url" :href="doc.url" target="_blank" rel="noopener noreferrer" class="ml-auto text-indigo-600 hover:underline">
          Voir la source ↗
        </a>
      </div>

      <div class="flex border-b mb-5">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          @click="activeTab = tab.key"
          class="px-4 py-2 text-sm font-medium transition-colors"
          :class="activeTab === tab.key ? 'text-indigo-600 border-b-2 border-indigo-600' : 'text-gray-500 hover:text-gray-700'"
        >
          {{ tab.label }}
        </button>
      </div>

      <div v-show="activeTab === 'summary'">
        <template v-if="doc.summarized">
          <p class="text-gray-700 leading-relaxed">{{ doc.tldr }}</p>
          <ol v-if="doc.key_points.length" class="mt-4 space-y-2 list-decimal list-inside text-sm text-gray-700">
            <li v-for="point in doc.key_points" :key="point">{{ point }}</li>
          </ol>
          <div v-if="doc.categories.length" class="flex flex-wrap gap-1.5 mt-4">
            <span v-for="slug in doc.categories" :key="slug" class="text-xs px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700">
              {{ domain?.categories?.[slug] || slug }}
            </span>
          </div>
          <p class="text-xs text-gray-400 mt-5">Résumé généré par {{ doc.summary_model }}</p>
        </template>
        <p v-else-if="doc.relevant" class="text-sm text-gray-400">Pas encore de résumé : relancer la veille de la semaine.</p>
        <p v-else class="text-sm text-gray-400">
          Document écarté par le tri automatique ({{ doc.relevance_reason }}) : il n'est ni résumé ni conservé en texte intégral.
        </p>
      </div>

      <div v-show="activeTab === 'content'">
        <pre v-if="doc.raw_content" class="whitespace-pre-wrap font-sans text-sm text-gray-700 leading-relaxed">{{ doc.raw_content }}</pre>
        <p v-else class="text-sm text-gray-400">Texte non conservé.</p>
      </div>
    </template>
  </BaseModal>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { importanceLabel, importanceBadge, formatDateTime } from '../../composables/useSentinel'
import BaseModal from '../companies/BaseModal.vue'

const props = defineProps({
  documentId: { type: Number, required: true },
  domain: { type: Object, default: null },
})
defineEmits(['close'])

const { get } = useApi()
const doc = ref(null)
const activeTab = ref('summary')
const tabs = [
  { key: 'summary', label: 'Résumé IA' },
  { key: 'content', label: 'Texte collecté' },
]

onMounted(async () => {
  doc.value = await get(`/sentinel_documents/${props.documentId}`)
})
</script>
