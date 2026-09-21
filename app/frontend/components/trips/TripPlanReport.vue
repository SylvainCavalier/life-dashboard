<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <div class="flex items-start justify-between gap-4 mb-4">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Rapport IA</h2>
        <p v-if="plan?.generated_at && content" class="text-xs text-gray-400">
          Généré le {{ formatDateTime(plan.generated_at) }}<span v-if="plan.model"> · {{ plan.model }}</span>
        </p>
        <p v-else class="text-xs text-gray-400">Estimation des coûts, présentation de la destination, lieux, restaurants et itinéraire suggéré.</p>
      </div>
      <button
        @click="generate"
        :disabled="inProgress"
        class="flex-shrink-0 bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-indigo-700 transition disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <span v-if="inProgress">Génération en cours...</span>
        <span v-else-if="plan?.status === 'failed'">Réessayer</span>
        <span v-else-if="plan?.stuck">Relancer</span>
        <span v-else-if="content">Régénérer</span>
        <span v-else>Planifier avec l'IA</span>
      </button>
    </div>

    <!-- États -->
    <div v-if="inProgress" class="flex items-center gap-3 bg-indigo-50 text-indigo-800 text-sm rounded-lg px-4 py-3 mb-4">
      <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" /><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z" /></svg>
      L'agent recherche les prix et les informations sur le web. Compte 1 à 3 minutes, la page se met à jour toute seule.
    </div>
    <div v-else-if="plan?.stuck" class="bg-amber-50 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
      La génération semble bloquée (le serveur a peut-être redémarré). Tu peux la relancer.
    </div>
    <div v-else-if="plan?.status === 'failed'" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mb-4">
      <p class="font-medium">La génération a échoué.</p>
      <p class="text-xs mt-1 break-words">{{ plan.error }}</p>
    </div>
    <div v-if="plan?.outdated && content" class="bg-amber-50 text-amber-800 text-sm rounded-lg px-4 py-3 mb-4">
      Le voyage a été modifié depuis ce rapport (dates, destination ou voyageurs) : les estimations peuvent ne plus correspondre.
    </div>

    <div v-if="!content && !inProgress && plan?.status !== 'failed'" class="text-center text-gray-400 text-sm py-10">
      Aucun rapport pour l'instant. Clique sur « Planifier avec l'IA » pour lancer l'estimation.
    </div>

    <div v-if="content" class="space-y-8">
      <!-- Coûts -->
      <section v-if="content.costs">
        <h3 class="section-title">Estimation des coûts <span class="font-normal text-gray-400">pour {{ trip.travelers }} voyageur{{ trip.travelers > 1 ? 's' : '' }}, {{ trip.duration_days }} jours</span></h3>
        <div class="grid grid-cols-2 md:grid-cols-5 gap-3">
          <div class="stat"><span class="stat-label">Vols A/R</span><span class="stat-value">{{ formatCurrency(content.costs.flights_eur) }}</span></div>
          <div class="stat"><span class="stat-label">Hébergement / nuit</span><span class="stat-value">{{ formatCurrency(content.costs.lodging_per_night_eur) }}</span></div>
          <div class="stat"><span class="stat-label">Nourriture / jour</span><span class="stat-value">{{ formatCurrency(content.costs.food_per_day_eur) }}</span></div>
          <div class="stat"><span class="stat-label">Activités</span><span class="stat-value">{{ formatCurrency(content.costs.activities_eur) }}</span></div>
          <div class="stat bg-indigo-50"><span class="stat-label text-indigo-600">Total estimé</span><span class="stat-value text-indigo-700">{{ formatCurrency(content.costs.total_eur) }}</span></div>
        </div>
        <p v-if="content.costs.exchange_rate_note" class="text-xs text-gray-400 mt-2">{{ content.costs.local_currency }} · {{ content.costs.exchange_rate_note }}</p>
        <ul v-if="content.costs.assumptions?.length" class="text-xs text-gray-500 mt-2 list-disc list-inside">
          <li v-for="(a, i) in content.costs.assumptions" :key="i">{{ a }}</li>
        </ul>
      </section>

      <!-- Présentation et histoire -->
      <section v-if="content.summary">
        <h3 class="section-title">Présentation</h3>
        <p class="prose-text">{{ content.summary }}</p>
      </section>
      <section v-if="content.history">
        <h3 class="section-title">Un peu d'histoire</h3>
        <p class="prose-text">{{ content.history }}</p>
      </section>

      <!-- Infos pratiques -->
      <section v-if="content.practical_info?.length">
        <h3 class="section-title">Infos pratiques</h3>
        <dl class="grid grid-cols-1 md:grid-cols-2 gap-2">
          <div v-for="(info, i) in content.practical_info" :key="i" class="bg-gray-50 rounded-lg px-3 py-2">
            <dt class="text-xs font-medium text-gray-500">{{ info.label }}</dt>
            <dd class="text-sm text-gray-800">{{ info.value }}</dd>
          </div>
        </dl>
      </section>

      <!-- Règles -->
      <section v-if="content.rules?.length">
        <h3 class="section-title">Réglementations et interdictions</h3>
        <ul class="space-y-2">
          <li v-for="(rule, i) in content.rules" :key="i" class="border-l-2 border-red-300 pl-3">
            <p class="text-sm font-medium text-gray-800">{{ rule.title }}</p>
            <p class="text-sm text-gray-600">{{ rule.detail }}</p>
          </li>
        </ul>
      </section>

      <!-- Lieux -->
      <section v-if="content.places?.length">
        <h3 class="section-title">À visiter</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div v-for="(place, i) in content.places" :key="i" class="border border-gray-100 rounded-lg p-3">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-900">{{ place.name }} <span class="text-xs font-normal text-gray-400">· {{ place.city }}</span></p>
                <p class="text-sm text-gray-600 mt-0.5">{{ place.description }}</p>
                <p class="text-xs text-gray-500 mt-1">
                  <span v-if="place.price_eur !== null && place.price_eur !== undefined">{{ place.price_eur > 0 ? formatCurrency(place.price_eur) + ' / pers.' : 'Gratuit' }}</span>
                  <span v-if="place.price_note"> · {{ place.price_note }}</span>
                  <a v-if="place.booking_url" :href="place.booking_url" target="_blank" rel="noopener" class="text-indigo-600 hover:underline ml-1">Réserver ↗</a>
                </p>
              </div>
              <AddPicker :days="days" @add="day => addItem(day, 'visite', place.name, place.booking_url, place.description, place.price_eur)" />
            </div>
          </div>
        </div>
      </section>

      <!-- Restaurants -->
      <section v-if="content.restaurants?.length">
        <h3 class="section-title">Où manger</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <div v-for="(resto, i) in content.restaurants" :key="i" class="border border-gray-100 rounded-lg p-3">
            <div class="flex items-start justify-between gap-2">
              <div class="min-w-0">
                <p class="text-sm font-medium text-gray-900">
                  {{ resto.name }} <span class="text-xs font-normal text-gray-400">· {{ resto.city }} · {{ resto.price_range }}</span>
                </p>
                <p class="text-sm text-gray-600">{{ resto.cuisine }}<span v-if="resto.note"> — {{ resto.note }}</span></p>
                <a v-if="resto.url" :href="resto.url" target="_blank" rel="noopener" class="text-xs text-indigo-600 hover:underline">Voir ↗</a>
              </div>
              <AddPicker :days="days" @add="day => addItem(day, 'restaurant', resto.name, resto.url, resto.note)" />
            </div>
          </div>
        </div>
      </section>

      <!-- Itinéraire suggéré -->
      <section v-if="content.itinerary?.length">
        <h3 class="section-title">Itinéraire suggéré</h3>
        <div class="space-y-3">
          <div v-for="dayPlan in content.itinerary" :key="dayPlan.day_number" class="border border-gray-100 rounded-lg p-3">
            <div class="flex items-center justify-between gap-2 mb-2">
              <p class="text-sm font-semibold text-gray-800">
                Jour {{ dayPlan.day_number }} <span class="font-normal text-gray-400 capitalize">· {{ formatDayLong(dayFor(dayPlan.day_number)) }}</span> — {{ dayPlan.title }}
              </p>
              <button @click="addDay(dayPlan)" class="text-xs text-indigo-600 hover:text-indigo-800 whitespace-nowrap">+ Ajouter la journée</button>
            </div>
            <ul class="space-y-1">
              <li v-for="(act, i) in dayPlan.activities" :key="i" class="flex items-start gap-2 text-sm">
                <span class="text-xs text-gray-400 w-20 flex-shrink-0 pt-0.5">{{ momentLabels[act.moment] || act.moment }}</span>
                <div class="flex-1 min-w-0">
                  <span class="text-gray-800 font-medium">{{ act.title }}</span>
                  <span class="text-gray-600"> — {{ act.description }}</span>
                  <a v-if="act.url" :href="act.url" target="_blank" rel="noopener" class="text-indigo-600 hover:underline ml-1">↗</a>
                </div>
                <button @click="addActivity(dayPlan, act)" class="text-xs text-gray-400 hover:text-indigo-600 flex-shrink-0" title="Ajouter au planning">+</button>
              </li>
            </ul>
          </div>
        </div>
      </section>

      <!-- Sources -->
      <section v-if="content.sources?.length">
        <h3 class="section-title">Sources consultées</h3>
        <ul class="text-xs space-y-1">
          <li v-for="(src, i) in content.sources" :key="i">
            <a :href="src.url" target="_blank" rel="noopener" class="text-indigo-600 hover:underline break-all">{{ src.title || src.url }}</a>
          </li>
        </ul>
      </section>
    </div>
  </div>
