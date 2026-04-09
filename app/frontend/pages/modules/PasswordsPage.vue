<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-4xl mx-auto">
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
            <span class="text-3xl">🔐</span>
            <h1 class="text-2xl font-bold text-gray-900">Mots de passe</h1>
          </div>
          <button
            @click="showForm = !showForm"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showForm ? 'Annuler' : '+ Ajouter' }}
          </button>
        </div>

        <!-- Formulaire d'ajout -->
        <form v-if="showForm" @submit.prevent="addEntry" class="mb-6 p-4 bg-gray-50 rounded-lg flex flex-col sm:flex-row gap-3">
          <input
            v-model="form.name"
            type="text"
            placeholder="Nom (ex: Gmail)"
            required
            class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <input
            v-model="form.login"
            type="text"
            placeholder="Login / Email"
            required
            class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <input
            v-model="form.password"
            type="text"
            placeholder="Mot de passe"
            required
            class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <button
            type="submit"
            class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium whitespace-nowrap"
          >
            Enregistrer
          </button>
        </form>

        <!-- Tableau -->
        <div v-if="entries.length === 0" class="text-center text-gray-400 py-12">
          Aucun mot de passe enregistre
        </div>

        <table v-else class="w-full">
          <thead>
            <tr class="border-b border-gray-200 text-left text-sm text-gray-500">
              <th class="pb-3 font-medium">Nom</th>
              <th class="pb-3 font-medium">Login</th>
              <th class="pb-3 font-medium">Mot de passe</th>
              <th class="pb-3 font-medium w-24"></th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="entry in entries"
              :key="entry.id"
              class="border-b border-gray-100 hover:bg-gray-50"
            >
              <td class="py-3 text-sm text-gray-900 font-medium">{{ entry.name }}</td>
              <td class="py-3 text-sm text-gray-700">{{ entry.login }}</td>
              <td class="py-3 text-sm text-gray-700 font-mono">
                <span v-if="visiblePasswords.has(entry.id)">{{ entry.password }}</span>
                <span v-else class="tracking-widest">••••••••</span>
                <button
                  @click="togglePassword(entry.id)"
                  class="ml-2 text-gray-400 hover:text-gray-600"
                  :title="visiblePasswords.has(entry.id) ? 'Masquer' : 'Afficher'"
                >
                  <svg v-if="visiblePasswords.has(entry.id)" class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21" />
                  </svg>
                  <svg v-else class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
              </td>
              <td class="py-3 text-right">
                <button
                  @click="deleteEntry(entry.id)"
                  class="text-red-400 hover:text-red-600 text-sm"
                  title="Supprimer"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud } = useApi()
const { list, create, destroy } = useCrud('password_entries')

const entries = ref([])
const showForm = ref(false)
const visiblePasswords = ref(new Set())

const form = reactive({
  name: '',
  login: '',
  password: '',
})

const fetchEntries = async () => {
  entries.value = await list()
}

const addEntry = async () => {
  await create({ password_entry: { ...form } })
  form.name = ''
  form.login = ''
  form.password = ''
  showForm.value = false
  await fetchEntries()
}

const deleteEntry = async (id) => {
  await destroy(id)
  visiblePasswords.value.delete(id)
  await fetchEntries()
}

const togglePassword = (id) => {
  if (visiblePasswords.value.has(id)) {
    visiblePasswords.value.delete(id)
  } else {
    visiblePasswords.value.add(id)
  }
  // Force reactivity
  visiblePasswords.value = new Set(visiblePasswords.value)
}

onMounted(fetchEntries)
</script>
