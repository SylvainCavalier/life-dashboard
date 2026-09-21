<template>
  <div class="bg-white rounded-xl shadow-sm p-6">
    <div class="flex items-center justify-between mb-4">
      <div>
        <h2 class="text-lg font-semibold text-gray-900">Planning du voyage</h2>
        <p class="text-xs text-gray-400">{{ days.length }} jour{{ days.length > 1 ? 's' : '' }} · {{ items.length }} élément{{ items.length > 1 ? 's' : '' }}<span v-if="totalCost"> · {{ formatCurrency(totalCost) }} planifiés</span></p>
      </div>
      <div class="flex items-center gap-3 text-xs text-gray-500">
        <span v-for="(label, kind) in kindLabels" :key="kind">{{ kindIcons[kind] }} {{ label }}</span>
      </div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
      <div v-for="(day, index) in days" :key="day" class="border border-gray-100 rounded-xl p-4 bg-gray-50/60 flex flex-col">
        <div class="flex items-center justify-between mb-3">
          <div>
            <span class="text-xs font-semibold text-indigo-600 uppercase">Jour {{ index + 1 }}</span>
            <h3 class="text-sm font-medium text-gray-800 capitalize">{{ formatDayLong(day) }}</h3>
          </div>
          <button @click="openForm(day)" class="text-xs text-indigo-600 hover:text-indigo-800 font-medium">+ Ajouter</button>
        </div>

        <div class="space-y-2 flex-1">
          <template v-for="item in itemsByDay[day] || []" :key="item.id">
            <ItemForm v-if="editingId === item.id" :initial="item" :days="days" @submit="submitEdit" @cancel="closeForm" />
            <div v-else class="bg-white rounded-lg border border-gray-100 px-3 py-2 group">
              <div class="flex items-start gap-2">
                <span class="text-base leading-6">{{ kindIcons[item.kind] || '📌' }}</span>
                <div class="flex-1 min-w-0">
                  <div class="flex items-baseline gap-2">
                    <span v-if="item.start_time" class="text-xs text-gray-400 tabular-nums">{{ item.start_time }}</span>
                    <a v-if="item.url" :href="item.url" target="_blank" rel="noopener" class="text-sm font-medium text-indigo-700 hover:underline truncate">{{ item.title }} ↗</a>
                    <span v-else class="text-sm font-medium text-gray-800 truncate">{{ item.title }}</span>
                  </div>
                  <p v-if="item.notes" class="text-xs text-gray-500 whitespace-pre-line">{{ item.notes }}</p>
                  <p v-if="item.cost !== null && item.cost !== undefined" class="text-xs text-gray-400">{{ formatCurrency(item.cost) }}</p>
                </div>
              </div>
              <div class="flex justify-end gap-3 mt-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <button @click="editingId = item.id; formDay = null" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
                <button @click="remove(item)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
              </div>
            </div>
          </template>

          <p v-if="!(itemsByDay[day] || []).length && formDay !== day" class="text-xs text-gray-300 italic">Rien de prévu</p>
          <ItemForm v-if="formDay === day" :initial="{ day }" :days="days" @submit="submitCreate" @cancel="closeForm" />
        </div>
      </div>
    </div>

    <!-- Éléments hors de la plage de dates (voyage modifié après coup) -->
    <div v-if="orphans.length" class="mt-6 border border-amber-200 bg-amber-50 rounded-xl p-4">
      <h3 class="text-sm font-semibold text-amber-800 mb-2">Hors dates du voyage</h3>
      <p class="text-xs text-amber-700 mb-3">Ces éléments ne correspondent plus aux dates du voyage. Déplace-les ou supprime-les.</p>
      <div class="space-y-2">
        <template v-for="item in orphans" :key="item.id">
          <ItemForm v-if="editingId === item.id" :initial="item" :days="days" @submit="submitEdit" @cancel="closeForm" />
          <div v-else class="bg-white rounded-lg px-3 py-2 flex items-center justify-between gap-3">
            <div class="text-sm text-gray-800 truncate">{{ kindIcons[item.kind] || '📌' }} {{ formatDayShort(item.day) }} · {{ item.title }}</div>
            <div class="flex gap-3 flex-shrink-0">
              <button @click="editingId = item.id; formDay = null" class="text-xs text-blue-500 hover:text-blue-700">Déplacer</button>
              <button @click="remove(item)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, defineComponent, h } from 'vue'
import { useTripDates } from '../../composables/useTripDates'

