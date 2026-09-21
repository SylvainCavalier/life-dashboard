<template>
  <BaseModal :title="`Sources · ${domain.label}`" max-width-class="max-w-4xl" @close="$emit('close')">
    <p class="text-sm text-gray-500 -mt-3 mb-5">
      Une source se collecte par son flux RSS, par la recherche web restreinte à son site, ou par un adaptateur dédié (API officielle).
      Une source « spécialisée » est retenue en entier ; une source généraliste est filtrée par mots-clés avant tout résumé.
    </p>

    <div v-if="loading" class="text-center text-gray-400 py-8">Chargement...</div>

    <div v-else class="space-y-2 mb-6">
      <div v-for="source in sources" :key="source.id" class="border border-gray-100 rounded-lg px-4 py-3" :class="{ 'opacity-50': !source.active }">
        <div class="flex flex-wrap items-center gap-2">
          <a v-if="source.url" :href="source.url" target="_blank" rel="noopener noreferrer" class="font-medium text-gray-900 hover:text-indigo-600">{{ source.name }}</a>
          <span v-else class="font-medium text-gray-900">{{ source.name }}</span>

          <span v-for="channel in source.channels" :key="channel" class="text-xs px-2 py-0.5 rounded-full bg-gray-100 text-gray-600">{{ channelLabel(channel) }}</span>
          <span v-if="source.on_topic" class="text-xs px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-700">Spécialisée</span>
          <span class="text-xs uppercase text-gray-400">{{ source.language }}</span>

          <div class="ml-auto flex items-center gap-3 text-sm">
            <button @click="toggle(source)" class="text-gray-500 hover:text-gray-800">{{ source.active ? 'Désactiver' : 'Activer' }}</button>
            <button v-if="!source.adapter" @click="edit(source)" class="text-indigo-600 hover:underline">Modifier</button>
            <button @click="destroy(source)" class="text-red-500 hover:underline">Supprimer</button>
          </div>
        </div>

        <p v-if="source.last_error" class="text-xs text-red-600 mt-1">Dernière collecte : {{ source.last_error }}</p>
        <p v-else-if="source.last_collected_at" class="text-xs text-gray-400 mt-1">
          Dernière collecte le {{ formatDateTime(source.last_collected_at) }} : {{ source.last_documents_count }} nouveau{{ source.last_documents_count > 1 ? 'x' : '' }} document{{ source.last_documents_count > 1 ? 's' : '' }}
        </p>
      </div>

      <div v-if="!sources.length" class="text-center text-gray-400 py-8">Aucune source pour ce domaine</div>
    </div>

    <form @submit.prevent="save" class="bg-gray-50 rounded-lg p-4">
      <h3 class="text-sm font-semibold text-gray-900 mb-3">{{ form.id ? `Modifier « ${form.name} »` : 'Ajouter une source' }}</h3>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <input v-model="form.name" type="text" placeholder="Nom" required class="field" />
        <input v-model="form.url" type="url" placeholder="Adresse du site (https://...)" class="field" />
        <input v-model="form.feed_url" type="url" placeholder="Flux RSS ou Atom (facultatif)" class="field" />
        <select v-model="form.language" class="field">
          <option value="fr">Français</option>
          <option value="en">Anglais</option>
          <option value="es">Espagnol</option>
        </select>
      </div>

      <div class="flex flex-wrap gap-5 mt-3 text-sm text-gray-600">
        <label class="flex items-center gap-2">
          <input v-model="form.web_search" type="checkbox" class="rounded border-gray-300" /> Recherche web sur ce site
        </label>
        <label class="flex items-center gap-2">
          <input v-model="form.on_topic" type="checkbox" class="rounded border-gray-300" /> Source spécialisée (tout retenir)
        </label>
      </div>

      <p v-if="errors.length" class="text-sm text-red-600 mt-3">{{ errors.join(' · ') }}</p>

      <div class="flex items-center gap-3 mt-4">
        <button type="submit" :disabled="saving" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40">
          {{ form.id ? 'Enregistrer' : 'Ajouter' }}
        </button>
        <button v-if="form.id" type="button" @click="resetForm" class="text-sm text-gray-500 hover:text-gray-700">Annuler</button>
        <button type="button" @click="restoreDefaults" class="ml-auto text-sm text-gray-500 hover:text-gray-700">
          Restaurer les sources par défaut
        </button>
      </div>
    </form>
  </BaseModal>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { formatDateTime } from '../../composables/useSentinel'
import BaseModal from '../companies/BaseModal.vue'

const props = defineProps({
  domain: { type: Object, required: true },
})
const emit = defineEmits(['close', 'changed'])

const { get, post, patch, delete: del } = useApi()

const sources = ref([])
const loading = ref(true)
const saving = ref(false)
const errors = ref([])

const blank = () => ({ id: null, name: '', url: '', feed_url: '', language: 'fr', web_search: true, on_topic: false })
const form = reactive(blank())

const basePath = `/sentinel_domains/${props.domain.key}/sources`
const channelLabel = (channel) => ({ api: 'API', rss: 'RSS', web: 'Recherche web' }[channel] || channel)

const fetchSources = async () => {
  sources.value = await get(basePath)
  loading.value = false
}

const resetForm = () => {
  Object.assign(form, blank())
  errors.value = []
}

const edit = (source) => {
  Object.assign(form, {
    id: source.id, name: source.name, url: source.url || '', feed_url: source.feed_url || '',
    language: source.language, web_search: source.web_search, on_topic: source.on_topic,
  })
  errors.value = []
}

const save = async () => {
  saving.value = true
  errors.value = []
  const { id, ...attributes } = form
  try {
    if (id) {
      await patch(`/sentinel_sources/${id}`, { sentinel_source: attributes })
    } else {
      await post(basePath, { sentinel_source: attributes })
    }
    resetForm()
    await fetchSources()
    emit('changed')
  } catch (e) {
    errors.value = e.response?.data?.errors || ['Une erreur est survenue']
  } finally {
    saving.value = false
  }
}

const toggle = async (source) => {
  await patch(`/sentinel_sources/${source.id}`, { sentinel_source: { active: !source.active } })
  await fetchSources()
  emit('changed')
}

const destroy = async (source) => {
  if (!confirm(`Supprimer « ${source.name} » ? Les documents déjà collectés depuis cette source seront supprimés aussi.`)) return
  await del(`/sentinel_sources/${source.id}`)
  await fetchSources()
  emit('changed')
}

const restoreDefaults = async () => {
  sources.value = await post(`${basePath}/restore_defaults`)
  emit('changed')
}

onMounted(fetchSources)
</script>

<style scoped>
.field {
  @apply text-sm border border-gray-200 rounded-lg px-3 py-2 bg-white text-gray-700 w-full;
}
</style>
