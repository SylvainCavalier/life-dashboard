<template>
  <div class="bg-white rounded-xl shadow-sm p-5">
    <h2 class="text-lg font-semibold text-gray-900 mb-4">{{ title }}</h2>

    <!-- Formulaire d'ajout -->
    <form @submit.prevent="addTask" class="mb-4 space-y-2">
      <input
        v-model="newTask.description"
        type="text"
        placeholder="Nouvelle tache..."
        class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        required
      />
      <div class="flex gap-2">
        <div class="flex items-center gap-1 flex-1">
          <span class="text-xs text-gray-500">Priorite :</span>
          <button
            v-for="star in 5"
            :key="star"
            type="button"
            @click="newTask.priority = star"
            class="text-lg leading-none"
            :class="star <= newTask.priority ? 'text-yellow-400' : 'text-gray-300'"
          >
            ★
          </button>
        </div>
        <input
          v-model="newTask.deadline"
          type="date"
          class="border border-gray-300 rounded-lg px-2 py-1 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
        />
      </div>
      <button
        type="submit"
        class="w-full bg-blue-600 text-white rounded-lg px-3 py-2 text-sm font-medium hover:bg-blue-700 transition-colors"
      >
        Ajouter
      </button>
    </form>

    <!-- Liste des taches -->
    <ul class="space-y-2">
      <li
        v-for="task in visibleTasks"
        :key="task.id"
        class="flex items-start gap-2 p-2 rounded-lg hover:bg-gray-50 group"
      >
        <input
          type="checkbox"
          :checked="task.completed"
          :disabled="editingId === task.id"
          @change="toggleTask(task)"
          class="mt-1 h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500 cursor-pointer disabled:opacity-40"
        />

        <!-- Mode edition -->
        <form
          v-if="editingId === task.id"
          @submit.prevent="saveTask(task)"
          class="flex-1 min-w-0 space-y-2"
        >
          <input
            ref="editInput"
            v-model="editForm.description"
            type="text"
            class="w-full border border-gray-300 rounded-lg px-2 py-1 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
            required
            @keyup.esc="cancelEdit"
          />
          <div class="flex items-center gap-2">
            <div class="flex items-center gap-0.5 flex-1">
              <button
                v-for="star in 5"
                :key="star"
                type="button"
                @click="editForm.priority = star"
                class="text-base leading-none"
                :class="star <= editForm.priority ? 'text-yellow-400' : 'text-gray-300'"
              >
                ★
              </button>
            </div>
            <input
              v-model="editForm.deadline"
              type="date"
              class="border border-gray-300 rounded-lg px-2 py-1 text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
            />
          </div>
          <div class="flex items-center gap-2">
            <button
              type="submit"
              class="text-xs font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-lg px-3 py-1 transition-colors"
            >
              Enregistrer
            </button>
            <button
              type="button"
              @click="cancelEdit"
              class="text-xs text-gray-500 hover:text-gray-700"
            >
              Annuler
            </button>
          </div>
        </form>

        <!-- Mode lecture -->
        <div v-else class="flex-1 min-w-0">
          <p
            class="text-sm leading-tight"
            :class="task.completed ? 'line-through text-gray-400' : 'text-gray-900'"
          >
            {{ task.description }}
          </p>
          <div class="flex items-center gap-2 mt-0.5">
            <span class="text-xs text-yellow-400 leading-none">
              {{ '★'.repeat(task.priority) }}<span class="text-gray-200">{{ '★'.repeat(5 - task.priority) }}</span>
            </span>
            <span v-if="task.deadline" class="text-xs" :class="deadlineClass(task)">
              {{ formatDate(task.deadline) }}
            </span>
          </div>
        </div>

        <button
          v-if="editingId !== task.id"
          @click="startEdit(task)"
          class="text-gray-400 hover:text-blue-600 transition-colors opacity-0 group-hover:opacity-100 p-1"
          title="Modifier"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button
          v-if="task.completed && editingId !== task.id"
          @click="deleteTask(task)"
          class="text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100 p-1"
          title="Supprimer"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </li>
    </ul>

    <!-- Vide -->
    <p v-if="tasks.length === 0" class="text-sm text-gray-400 text-center py-4">
      Aucune tache pour le moment
    </p>

    <!-- Voir plus -->
    <button
      v-if="tasks.length > 10 && !showAll"
      @click="showAll = true"
      class="mt-3 w-full text-sm text-blue-600 hover:text-blue-800 font-medium"
    >
      Voir plus ({{ tasks.length - 10 }} restantes)
    </button>
    <button
      v-if="showAll && tasks.length > 10"
      @click="showAll = false"
      class="mt-3 w-full text-sm text-blue-600 hover:text-blue-800 font-medium"
    >
      Voir moins
    </button>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue'
