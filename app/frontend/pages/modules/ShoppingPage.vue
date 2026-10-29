<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-3xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between gap-3 mb-6">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Liste de courses</h1>
          <p class="text-sm text-gray-400">
            <template v-if="items.length">{{ toBuy.length }} article{{ toBuy.length > 1 ? 's' : '' }} à acheter<template v-if="inCart.length"> · {{ inCart.length }} dans le caddie</template></template>
            <template v-else-if="loaded">La liste est vide</template>
          </p>
        </div>
        <button
          v-if="items.length"
          @click="clearList"
          :disabled="busy"
          class="text-sm px-4 py-2 rounded-lg border border-red-200 text-red-600 hover:bg-red-50 transition disabled:opacity-50"
        >
          Réinitialiser
        </button>
      </div>

      <!-- Saisie -->
      <form class="flex gap-2 mb-2" @submit.prevent="addFromInput">
        <input
          ref="input"
          v-model="draft"
          type="text"
          maxlength="300"
          placeholder="Ajouter un article (ex. Lait, Œufs)"
          enterkeyhint="done"
          class="flex-1 min-w-0 border border-gray-300 rounded-lg px-3 py-2.5 text-base sm:text-sm focus:outline-none focus:ring-2 focus:ring-gray-900/20"
        />
        <button type="submit" :disabled="!draft.trim() || busy" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40">
          Ajouter
        </button>
      </form>
      <p v-if="notice" class="text-xs mb-4" :class="notice.error ? 'text-red-600' : 'text-gray-500'">{{ notice.text }}</p>
      <div v-else class="mb-4"></div>

      <!-- Articles habituels -->
      <section class="mb-8">
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-sm font-semibold text-gray-700">Articles habituels</h2>
          <button @click="managing = !managing" class="text-xs text-gray-400 hover:text-gray-700 underline">
            {{ managing ? 'Terminé' : 'Gérer' }}
          </button>
        </div>

        <p v-if="loaded && !presets.length && !managing" class="text-sm text-gray-400">
          Aucun article habituel. <button @click="managing = true" class="underline hover:text-gray-600">Créer une carte</button>
          ou cliquez sur ☆ à côté d'un article de la liste.
        </p>

        <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-2">
          <div v-for="preset in presets" :key="preset.id" class="relative">
            <button
              type="button"
              @click="managing ? null : addPreset(preset)"
              :disabled="busy && !managing"
              class="w-full h-full min-h-[4.5rem] flex flex-col items-center justify-center gap-1 rounded-xl border px-2 py-2 text-center transition"
              :class="presetClass(preset)"
              :title="isListed(preset.name) ? 'Déjà dans la liste' : `Ajouter « ${preset.name} »`"
            >
              <span class="text-xl leading-none">{{ preset.icon || '🛒' }}</span>
              <span class="text-xs font-medium leading-tight break-words">{{ preset.name }}</span>
              <span v-if="isListed(preset.name) && !managing" class="absolute top-1 right-1.5 text-[10px] text-emerald-600">✓</span>
            </button>
            <button
              v-if="managing"
              type="button"
              @click="deletePreset(preset)"
              class="absolute -top-2 -right-2 h-6 w-6 rounded-full bg-white border border-gray-300 text-gray-500 hover:text-red-600 hover:border-red-300 text-xs shadow-sm"
              :aria-label="`Supprimer la carte ${preset.name}`"
            >✕</button>
          </div>
        </div>

        <form v-if="managing" class="flex gap-2 mt-3" @submit.prevent="createPreset">
          <input v-model="presetDraft.icon" type="text" maxlength="16" placeholder="🥖" class="w-14 border border-gray-300 rounded-lg px-2 py-2 text-center text-base sm:text-sm" aria-label="Emoji" />
          <input v-model="presetDraft.name" type="text" maxlength="100" placeholder="Nouvel article habituel" class="flex-1 min-w-0 border border-gray-300 rounded-lg px-3 py-2 text-base sm:text-sm" />
          <button type="submit" :disabled="!presetDraft.name.trim()" class="text-sm px-4 py-2 rounded-lg border border-gray-300 text-gray-700 hover:bg-white disabled:opacity-40">
            Créer
          </button>
        </form>
      </section>

      <!-- Liste -->
      <section>
        <div v-if="loaded && !items.length" class="text-center text-gray-400 py-12 bg-white rounded-xl shadow-sm">
          Rien à acheter pour l'instant
        </div>

        <ul v-if="toBuy.length" class="bg-white rounded-xl shadow-sm divide-y divide-gray-100">
          <li v-for="item in toBuy" :key="item.id" class="flex items-center gap-3 px-4 py-3">
            <button
              type="button"
              @click="toggle(item)"
              class="h-6 w-6 flex-shrink-0 rounded-md border-2 border-gray-300 hover:border-gray-500"
              :aria-label="`Cocher ${item.name}`"
            ></button>
            <span class="flex-1 min-w-0 break-words text-gray-900 cursor-pointer" @click="toggle(item)">{{ item.name }}</span>
            <button
              v-if="!hasPreset(item.name)"
              type="button"
              @click="makePreset(item)"
              class="text-gray-300 hover:text-amber-500 px-1"
              title="En faire un article habituel"
            >☆</button>
            <button type="button" @click="removeItem(item)" class="text-gray-300 hover:text-red-600 px-1" :aria-label="`Retirer ${item.name}`">✕</button>
          </li>
        </ul>

        <template v-if="inCart.length">
          <h3 class="text-xs uppercase tracking-wide text-gray-400 mt-6 mb-2">Dans le caddie</h3>
          <ul class="bg-white/60 rounded-xl divide-y divide-gray-100">
            <li v-for="item in inCart" :key="item.id" class="flex items-center gap-3 px-4 py-2.5">
              <button
                type="button"
                @click="toggle(item)"
                class="h-6 w-6 flex-shrink-0 rounded-md bg-emerald-500 text-white text-sm flex items-center justify-center"
                :aria-label="`Décocher ${item.name}`"
              >✓</button>
              <span class="flex-1 min-w-0 break-words text-gray-400 line-through cursor-pointer" @click="toggle(item)">{{ item.name }}</span>
              <button type="button" @click="removeItem(item)" class="text-gray-300 hover:text-red-600 px-1" :aria-label="`Retirer ${item.name}`">✕</button>
            </li>
          </ul>
        </template>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import apiClient from '../../plugins/axios'

