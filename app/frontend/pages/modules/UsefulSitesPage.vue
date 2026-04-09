<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <!-- Retour -->
      <router-link
        to="/"
        class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6"
      >
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour au dashboard
      </router-link>

      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">🔗</span>
            <h1 class="text-2xl font-bold text-gray-900">Sites utiles</h1>
            <span class="text-sm text-gray-400">({{ filteredSites.length }})</span>
          </div>
          <button
            @click="openForm()"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showForm ? 'Annuler' : '+ Ajouter' }}
          </button>
        </div>

        <!-- Filtre par categorie -->
        <div v-if="sites.length > 0" class="flex flex-wrap gap-2 mb-6">
          <button
            @click="filterCategory = ''"
            :class="filterCategory === '' ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            Tous
          </button>
          <button
            v-for="cat in usedCategories"
            :key="cat"
            @click="filterCategory = cat"
            :class="filterCategory === cat ? 'bg-indigo-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'"
            class="px-3 py-1 rounded-full text-xs font-medium transition-colors"
          >
            {{ categoryLabel(cat) }}
            <span class="ml-1 opacity-70">({{ categoryCount(cat) }})</span>
          </button>
        </div>

        <!-- Formulaire d'ajout / edition -->
        <form v-if="showForm" @submit.prevent="saveSite" class="mb-6 p-5 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <input
              v-model="form.name"
              type="text"
              placeholder="Nom du site *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <select
              v-model="form.category"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Categorie *</option>
              <option v-for="cat in categories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
            </select>
            <div class="sm:col-span-2 flex gap-2">
              <input
                v-model="form.url"
                type="url"
                placeholder="https://example.com *"
                required
                class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                @blur="fetchDescription"
              />
              <button
                type="button"
                @click="fetchDescription"
                :disabled="fetchingMeta"
                class="px-3 py-2 text-sm border border-gray-300 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-50"
                title="Recuperer la description du site"
              >
                {{ fetchingMeta ? '...' : 'Auto-description' }}
              </button>
            </div>
            <textarea
              v-model="form.description"
              placeholder="Description (optionnelle)"
              rows="2"
              class="sm:col-span-2 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>
          <div class="mt-3 flex gap-2">
            <button
              type="submit"
              class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
            >
              {{ editingId ? 'Modifier' : 'Enregistrer' }}
            </button>
            <button
              v-if="editingId"
              type="button"
              @click="cancelEdit"
              class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors text-sm font-medium"
            >
              Annuler
            </button>
          </div>
        </form>

        <!-- Liste vide -->
        <div v-if="sites.length === 0" class="text-center text-gray-400 py-12">
          Aucun site enregistre
        </div>

        <!-- Sites par categorie -->
        <div v-else>
          <div v-for="cat in displayedCategories" :key="cat" class="mb-8 last:mb-0">
            <h2 class="text-lg font-semibold text-gray-800 mb-3 flex items-center gap-2">
              <span
                class="inline-block w-3 h-3 rounded-full"
                :class="categoryDotClass(cat)"
              ></span>
              {{ categoryLabel(cat) }}
              <span class="text-sm font-normal text-gray-400">({{ sitesForCategory(cat).length }})</span>
            </h2>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
              <div
                v-for="site in sitesForCategory(cat)"
                :key="site.id"
                class="border border-gray-200 rounded-lg p-4 hover:border-indigo-300 hover:shadow-sm transition-all group"
              >
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <a
                      :href="site.url"
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm font-medium text-indigo-600 hover:text-indigo-800 hover:underline"
                    >
                      {{ site.name }}
                    </a>
                    <p class="text-xs text-gray-400 truncate mt-0.5">{{ cleanUrl(site.url) }}</p>
                    <p v-if="site.description" class="text-sm text-gray-600 mt-1.5 line-clamp-2">{{ site.description }}</p>
                  </div>
                  <div class="flex gap-1 ml-3 opacity-0 group-hover:opacity-100 transition-opacity">
                    <button
                      @click="editSite(site)"
                      class="text-gray-400 hover:text-indigo-600"
                      title="Modifier"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                      </svg>
                    </button>
                    <button
                      @click="deleteSite(site.id)"
                      class="text-gray-400 hover:text-red-600"
                      title="Supprimer"
                    >
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud, post: apiPost } = useApi()
const { list, create, update, destroy } = useCrud('useful_sites')

