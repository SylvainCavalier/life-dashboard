<template>
  <div
    :id="`reminder-${reminder.id}`"
    :class="[
      'rounded-xl shadow-sm p-4 transition-all',
      due ? 'bg-red-50 border border-red-200' : 'bg-white',
      highlighted ? 'ring-2 ring-indigo-400' : '',
    ]"
  >
    <div class="flex items-start justify-between gap-3">
      <div class="min-w-0">
        <h3 class="font-semibold text-gray-900 break-words">{{ reminder.title }}</h3>
        <p class="text-xs mt-0.5" :class="due ? 'text-red-600' : 'text-gray-500'">
          {{ when }}
          <span v-if="reminder.recurring" class="ml-1 text-gray-400">· {{ reminder.recurrence_label }}</span>
          <span v-if="due && reminder.attempts" class="ml-1 text-gray-400">· {{ deliveryState }}</span>
        </p>
        <p v-if="reminder.notes" class="text-sm text-gray-600 whitespace-pre-line mt-2">{{ reminder.notes }}</p>
        <router-link
          v-if="reminder.remindable?.path"
          :to="reminder.remindable.path"
          class="inline-block text-xs text-indigo-600 hover:text-indigo-800 mt-2"
        >
          {{ reminder.remindable.label }} &rarr;
        </router-link>
      </div>
      <div class="flex gap-2 flex-shrink-0">
        <button @click="$emit('edit', reminder)" class="text-xs text-blue-500 hover:text-blue-700">Modifier</button>
        <button @click="$emit('remove', reminder)" class="text-xs text-red-400 hover:text-red-600">Supprimer</button>
      </div>
    </div>

    <div v-if="due" class="flex flex-wrap gap-2 mt-3">
      <button @click="$emit('done', reminder)" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
        {{ reminder.recurring ? 'Fait (occurrence suivante)' : 'Fait' }}
      </button>
      <button
        v-for="option in SNOOZES"
        :key="option.label"
        @click="$emit('snooze', reminder, option.value)"
        class="text-sm border border-gray-300 bg-white hover:border-gray-400 rounded-lg px-3 py-1.5"
      >
        {{ option.label }}
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  reminder: { type: Object, required: true },
  due: { type: Boolean, default: false },
  highlighted: { type: Boolean, default: false },
})
defineEmits(['done', 'snooze', 'edit', 'remove'])

const SNOOZES = [
  { label: '+10 min', value: 10 },
  { label: '+1 h', value: 60 },
  { label: 'Demain 9 h', value: 'tomorrow' },
]

const when = computed(() => {
  const d = new Date(props.reminder.remind_at)
  const time = d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })
  if (!props.due) return time
  return d.toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }) + ` à ${time}`
})

// Ou en est la livraison de l'occurrence en cours
const deliveryState = computed(() => {
  const r = props.reminder
  if (r.acknowledged_at) return 'notification vue'
  if (r.email_sent_at) return 'mail envoyé'
  return `notifié ${r.attempts} fois`
})
</script>