</template>

<script setup>
import { computed, defineComponent, h, ref } from 'vue'
import { useTripDates } from '../../composables/useTripDates'

const props = defineProps({
  trip: { type: Object, required: true },
  plan: { type: Object, default: null },
  // Contenu à afficher : le dernier rapport connu, conservé côté page pendant
  // une régénération (le serveur ne renvoie le contenu qu'en statut done).
  content: { type: Object, default: null },
})
const emit = defineEmits(['generate', 'add-item'])

const { tripDays, formatDayLong, formatDayShort, formatDateTime, formatCurrency, addDays } = useTripDates()

const momentLabels = { matin: 'Matin', midi: 'Midi', apres_midi: 'Après-midi', soir: 'Soir' }

const inProgress = computed(() => ['pending', 'running'].includes(props.plan?.status) && !props.plan?.stuck)
const days = computed(() => tripDays(props.trip.start_date, props.trip.end_date))

const generate = () => {
  if (props.content && !confirm('Régénérer le rapport ? L\'actuel sera remplacé une fois la nouvelle version prête.')) return
  emit('generate')
}

// Jour du planning correspondant au jour N de l'itinéraire, borné aux dates du voyage.
const dayFor = (dayNumber) => {
  const index = Math.min(Math.max(dayNumber - 1, 0), days.value.length - 1)
  return days.value[index] || addDays(props.trip.start_date, dayNumber - 1)
}