const sites = ref([])
const showForm = ref(false)
const editingId = ref(null)
const filterCategory = ref('')
const fetchingMeta = ref(false)

const categories = [
  { value: 'dev', label: 'Dev' },
  { value: 'medias', label: 'Medias' },
  { value: 'desinformation', label: 'Desinformation' },
  { value: 'video', label: 'Video' },
  { value: 'jeux', label: 'Jeux' },
  { value: 'administratif', label: 'Administratif' },
  { value: 'sante', label: 'Sante' },
  { value: 'langues', label: 'Langues' },
]

const categoryLabels = Object.fromEntries(categories.map(c => [c.value, c.label]))

const categoryColors = {
  dev: 'bg-cyan-100 text-cyan-700',
  medias: 'bg-pink-100 text-pink-700',
  desinformation: 'bg-red-100 text-red-700',
  video: 'bg-purple-100 text-purple-700',
  jeux: 'bg-green-100 text-green-700',
  administratif: 'bg-blue-100 text-blue-700',
  sante: 'bg-emerald-100 text-emerald-700',
  langues: 'bg-amber-100 text-amber-700',
}

const categoryDots = {
  dev: 'bg-cyan-500',
  medias: 'bg-pink-500',
  desinformation: 'bg-red-500',
  video: 'bg-purple-500',
  jeux: 'bg-green-500',
  administratif: 'bg-blue-500',
  sante: 'bg-emerald-500',
  langues: 'bg-amber-500',
}

const defaultForm = {
  name: '',
  url: '',
  description: '',
  category: '',
}

const form = reactive({ ...defaultForm })

const categoryLabel = (value) => categoryLabels[value] || value
const categoryDotClass = (value) => categoryDots[value] || 'bg-gray-500'

const usedCategories = computed(() => {
  const cats = new Set(sites.value.map(s => s.category).filter(Boolean))
  return categories.map(c => c.value).filter(v => cats.has(v))
})

const displayedCategories = computed(() => {
  if (filterCategory.value) return [filterCategory.value]
  return usedCategories.value
})

const categoryCount = (cat) => {
  return sites.value.filter(s => s.category === cat).length
}

const sitesForCategory = (cat) => {
  return sites.value.filter(s => s.category === cat).sort((a, b) => a.name.localeCompare(b.name, 'fr'))
}

const filteredSites = computed(() => {
  if (filterCategory.value) {
    return sites.value.filter(s => s.category === filterCategory.value)
  }
  return sites.value
})

const cleanUrl = (url) => {
  try {
    const u = new URL(url)
    return u.hostname + (u.pathname !== '/' ? u.pathname : '')
  } catch {
    return url
  }
}

const fetchSites = async () => {
  sites.value = await list()
}

const fetchDescription = async () => {
  if (!form.url || fetchingMeta.value) return
  try {
    new URL(form.url)
  } catch {
    return
  }
  fetchingMeta.value = true
  try {
    const data = await apiPost('/useful_sites/fetch_meta', { url: form.url })
    if (data.description && !form.description) {
      form.description = data.description
    }
  } catch {
    // silently ignore
  } finally {
    fetchingMeta.value = false
  }
}

const openForm = () => {
  if (showForm.value && !editingId.value) {
    showForm.value = false
    return
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = true
}

const saveSite = async () => {
  const data = { useful_site: { ...form } }
  if (editingId.value) {
    await update(editingId.value, data)
  } else {
    await create(data)
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = false
  await fetchSites()
}

const editSite = (site) => {
  editingId.value = site.id
  Object.assign(form, {
    name: site.name,
    url: site.url,
    description: site.description || '',
    category: site.category || '',
  })
  showForm.value = true
}

const cancelEdit = () => {
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = false
}

const deleteSite = async (id) => {
  await destroy(id)
  await fetchSites()
}

onMounted(fetchSites)
</script>
