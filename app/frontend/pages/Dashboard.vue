<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
      <!-- Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Life Dashboard</h1>
        <p class="text-gray-500 mt-1">{{ formattedDate }}</p>
      </div>

      <div class="flex gap-6">
        <!-- Colonne gauche : Todo List -->
        <aside class="w-80 flex-shrink-0">
          <TodoList />
        </aside>

        <!-- Colonne droite : Resume du jour + Modules -->
        <div class="flex-1 min-w-0">
          <!-- Resume du jour -->
          <div class="mb-10">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Resume du jour</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div v-for="panel in summaryPanels" :key="panel.title" class="bg-white rounded-xl shadow-sm p-5">
                <h3 class="text-sm font-medium text-gray-500 mb-2">{{ panel.title }}</h3>
                <p class="text-gray-400 text-sm">{{ panel.content }}</p>
              </div>
            </div>
          </div>

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

const { useCrud } = useApi()

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
  { name: 'Budget', icon: '💰', subtitle: 'Non configure', to: '/budget' },
  { name: 'Activites', icon: '🏃', subtitle: '0 activites', to: '/activities' },
  { name: 'Langues', icon: '🌍', subtitle: '0 langues', to: '/languages' },
  { name: 'Agenda', icon: '📅', subtitle: `${counts.value.events} événement${counts.value.events > 1 ? 's' : ''}`, to: '/agenda' },
  { name: 'Mots de passe', icon: '🔐', subtitle: `${counts.value.passwords} entree${counts.value.passwords > 1 ? 's' : ''}`, to: '/passwords' },
  { name: 'Messagerie', icon: '📧', subtitle: `${counts.value.mails} compte${counts.value.mails > 1 ? 's' : ''}`, to: '/mails' },
  { name: 'Sante', icon: '🏥', subtitle: 'Infos & documents', to: '/health' },
  { name: 'Abonnements', icon: '🔄', subtitle: `${counts.value.subscriptions} abonnement${counts.value.subscriptions > 1 ? 's' : ''}`, to: '/subscriptions' },
  { name: 'Notes', icon: '📝', subtitle: `${counts.value.notes} note${counts.value.notes > 1 ? 's' : ''}`, to: '/notes' },
  { name: 'Sites utiles', icon: '🔗', subtitle: `${counts.value.useful_sites} site${counts.value.useful_sites > 1 ? 's' : ''}`, to: '/useful-sites' },
  { name: 'Mes projets', icon: '🚀', subtitle: `${counts.value.projects} projet${counts.value.projects > 1 ? 's' : ''}`, to: '/projects' },
  { name: 'Mon profil', icon: '👤', subtitle: 'Donnees personnelles', to: '/profile' },
])

const summaryPanels = [
  { title: 'Prochains RDV', content: 'Aucune donnee' },
  { title: 'Budget du mois', content: 'Aucune donnee' },
  { title: 'Factures en attente', content: 'Aucune donnee' },
  { title: 'Activites de la semaine', content: 'Aucune donnee' },
]

onMounted(fetchCounts)
</script>
