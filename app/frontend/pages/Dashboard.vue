<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <div class="mb-8 flex items-start justify-between gap-4">
        <div>
          <h1 class="text-3xl font-bold text-gray-900">Life Dashboard</h1>
          <p class="text-gray-500 mt-1">{{ formattedDate }}</p>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <a
            href="/account/password"
            class="text-sm text-gray-500 hover:text-gray-800 border border-gray-200 hover:border-gray-300 rounded-lg px-3 py-2 bg-white transition-colors"
          >
            Mot de passe
          </a>
        <!-- Deconnexion : formulaire Rails classique (session Devise, DELETE + CSRF) -->
        <form action="/users/sign_out" method="post">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="authenticity_token" :value="csrfToken" />
          <button
            type="submit"
            class="text-sm text-gray-500 hover:text-gray-800 border border-gray-200 hover:border-gray-300 rounded-lg px-3 py-2 bg-white transition-colors"
          >
            Se deconnecter
          </button>
        </form>
        </div>
      </div>

      <div class="flex gap-6">
        <!-- Colonne gauche : Todo List -->
        <aside class="w-80 flex-shrink-0">
          <TodoList />
        </aside>

        <!-- Colonne droite : Modules -->
        <div class="flex-1 min-w-0">
          <!-- Grille de modules -->
          <div class="grid grid-cols-2 lg:grid-cols-3 gap-4">
            <router-link
              v-for="mod in modules"
              :key="mod.name"
              :to="mod.to"
              class="bg-white rounded-xl shadow-sm p-6 hover:shadow-md hover:-translate-y-0.5 transition-all"
            >
              <div class="text-3xl mb-3">{{ mod.icon }}</div>
              <h2 class="font-semibold text-gray-900">{{ mod.name }}</h2>
              <p class="text-sm text-gray-400 mt-1">{{ mod.subtitle }}</p>
            </router-link>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useApi } from '../composables/useApi'
import TodoList from '../components/TodoList.vue'

const { useCrud, get } = useApi()

// Jeton CSRF pose par Rails dans le layout : necessaire au formulaire de
// deconnexion, qui est un POST Rails classique et non un appel axios.
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

const counts = ref({
  contacts: 0,
  properties: 0,
  companies: 0,
  passwords: 0,
  mails: 0,
  documents: 0,
  subscriptions: 0,
  notes: 0,
  useful_sites: 0,
  projects: 0,
  events: 0,
  file_transfers: 0,
  trips: 0,
  video_downloads: 0,
  meetings: 0,
})

const fetchCounts = async () => {
  const fetches = [
    { key: 'contacts', resource: 'contacts' },
    { key: 'properties', resource: 'properties' },
    { key: 'companies', resource: 'companies' },
    { key: 'passwords', resource: 'password_entries' },
    { key: 'mails', resource: 'mail_accounts' },
    { key: 'documents', resource: 'documents' },
    { key: 'subscriptions', resource: 'subscriptions' },
    { key: 'notes', resource: 'notes' },
    { key: 'useful_sites', resource: 'useful_sites' },
    { key: 'projects', resource: 'projects' },
    { key: 'events', resource: 'events' },
    { key: 'file_transfers', resource: 'file_transfers' },
    { key: 'trips', resource: 'trips' },
    { key: 'video_downloads', resource: 'video_downloads' },
    { key: 'meetings', resource: 'meetings' },
  ]

  const results = await Promise.allSettled(
    fetches.map(f => useCrud(f.resource).list())
  )

  fetches.forEach((f, i) => {
    if (results[i].status === 'fulfilled' && Array.isArray(results[i].value)) {
      counts.value[f.key] = results[i].value.length
    }
  })
}

// Solde du mois courant, calcule par le serveur avec la meme formule que la page Budget
const monthlyBalance = ref(null)

const fetchBudgetSummary = async () => {
  try {
    const today = new Date()
    const summary = await get('/budget_entries/summary', { params: { year: today.getFullYear() } })
    const current = summary.months?.find(m => m.month === today.getMonth() + 1)
    if (current) monthlyBalance.value = parseFloat(current.balance)
  } catch {
    monthlyBalance.value = null
  }
}

// GET /api/languages renvoie { languages, available_names } et non un tableau
const languages = ref([])

const fetchLanguages = async () => {
  try {
    const data = await get('/languages')
    languages.value = data.languages || []
  } catch {
    languages.value = []
  }
}

