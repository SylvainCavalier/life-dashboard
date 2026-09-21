<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
      <router-link to="/trips" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour aux voyages
      </router-link>

      <div v-if="trip" class="space-y-6">
        <!-- En-tête -->
        <div v-if="!editing" class="bg-white rounded-xl shadow-sm p-6">
          <div class="flex items-start justify-between gap-4">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <h1 class="text-2xl font-bold text-gray-900">{{ flagEmoji(trip.country_code) }} {{ trip.destination }}</h1>
                <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="statusClasses[trip.status]">{{ statusLabels[trip.status] }}</span>
                <span v-if="trip.past" class="text-xs px-2 py-0.5 rounded-full font-medium bg-gray-100 text-gray-500">Passé</span>
              </div>
              <p class="text-sm text-gray-500">{{ countryName(trip.country_code) }}</p>
              <p class="text-sm text-gray-600 mt-2">
                Du {{ formatDate(trip.start_date) }} au {{ formatDate(trip.end_date) }} · {{ trip.duration_days }} jour{{ trip.duration_days > 1 ? 's' : '' }}
                · {{ trip.travelers }} voyageur{{ trip.travelers > 1 ? 's' : '' }} · départ de {{ trip.departure_city || 'Paris' }}
              </p>
              <p v-if="trip.notes" class="text-sm text-gray-500 mt-2 whitespace-pre-line">{{ trip.notes }}</p>
            </div>
            <div class="flex items-center gap-3 flex-shrink-0">
              <button @click="startEdit" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteTrip" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>
        </div>
        <TripForm v-else :initial="trip" :saving="saving" :errors="formErrors" @submit="saveTrip" @cancel="editing = false" />

        <TripPlanReport :trip="trip" :plan="trip.plan" :content="reportContent" @generate="generatePlan" @add-item="addSuggestedItem" />

        <TripPlanner :trip="trip" :items="trip.items" @create="createItem" @update="updateItem" @destroy="destroyItem" />
      </div>

      <div v-else-if="notFound" class="text-center text-gray-400 py-12">Voyage introuvable</div>
      <div v-else class="text-center text-gray-400 py-12">Chargement...</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import { useCountries } from '../../composables/useCountries'
import { useTripDates } from '../../composables/useTripDates'
import TripForm from '../../components/trips/TripForm.vue'
import TripPlanReport from '../../components/trips/TripPlanReport.vue'
import TripPlanner from '../../components/trips/TripPlanner.vue'

const props = defineProps({ id: { type: [String, Number], required: true } })

const router = useRouter()
const { useCrud, post, patch, delete: del } = useApi()
const { show, update, destroy } = useCrud('trips')
const { countryName, flagEmoji } = useCountries()
const { formatDate } = useTripDates()

const trip = ref(null)
const notFound = ref(false)
const editing = ref(false)
const saving = ref(false)
const formErrors = ref([])

// Dernier rapport connu : reste affiché pendant une régénération, le serveur
// ne renvoyant le contenu qu'en statut done.
const lastContent = ref(null)
const reportContent = computed(() => trip.value?.plan?.content || lastContent.value)

const statusLabels = { envisage: 'Envisagé', confirme: 'Confirmé', annule: 'Annulé' }
const statusClasses = { envisage: 'bg-gray-100 text-gray-600', confirme: 'bg-green-100 text-green-700', annule: 'bg-red-100 text-red-600' }

const POLL_DELAY = 3000
let pollTimer = null

const planInProgress = () => {
  const plan = trip.value?.plan
  return plan && ['pending', 'running'].includes(plan.status) && !plan.stuck
}

const fetchTrip = async () => {
  try {
    trip.value = await show(props.id)
    if (trip.value.plan?.content) lastContent.value = trip.value.plan.content
    schedulePoll()
  } catch (e) {
    if (e.response?.status === 404) notFound.value = true
  }
}

// Chaîne de setTimeout (et non setInterval) : pas de chevauchement si une
// requête traîne.
const schedulePoll = () => {
  clearTimeout(pollTimer)
  if (!planInProgress()) return
  pollTimer = setTimeout(fetchTrip, POLL_DELAY)
}

const showErrors = (e, fallback) => {
  const errors = e.response?.data?.errors
  alert(errors ? errors.join('\n') : fallback)
}

const startEdit = () => { formErrors.value = []; editing.value = true }

const saveTrip = async (payload) => {
  saving.value = true
  formErrors.value = []
  try {
    trip.value = await update(props.id, { trip: payload })
    editing.value = false
  } catch (e) {
    formErrors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

const deleteTrip = async () => {
  if (!confirm(`Supprimer le voyage « ${trip.value.destination} » et son planning ?`)) return
  await destroy(props.id)
  router.push('/trips')
}

const generatePlan = async () => {
  try {
    const plan = await post(`/trips/${props.id}/plan`)
    trip.value = { ...trip.value, plan }
    schedulePoll()
  } catch (e) {
    showErrors(e, 'Impossible de lancer la génération')
  }
}

const createItem = async (payload) => {
  try {
    await post(`/trips/${props.id}/trip_items`, { trip_item: payload })
    await fetchTrip()
  } catch (e) {
    showErrors(e, 'Ajout impossible')
  }
}

const updateItem = async (itemId, payload) => {
  try {
    await patch(`/trips/${props.id}/trip_items/${itemId}`, { trip_item: payload })
    await fetchTrip()
  } catch (e) {
    showErrors(e, 'Modification impossible')
  }
}

const destroyItem = async (itemId) => {
  try {
    await del(`/trips/${props.id}/trip_items/${itemId}`)
    await fetchTrip()
  } catch (e) {
    showErrors(e, 'Suppression impossible')
  }
}

const addSuggestedItem = (payload) => createItem(payload)

onMounted(fetchTrip)
onUnmounted(() => clearTimeout(pollTimer))
</script>
