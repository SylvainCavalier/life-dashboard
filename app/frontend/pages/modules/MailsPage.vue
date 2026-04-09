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
            <span class="text-3xl">📧</span>
            <h1 class="text-2xl font-bold text-gray-900">Messagerie</h1>
            <span class="text-sm text-gray-400">({{ accounts.length }})</span>
          </div>
          <button
            @click="toggleForm()"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showForm ? 'Annuler' : '+ Ajouter un compte' }}
          </button>
        </div>

        <!-- Formulaire d'ajout / edition -->
        <form v-if="showForm" @submit.prevent="saveAccount" class="mb-6 p-5 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <input
              v-model="form.email"
              type="email"
              placeholder="Adresse email *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <select
              v-model="form.provider"
              required
              @change="onProviderChange"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="" disabled>Provider *</option>
              <option v-for="p in providers" :key="p.value" :value="p.value">{{ p.label }}</option>
            </select>
            <input
              v-model="form.provider_url"
              type="url"
              placeholder="URL du webmail *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.password"
              type="password"
              placeholder="Mot de passe (optionnel)"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <!-- Champs optionnels IMAP/SMTP -->
          <div class="mt-3">
            <button
              type="button"
              @click="showAdvanced = !showAdvanced"
              class="text-sm text-indigo-600 hover:text-indigo-800"
            >
              {{ showAdvanced ? '▾ Masquer les options avancées' : '▸ Options avancées (IMAP / SMTP)' }}
            </button>
          </div>
          <div v-if="showAdvanced" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 mt-3">
            <input
              v-model="form.imap_server"
              type="text"
              placeholder="Serveur IMAP"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.imap_port"
              type="number"
              placeholder="Port IMAP"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.smtp_server"
              type="text"
              placeholder="Serveur SMTP"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.smtp_port"
              type="number"
              placeholder="Port SMTP"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div class="flex gap-2 mt-4">
            <button
              type="submit"
              :disabled="saving"
              class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium disabled:opacity-50"
            >
              {{ editing ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </form>

        <!-- Erreurs -->
        <div v-if="error" class="mb-4 px-4 py-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
          {{ error }}
        </div>

        <!-- Liste des comptes mail -->
        <div v-if="loading" class="text-center text-gray-400 py-12">Chargement...</div>

        <div v-else-if="accounts.length === 0" class="text-center text-gray-400 py-12">
          Aucun compte mail enregistré
        </div>

        <div v-else class="space-y-3">
          <div
            v-for="account in accounts"
            :key="account.id"
            class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <div class="flex items-center gap-4 min-w-0">
              <span class="text-2xl flex-shrink-0">{{ providerIcon(account.provider) }}</span>
              <div class="min-w-0">
                <div class="font-medium text-gray-900 truncate">{{ account.email }}</div>
                <div class="text-sm text-gray-500">{{ providerLabel(account.provider) }}</div>
              </div>
            </div>
            <div class="flex items-center gap-2 flex-shrink-0">
              <a
                :href="account.provider_url"
                target="_blank"
                rel="noopener noreferrer"
                class="bg-indigo-100 text-indigo-700 px-3 py-1.5 rounded-lg hover:bg-indigo-200 transition-colors text-sm font-medium"
              >
                Ouvrir ↗
              </a>
              <button
                @click="editAccount(account)"
                class="text-gray-400 hover:text-indigo-600 transition-colors p-1.5"
                title="Modifier"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                </svg>
              </button>
              <button
                @click="deleteAccount(account)"
                class="text-gray-400 hover:text-red-600 transition-colors p-1.5"
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
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud } = useApi()
const { list, create, update, destroy } = useCrud('mail_accounts')

const accounts = ref([])
const showForm = ref(false)
const showAdvanced = ref(false)
const saving = ref(false)
const loading = ref(true)
const error = ref(null)
const editing = ref(null)

const providers = [
  { value: 'gmail', label: 'Gmail' },
  { value: 'zoho', label: 'Zoho Mail' },
  { value: 'orange', label: 'Orange' },
  { value: 'microsoft', label: 'Microsoft / Outlook' },
  { value: 'yahoo', label: 'Yahoo Mail' },
  { value: 'protonmail', label: 'ProtonMail' },
  { value: 'other', label: 'Autre' },
]

const providerUrls = {
  gmail: 'https://mail.google.com',
  zoho: 'https://mail.zoho.eu',
  orange: 'https://messagerie.orange.fr',
  microsoft: 'https://outlook.live.com',
  yahoo: 'https://mail.yahoo.com',
  protonmail: 'https://mail.proton.me',
}

const providerDefaults = {
  gmail: { imap_server: 'imap.gmail.com', imap_port: 993, smtp_server: 'smtp.gmail.com', smtp_port: 587 },
  zoho: { imap_server: 'imap.zoho.eu', imap_port: 993, smtp_server: 'smtp.zoho.eu', smtp_port: 587 },
  orange: { imap_server: 'imap.orange.fr', imap_port: 993, smtp_server: 'smtp.orange.fr', smtp_port: 465 },
  microsoft: { imap_server: 'outlook.office365.com', imap_port: 993, smtp_server: 'smtp.office365.com', smtp_port: 587 },
  yahoo: { imap_server: 'imap.mail.yahoo.com', imap_port: 993, smtp_server: 'smtp.mail.yahoo.com', smtp_port: 587 },
  protonmail: { imap_server: '127.0.0.1', imap_port: 1143, smtp_server: '127.0.0.1', smtp_port: 1025 },
}

const emptyForm = () => ({
  email: '',
  provider: '',
  provider_url: '',
  password: '',
  imap_server: '',
  imap_port: null,
  smtp_server: '',
  smtp_port: null,
})

const form = ref(emptyForm())

const providerIcon = (provider) => {
  const icons = {
    gmail: '📨',
    zoho: '📬',
    orange: '📪',
    microsoft: '📩',
    yahoo: '📫',
    protonmail: '🔒',
    other: '✉️',
  }
  return icons[provider] || '✉️'
}

const providerLabel = (provider) => {
  const found = providers.find((p) => p.value === provider)
  return found ? found.label : provider
}

const onProviderChange = () => {
  const p = form.value.provider
  if (providerUrls[p]) {
    form.value.provider_url = providerUrls[p]
  }
  if (providerDefaults[p]) {
    const defaults = providerDefaults[p]
    form.value.imap_server = defaults.imap_server
    form.value.imap_port = defaults.imap_port
    form.value.smtp_server = defaults.smtp_server
    form.value.smtp_port = defaults.smtp_port
  }
}

const toggleForm = () => {
  showForm.value = !showForm.value
  if (!showForm.value) {
    editing.value = null
    form.value = emptyForm()
    showAdvanced.value = false
  }
}

const editAccount = (account) => {
  editing.value = account.id
  form.value = {
    email: account.email,
    provider: account.provider,
    provider_url: account.provider_url,
    password: '',
    imap_server: account.imap_server || '',
    imap_port: account.imap_port,
    smtp_server: account.smtp_server || '',
    smtp_port: account.smtp_port,
  }
  showForm.value = true
  if (account.imap_server || account.smtp_server) {
    showAdvanced.value = true
  }
}

const saveAccount = async () => {
  saving.value = true
  error.value = null
  try {
    const data = { ...form.value }
    if (!data.password) delete data.password
    if (!data.imap_server) delete data.imap_server
    if (!data.imap_port) delete data.imap_port
    if (!data.smtp_server) delete data.smtp_server
    if (!data.smtp_port) delete data.smtp_port

    if (editing.value) {
      await update(editing.value, data)
    } else {
      await create(data)
    }
    await fetchAccounts()
    toggleForm()
  } catch (e) {
    error.value = e.response?.data?.errors?.join(', ') || 'Erreur lors de la sauvegarde'
  } finally {
    saving.value = false
  }
}

const deleteAccount = async (account) => {
  if (!confirm(`Supprimer le compte ${account.email} ?`)) return
  try {
    await destroy(account.id)
    await fetchAccounts()
  } catch (e) {
    error.value = 'Erreur lors de la suppression'
  }
}

const fetchAccounts = async () => {
  try {
    accounts.value = await list()
  } catch (e) {
    error.value = 'Erreur lors du chargement'
  } finally {
    loading.value = false
  }
}

onMounted(fetchAccounts)
</script>