const props = defineProps({
  trip: { type: Object, required: true },
  items: { type: Array, default: () => [] },
})
const emit = defineEmits(['create', 'update', 'destroy'])

const { tripDays, formatDayLong, formatDayShort, formatCurrency } = useTripDates()

const kindLabels = { hotel: 'Hôtel', restaurant: 'Restaurant', visite: 'Visite', transport: 'Transport', autre: 'Autre' }
const kindIcons = { hotel: '🏨', restaurant: '🍽️', visite: '🎟️', transport: '🚆', autre: '📌' }

const days = computed(() => tripDays(props.trip.start_date, props.trip.end_date))
const daySet = computed(() => new Set(days.value))

const itemsByDay = computed(() => {
  const map = {}
  props.items.forEach(item => {
    if (!daySet.value.has(item.day)) return
    ;(map[item.day] ||= []).push(item)
  })
  return map
})

const orphans = computed(() => props.items.filter(item => !daySet.value.has(item.day)))

const totalCost = computed(() => props.items.reduce((sum, item) => sum + (Number(item.cost) || 0), 0))

const formDay = ref(null)
const editingId = ref(null)

const openForm = (day) => { formDay.value = day; editingId.value = null }
const closeForm = () => { formDay.value = null; editingId.value = null }

const submitCreate = (payload) => { emit('create', payload); closeForm() }
const submitEdit = (payload) => { emit('update', editingId.value, payload); closeForm() }
const remove = (item) => {
  if (!confirm(`Supprimer « ${item.title} » du planning ?`)) return
  emit('destroy', item.id)
}

// Mini-formulaire inline partagé entre création et édition.
const ItemForm = defineComponent({
  props: { initial: { type: Object, default: () => ({}) }, days: { type: Array, default: () => [] } },
  emits: ['submit', 'cancel'],
  setup(formProps, { emit: formEmit }) {
    const form = ref({
      day: formProps.initial.day || formProps.days[0] || '',
      kind: formProps.initial.kind || 'visite',
      title: formProps.initial.title || '',
      url: formProps.initial.url || '',
      start_time: formProps.initial.start_time || '',
      cost: formProps.initial.cost ?? '',
      notes: formProps.initial.notes || '',
    })
    const input = 'w-full border rounded-lg px-2 py-1.5 text-sm'
    const field = (label, node) => h('div', [h('label', { class: 'block text-xs text-gray-500 mb-0.5' }, label), node])
    const bind = (key, extra = {}) => ({
      value: form.value[key],
      onInput: e => { form.value[key] = e.target.value },
      class: input,
      ...extra,
    })
    const submit = () => {
      if (!form.value.title.trim() || !form.value.day) return
      const payload = { ...form.value }
      payload.cost = payload.cost === '' ? null : Number(payload.cost)
      payload.start_time = payload.start_time || null
      payload.url = payload.url.trim() || null
      formEmit('submit', payload)
    }
    return () => h('div', { class: 'bg-white rounded-lg border border-indigo-200 p-3 space-y-2' }, [
      h('div', { class: 'grid grid-cols-2 gap-2' }, [
        field('Type', h('select', bind('kind'), Object.entries(kindLabels).map(([v, l]) => h('option', { value: v }, `${kindIcons[v]} ${l}`)))),
        field('Jour', h('select', bind('day'), formProps.days.map(d => h('option', { value: d }, formatDayShort(d))))),
      ]),
      field('Titre *', h('input', bind('title', { type: 'text', placeholder: 'Hôtel, restaurant, visite...' }))),
      field('Lien', h('input', bind('url', { type: 'url', placeholder: 'https://' }))),
      h('div', { class: 'grid grid-cols-2 gap-2' }, [
        field('Heure', h('input', bind('start_time', { type: 'time' }))),
        field('Coût (€)', h('input', bind('cost', { type: 'number', min: '0', step: '0.01' }))),
      ]),
      field('Notes', h('textarea', bind('notes', { rows: 2 }))),
      h('div', { class: 'flex justify-end gap-2 pt-1' }, [
        h('button', { class: 'text-xs text-gray-500 hover:text-gray-700 px-3 py-1', onClick: () => formEmit('cancel') }, 'Annuler'),
        h('button', { class: 'bg-black text-white text-xs px-3 py-1.5 rounded-lg hover:bg-gray-800', onClick: submit }, formProps.initial.id ? 'Enregistrer' : 'Ajouter'),
      ]),
    ])
  },
})
</script>