import { useApi } from '../composables/useApi'

// Sans projectId : to-do list generale du dashboard. Avec : to-do list du projet.
const props = defineProps({
  projectId: { type: [Number, String], default: null },
  title: { type: String, default: 'To-do list' },
})
const emit = defineEmits(['changed'])

const { useCrud } = useApi()
const tasksCrud = useCrud('tasks')

const tasks = ref([])
const showAll = ref(false)
const editingId = ref(null)
const editInput = ref(null)
const editForm = ref({
  description: '',
  priority: 3,
  deadline: '',
})
const newTask = ref({
  description: '',
  priority: 3,
  deadline: '',
})

const visibleTasks = computed(() => {
  return showAll.value ? tasks.value : tasks.value.slice(0, 10)
})

const fetchTasks = async () => {
  try {
    const data = await tasksCrud.list(props.projectId ? { project_id: props.projectId } : {})
    if (Array.isArray(data)) {
      tasks.value = data
      emit('changed', data)
    }
  } catch (e) {
    console.error('Erreur chargement taches:', e)
  }
}

const addTask = async () => {
  if (!newTask.value.description.trim()) return
  try {
    const payload = {
      task: {
        description: newTask.value.description.trim(),
        priority: newTask.value.priority,
        deadline: newTask.value.deadline || null,
        project_id: props.projectId || null,
      }
    }
    await tasksCrud.create(payload)
    newTask.value = { description: '', priority: 3, deadline: '' }
    await fetchTasks()
  } catch (e) {
    console.error('Erreur ajout tache:', e)
  }
}

const startEdit = async (task) => {
  editingId.value = task.id
  editForm.value = {
    description: task.description,
    priority: task.priority,
    deadline: task.deadline || '',
  }
  await nextTick()
  const input = Array.isArray(editInput.value) ? editInput.value[0] : editInput.value
  input?.focus()
}

const cancelEdit = () => {
  editingId.value = null
}

const saveTask = async (task) => {
  if (!editForm.value.description.trim()) return
  try {
    await tasksCrud.update(task.id, {
      task: {
        description: editForm.value.description.trim(),
        priority: editForm.value.priority,
        deadline: editForm.value.deadline || null,
      }
    })
    editingId.value = null
    await fetchTasks()
  } catch (e) {
    console.error('Erreur mise a jour tache:', e)
  }
}

const toggleTask = async (task) => {
  try {
    await tasksCrud.update(task.id, { task: { completed: !task.completed } })
    await fetchTasks()
  } catch (e) {
    console.error('Erreur mise a jour tache:', e)
  }
}

const deleteTask = async (task) => {
  try {
    await tasksCrud.destroy(task.id)
    tasks.value = tasks.value.filter(t => t.id !== task.id)
    emit('changed', tasks.value)
  } catch (e) {
    console.error('Erreur suppression tache:', e)
  }
}

const formatDate = (dateStr) => {
  const date = new Date(dateStr + 'T00:00:00')
  return date.toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' })
}

const deadlineClass = (task) => {
  if (task.completed) return 'text-gray-400'
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  const deadline = new Date(task.deadline + 'T00:00:00')
  if (deadline < today) return 'text-red-500 font-medium'
  if (deadline.getTime() - today.getTime() <= 2 * 86400000) return 'text-orange-500'
  return 'text-gray-500'
}

onMounted(fetchTasks)
</script>