const items = ref([])
const presets = ref([])
const loaded = ref(false)
const busy = ref(false)
const managing = ref(false)
const draft = ref('')
const presetDraft = ref({ name: '', icon: '' })
const notice = ref(null)
const input = ref(null)

// Meme ordre que ShoppingItem.ordered : a acheter dans l'ordre d'ajout, puis le caddie.
const toBuy = computed(() => items.value.filter(i => !i.checked))
const inCart = computed(() => items.value.filter(i => i.checked))

const sameName = (a, b) => a.localeCompare(b, 'fr', { sensitivity: 'accent' }) === 0
const isListed = (name) => items.value.some(i => sameName(i.name, name))
const hasPreset = (name) => presets.value.some(p => sameName(p.name, name))

const presetClass = (preset) => {
  if (managing.value) return 'bg-white border-dashed border-gray-300 text-gray-600 cursor-default'
  if (isListed(preset.name)) return 'bg-emerald-50 border-emerald-200 text-emerald-800'
  return 'bg-white border-gray-200 text-gray-800 hover:border-gray-400 hover:shadow-sm'
}

const flash = (text, error = false) => {
  notice.value = { text, error }
  setTimeout(() => { if (notice.value?.text === text) notice.value = null }, 4000)
}

const errorText = (e, fallback) => e.response?.data?.errors?.join(', ') || fallback

const fetchItems = async () => {
  items.value = (await apiClient.get('/shopping_items')).data || []
}

const fetchAll = async () => {
  const [list, cards] = await Promise.all([apiClient.get('/shopping_items'), apiClient.get('/shopping_presets')])
  items.value = list.data || []
  presets.value = cards.data || []
  loaded.value = true
}

const addNames = async (names) => {
  busy.value = true
  try {
    const { data } = await apiClient.post('/shopping_items', { names })
    await fetchItems()
    if (data.skipped.length) flash(`Déjà dans la liste : ${data.skipped.join(', ')}`)
    return true
  } catch (e) {
    flash(errorText(e, 'Ajout impossible'), true)
    return false
  } finally {
    busy.value = false
  }
}

// « Lait, œufs ; pain » : plusieurs articles d'un coup.
const addFromInput = async () => {
  const names = draft.value.split(/[,;\n]/).map(n => n.trim()).filter(Boolean)
  if (!names.length) return
  if (await addNames(names)) draft.value = ''
  input.value?.focus()
}

const addPreset = (preset) => {
  if (isListed(preset.name)) return
  addNames([preset.name])
}

const toggle = async (item) => {
  const checked = !item.checked
  item.checked = checked // optimiste : en magasin, la case doit reagir tout de suite
  try {
    await apiClient.patch(`/shopping_items/${item.id}`, { shopping_item: { checked } })
    await fetchItems()
  } catch (e) {
    item.checked = !checked
    flash(errorText(e, 'Modification impossible'), true)
  }
}

const removeItem = async (item) => {
  items.value = items.value.filter(i => i.id !== item.id)
  try {
    await apiClient.delete(`/shopping_items/${item.id}`)
  } catch (e) {
    await fetchItems()
    flash(errorText(e, 'Suppression impossible'), true)
  }
}

const clearList = async () => {
  if (!confirm('Vider toute la liste de courses ?')) return
  busy.value = true
  try {
    await apiClient.delete('/shopping_items/clear')
    items.value = []
  } finally {
    busy.value = false
  }
}

const savePreset = async (attributes) => {
  try {
    await apiClient.post('/shopping_presets', { shopping_preset: attributes })
    presets.value = (await apiClient.get('/shopping_presets')).data || []
    return true
  } catch (e) {
    flash(errorText(e, 'Création de la carte impossible'), true)
    return false
  }
}

const createPreset = async () => {
  if (await savePreset({ name: presetDraft.value.name.trim(), icon: presetDraft.value.icon.trim() })) {
    presetDraft.value = { name: '', icon: '' }
  }
}

const makePreset = async (item) => {
  if (await savePreset({ name: item.name })) flash(`« ${item.name} » ajouté aux articles habituels`)
}

const deletePreset = async (preset) => {
  presets.value = presets.value.filter(p => p.id !== preset.id)
  await apiClient.delete(`/shopping_presets/${preset.id}`)
}

// La liste bouge ailleurs : cochee depuis l'iPhone (relue au retour sur l'onglet), ou
// modifiee par une carte d'Alfred confirmee dans le widget de cette page.
const onVisible = () => {
  if (document.visibilityState === 'visible') fetchAll()
}

const onAlfredAction = (event) => {
  if (['ShoppingItem', 'ShoppingPreset'].includes(event.detail?.targetModel)) fetchAll()
}

onMounted(() => {
  fetchAll()
  document.addEventListener('visibilitychange', onVisible)
  window.addEventListener('alfred:action-resolved', onAlfredAction)
})

onBeforeUnmount(() => {
  document.removeEventListener('visibilitychange', onVisible)
  window.removeEventListener('alfred:action-resolved', onAlfredAction)
})
</script>