const restaurantNames = computed(() => new Set((props.content?.restaurants || []).map(r => r.name)))

const addItem = (day, kind, title, url, notes, cost) => {
  emit('add-item', { day, kind, title, url: url || null, notes: notes || null, cost: cost ?? null })
}

const activityKind = (act) => {
  if (act.place_name && restaurantNames.value.has(act.place_name)) return 'restaurant'
  if (['midi', 'soir'].includes(act.moment) && /(déjeuner|dîner|diner|restaurant|repas)/i.test(`${act.title} ${act.description}`)) return 'restaurant'
  return 'visite'
}

const addActivity = (dayPlan, act) => {
  addItem(dayFor(dayPlan.day_number), activityKind(act), act.title, act.url, act.description)
}

const addDay = (dayPlan) => {
  if (!confirm(`Ajouter les ${dayPlan.activities.length} activités du jour ${dayPlan.day_number} au planning ?`)) return
  dayPlan.activities.forEach(act => addActivity(dayPlan, act))
}

// Petit sélecteur de jour pour « Ajouter au planning ».
const AddPicker = defineComponent({
  props: { days: { type: Array, default: () => [] } },
  emits: ['add'],
  setup(pickerProps, { emit: pickerEmit }) {
    const open = ref(false)
    const day = ref(pickerProps.days[0] || '')
    return () => open.value
      ? h('div', { class: 'flex items-center gap-1 flex-shrink-0' }, [
        h('select', {
          class: 'border rounded-lg px-1.5 py-1 text-xs',
          value: day.value,
          onChange: e => { day.value = e.target.value },
        }, pickerProps.days.map(d => h('option', { value: d }, formatDayShort(d)))),
        h('button', { class: 'bg-black text-white text-xs px-2 py-1 rounded-lg', onClick: () => { pickerEmit('add', day.value); open.value = false } }, 'OK'),
        h('button', { class: 'text-xs text-gray-400 px-1', onClick: () => { open.value = false } }, '✕'),
      ])
      : h('button', {
        class: 'text-xs text-indigo-600 hover:text-indigo-800 whitespace-nowrap flex-shrink-0',
        onClick: () => { day.value = pickerProps.days[0] || ''; open.value = true },
      }, '+ Planning')
  },
})
</script>

<style scoped>
.section-title { @apply text-sm font-semibold text-gray-700 mb-3 border-b pb-2; }
.prose-text { @apply text-sm text-gray-700 whitespace-pre-line leading-relaxed; }
.stat { @apply bg-gray-50 rounded-lg p-3 flex flex-col; }
.stat-label { @apply text-xs text-gray-500; }
.stat-value { @apply text-base font-semibold text-gray-900; }
</style>
