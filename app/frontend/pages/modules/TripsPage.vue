<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <span class="text-3xl">✈️</span>
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Voyages</h1>
            <p class="text-sm text-gray-400">{{ trips.length }} voyage{{ trips.length > 1 ? 's' : '' }} · {{ visitedCodes.length }} pays visité{{ visitedCodes.length > 1 ? 's' : '' }}</p>
          </div>
        </div>
        <button @click="openForm()" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">
          + Nouveau voyage
        </button>
      </div>

      <div v-if="showForm" class="mb-6">
        <TripForm :initial="formInitial" :saving="saving" :errors="formErrors" @submit="saveTrip" @cancel="showForm = false" />
      </div>

      <div class="mb-6">
        <WorldMap :visited="visitedCodes" :planned="plannedCodes" :selected="formInitial?.country_code" @select="selectCountry" />
      </div>

      <div v-if="loaded && trips.length === 0" class="text-center text-gray-400 py-12">Aucun voyage pour l'instant</div>

      <section v-if="upcoming.length" class="mb-8">
        <h2 class="text-lg font-semibold text-gray-900 mb-3">À venir</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <TripCard v-for="entry in upcoming" :key="entry.id" :trip="entry" @delete="deleteTrip" />
        </div>
      </section>

      <section v-if="past.length">
        <h2 class="text-lg font-semibold text-gray-900 mb-3">Historique</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <TripCard v-for="entry in past" :key="entry.id" :trip="entry" @delete="deleteTrip" />
        </div>
      </section>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, defineComponent, h } from 'vue'
import { RouterLink } from 'vue-router'
import { useApi } from '../../composables/useApi'
import { useCountries } from '../../composables/useCountries'
import { useTripDates } from '../../composables/useTripDates'
import TripForm from '../../components/trips/TripForm.vue'
import WorldMap from '../../components/trips/WorldMap.vue'

const { useCrud } = useApi()
const { list, create, destroy } = useCrud('trips')
const { countryName, flagEmoji } = useCountries()
const { formatDate, formatCurrency } = useTripDates()

const trips = ref([])
const loaded = ref(false)
const showForm = ref(false)
const formInitial = ref(null)
const formErrors = ref([])
const saving = ref(false)

const fetchTrips = async () => {
  trips.value = await list()
  loaded.value = true
}

const byStartAsc = (a, b) => a.start_date.localeCompare(b.start_date)
const byEndDesc = (a, b) => b.end_date.localeCompare(a.end_date)

const upcoming = computed(() => trips.value.filter(t => !t.past && t.status !== 'annule').sort(byStartAsc))
const past = computed(() => trips.value.filter(t => t.past || t.status === 'annule').sort(byEndDesc))

const visitedCodes = computed(() => [...new Set(trips.value.filter(t => t.visited).map(t => t.country_code))])
const plannedCodes = computed(() => [...new Set(upcoming.value.map(t => t.country_code))].filter(c => !visitedCodes.value.includes(c)))

const openForm = (initial = null) => {
  formInitial.value = initial
  formErrors.value = []
  showForm.value = true
}

// Clic sur un pays de la carte : pré-remplit (ou ouvre) le formulaire.
const selectCountry = (code) => {
  formInitial.value = { ...(formInitial.value || {}), country_code: code }
  formErrors.value = []
  showForm.value = true
}

const saveTrip = async (payload) => {
  saving.value = true
  formErrors.value = []
  try {
    await create({ trip: payload })
    showForm.value = false
    formInitial.value = null
    await fetchTrips()
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const deleteTrip = async (trip) => {
  if (!confirm(`Supprimer le voyage « ${trip.destination} » et son planning ?`)) return
  await destroy(trip.id)
  await fetchTrips()
}

const statusLabels = { envisage: 'Envisagé', confirme: 'Confirmé', annule: 'Annulé' }
const statusClasses = { envisage: 'bg-gray-100 text-gray-600', confirme: 'bg-green-100 text-green-700', annule: 'bg-red-100 text-red-600' }
const planLabels = { pending: 'Rapport en attente', running: 'Rapport en cours', done: 'Rapport IA prêt', failed: 'Rapport en échec' }

const TripCard = defineComponent({
  props: { trip: { type: Object, required: true } },
  emits: ['delete'],
  setup(cardProps, { emit }) {
    return () => {
      const t = cardProps.trip
      return h('div', { class: 'bg-white rounded-xl shadow-sm p-5 hover:shadow-md transition-all flex flex-col' }, [
        h(RouterLink, { to: `/trips/${t.id}`, class: 'flex-1 block' }, () => [
          h('div', { class: 'flex items-start justify-between gap-2 mb-2' }, [
            h('div', { class: 'min-w-0' }, [
              h('h3', { class: 'font-semibold text-gray-900 truncate' }, `${flagEmoji(t.country_code)} ${t.destination}`),
              h('p', { class: 'text-xs text-gray-400' }, countryName(t.country_code)),
            ]),
            h('span', { class: `text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0 ${statusClasses[t.status] || ''}` }, statusLabels[t.status] || t.status),
          ]),
          h('p', { class: 'text-sm text-gray-600' }, `Du ${formatDate(t.start_date)} au ${formatDate(t.end_date)} · ${t.duration_days} jour${t.duration_days > 1 ? 's' : ''} · ${t.travelers} voyageur${t.travelers > 1 ? 's' : ''}`),
          h('p', { class: 'text-xs text-gray-400 mt-1' }, [
            t.estimated_total_eur ? `≈ ${formatCurrency(t.estimated_total_eur)} · ` : '',
            planLabels[t.plan_status] || 'Pas encore de rapport IA',
          ]),
        ]),
        h('div', { class: 'flex items-center justify-end gap-3 pt-3 mt-3 border-t border-gray-100' }, [
          h(RouterLink, { to: `/trips/${t.id}`, class: 'text-xs text-blue-500 hover:text-blue-700' }, () => 'Ouvrir'),
          h('button', { class: 'text-xs text-red-400 hover:text-red-600', onClick: () => emit('delete', t) }, 'Supprimer'),
        ]),
      ])
    }
  },
})

onMounted(fetchTrips)
</script>