const languagesSubtitle = computed(() => {
  const total = languages.value.length
  const practicedToday = languages.value.filter(l => l.practiced_today).length
  const label = `${total} langue${total > 1 ? 's' : ''}`
  return practicedToday > 0 ? `${label} · ${practicedToday} pratiquée${practicedToday > 1 ? 's' : ''} aujourd'hui` : label
})

const budgetSubtitle = computed(() => {
  if (monthlyBalance.value === null) return 'Solde du mois indisponible'
  const formatted = monthlyBalance.value.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  return `Solde du mois : ${monthlyBalance.value >= 0 ? '+' : ''}${formatted} €`
})

const formattedDate = computed(() => {
  return new Date().toLocaleDateString('fr-FR', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
})

const modules = computed(() => [
  { name: 'Contacts', icon: '👥', subtitle: `${counts.value.contacts} contact${counts.value.contacts > 1 ? 's' : ''}`, to: '/contacts' },
  { name: 'Immobilier', icon: '🏠', subtitle: `${counts.value.properties} bien${counts.value.properties > 1 ? 's' : ''}`, to: '/properties' },
  { name: 'Entreprises', icon: '🏢', subtitle: `${counts.value.companies} entreprise${counts.value.companies > 1 ? 's' : ''}`, to: '/companies' },
  { name: 'Budget', icon: '💰', subtitle: budgetSubtitle.value, to: '/budget' },
  { name: 'Langues', icon: '🌍', subtitle: languagesSubtitle.value, to: '/languages' },
  { name: 'Agenda', icon: '📅', subtitle: `${counts.value.events} événement${counts.value.events > 1 ? 's' : ''}`, to: '/agenda' },
  { name: 'Mots de passe', icon: '🔐', subtitle: `${counts.value.passwords} entree${counts.value.passwords > 1 ? 's' : ''}`, to: '/passwords' },
  { name: 'Messagerie', icon: '📧', subtitle: `${counts.value.mails} compte${counts.value.mails > 1 ? 's' : ''}`, to: '/mails' },
  { name: 'Sante', icon: '🏥', subtitle: 'Infos & documents', to: '/health' },
  { name: 'Abonnements', icon: '🔄', subtitle: `${counts.value.subscriptions} abonnement${counts.value.subscriptions > 1 ? 's' : ''}`, to: '/subscriptions' },
  { name: 'Reunions', icon: '🎙️', subtitle: `${counts.value.meetings} compte${counts.value.meetings > 1 ? 's' : ''} rendu${counts.value.meetings > 1 ? 's' : ''}`, to: '/meetings' },
  { name: 'Notes', icon: '📝', subtitle: `${counts.value.notes} note${counts.value.notes > 1 ? 's' : ''}`, to: '/notes' },
  { name: 'Sites utiles', icon: '🔗', subtitle: `${counts.value.useful_sites} site${counts.value.useful_sites > 1 ? 's' : ''}`, to: '/useful-sites' },
  { name: 'Mes projets', icon: '🚀', subtitle: `${counts.value.projects} projet${counts.value.projects > 1 ? 's' : ''}`, to: '/projects' },
  { name: 'Mon profil', icon: '👤', subtitle: 'Donnees personnelles', to: '/profile' },
  { name: 'CV', icon: '📄', subtitle: 'Experiences, formations, competences', to: '/cv' },
  { name: 'Documents', icon: '📁', subtitle: `${counts.value.documents} document${counts.value.documents > 1 ? 's' : ''}`, to: '/documents' },
  { name: 'Transfert', icon: '📤', subtitle: `${counts.value.file_transfers} fichier${counts.value.file_transfers > 1 ? 's' : ''} partage${counts.value.file_transfers > 1 ? 's' : ''}`, to: '/transfer' },
  { name: 'Voyages', icon: '✈️', subtitle: `${counts.value.trips} voyage${counts.value.trips > 1 ? 's' : ''}`, to: '/trips' },
  { name: 'Downloader', icon: '🎬', subtitle: `${counts.value.video_downloads} telechargement${counts.value.video_downloads > 1 ? 's' : ''}`, to: '/downloader' },
  { name: 'Sentinelle', icon: '🛰️', subtitle: 'Veille désinformation et droit du travail', to: '/sentinelle' },
  { name: 'Outils', icon: '🧰', subtitle: 'PDF et images', to: '/tools' },
  { name: 'Alfred', icon: '🎩', subtitle: 'Intendant IA : instructions, outils, mémoire', to: '/alfred' },
])

onMounted(() => {
  fetchCounts()
  fetchBudgetSummary()
  fetchLanguages()
})
</script>
