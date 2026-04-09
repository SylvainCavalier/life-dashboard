<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-6xl mx-auto">
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
            <span class="text-3xl">💰</span>
            <h1 class="text-2xl font-bold text-gray-900">Budget</h1>
          </div>
          <div class="flex items-center gap-3">
            <!-- Selecteur de vue -->
            <div class="flex bg-gray-100 rounded-lg p-0.5">
              <button
                @click="activeView = 'monthly'"
                :class="activeView === 'monthly' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'"
                class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
              >
                Mensuel
              </button>
              <button
                @click="activeView = 'annual'"
                :class="activeView === 'annual' ? 'bg-white shadow-sm text-gray-900' : 'text-gray-500 hover:text-gray-700'"
                class="px-3 py-1.5 rounded-md text-sm font-medium transition-colors"
              >
                Annuel
              </button>
            </div>
            <button
              @click="openForm()"
              class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
            >
              {{ showForm ? 'Annuler' : '+ Ajouter' }}
            </button>
          </div>
        </div>

        <!-- Formulaire d'ajout / edition -->
        <form v-if="showForm" @submit.prevent="saveEntry" class="mb-6 p-5 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            <input
              v-model="form.name"
              type="text"
              placeholder="Nom *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.amount"
              type="number"
              step="0.01"
              min="0"
              placeholder="Montant (€) *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <select
              v-model="form.entry_type"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="" disabled>Type *</option>
              <option value="income">Revenu</option>
              <option value="expense">Depense</option>
            </select>
            <select
              v-model="form.recurrence"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="fixed">Fixe (mensuel)</option>
              <option value="variable">Variable (ponctuel)</option>
            </select>
            <select
              v-model="form.category"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Categorie</option>
              <optgroup label="Revenus">
                <option v-for="cat in incomeCategories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
              </optgroup>
              <optgroup label="Depenses">
                <option v-for="cat in expenseCategories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
              </optgroup>
            </select>
            <template v-if="form.recurrence === 'variable'">
              <div class="flex gap-2">
                <select
                  v-model="form.month"
                  required
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  <option value="" disabled>Mois *</option>
                  <option v-for="m in months" :key="m.value" :value="m.value">{{ m.label }}</option>
                </select>
                <select
                  v-model="form.year"
                  required
                  class="w-28 px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  <option value="" disabled>Annee *</option>
                  <option v-for="y in years" :key="y" :value="y">{{ y }}</option>
                </select>
              </div>
            </template>
          </div>
          <div class="mt-3">
            <textarea
              v-model="form.notes"
              placeholder="Notes (optionnel)"
              rows="2"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>
          <div class="mt-3 flex gap-2">
            <button
              type="submit"
              class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
            >
              {{ editingId ? 'Modifier' : 'Enregistrer' }}
            </button>
            <button
              v-if="editingId"
              type="button"
              @click="cancelEdit"
              class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors text-sm font-medium"
            >
              Annuler
            </button>
          </div>
        </form>

        <!-- ==================== VUE MENSUELLE ==================== -->
        <template v-if="activeView === 'monthly'">
          <!-- Selecteur de mois -->
          <div class="flex items-center justify-center gap-4 mb-6">
            <button @click="prevMonth" class="p-1 rounded hover:bg-gray-100">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <h2 class="text-lg font-semibold text-gray-900 w-48 text-center">
              {{ monthName(selectedMonth) }} {{ selectedYear }}
            </h2>
            <button @click="nextMonth" class="p-1 rounded hover:bg-gray-100">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          <!-- Cartes de resume mensuel -->
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div class="bg-green-50 rounded-lg p-4">
              <p class="text-sm text-green-600 font-medium">Revenus fixes</p>
              <p class="text-xl font-bold text-green-900">{{ formatMoney(monthlyFixedIncome) }}</p>
            </div>
            <div class="bg-emerald-50 rounded-lg p-4">
              <p class="text-sm text-emerald-600 font-medium">Revenus variables</p>
              <p class="text-xl font-bold text-emerald-900">{{ formatMoney(monthlyVariableIncome) }}</p>
            </div>
            <div class="bg-red-50 rounded-lg p-4">
              <p class="text-sm text-red-600 font-medium">Depenses fixes</p>
              <p class="text-xl font-bold text-red-900">{{ formatMoney(monthlyFixedExpense) }}</p>
            </div>
            <div class="bg-orange-50 rounded-lg p-4">
              <p class="text-sm text-orange-600 font-medium">Depenses variables</p>
              <p class="text-xl font-bold text-orange-900">{{ formatMoney(monthlyVariableExpense) }}</p>
            </div>
          </div>

          <!-- Solde mensuel -->
          <div
            class="rounded-lg p-4 mb-6 text-center"
            :class="monthlyBalance >= 0 ? 'bg-green-100 border border-green-300' : 'bg-red-100 border border-red-300'"
          >
            <p class="text-sm font-medium" :class="monthlyBalance >= 0 ? 'text-green-700' : 'text-red-700'">
              Solde du mois
            </p>
            <p class="text-2xl font-bold" :class="monthlyBalance >= 0 ? 'text-green-900' : 'text-red-900'">
              {{ monthlyBalance >= 0 ? '+' : '' }}{{ formatMoney(monthlyBalance) }}
            </p>
            <p class="text-xs mt-1" :class="monthlyBalance >= 0 ? 'text-green-600' : 'text-red-600'">
              Revenus: {{ formatMoney(monthlyTotalIncome) }} — Depenses: {{ formatMoney(monthlyTotalExpense) }}
            </p>
          </div>

          <!-- Moyennes lissees -->
          <div v-if="hasVariableData" class="bg-indigo-50 rounded-lg p-4 mb-6">
            <p class="text-sm text-indigo-600 font-medium mb-2">Revenus variables — Moyenne lissee</p>
            <div class="grid grid-cols-3 gap-4">
              <div>
                <p class="text-xs text-indigo-500">3 derniers mois</p>
                <p class="text-lg font-bold text-indigo-900">{{ formatMoney(avgVariableIncome(3)) }}</p>
              </div>
              <div>
                <p class="text-xs text-indigo-500">6 derniers mois</p>
                <p class="text-lg font-bold text-indigo-900">{{ formatMoney(avgVariableIncome(6)) }}</p>
              </div>
              <div>
                <p class="text-xs text-indigo-500">12 derniers mois</p>
                <p class="text-lg font-bold text-indigo-900">{{ formatMoney(avgVariableIncome(12)) }}</p>
              </div>
            </div>
            <div class="mt-3 pt-3 border-t border-indigo-200">
              <p class="text-xs text-indigo-500">Seuil de rentabilite (charges fixes mensuelles)</p>
              <p class="text-lg font-bold text-indigo-900">{{ formatMoney(monthlyFixedExpense - monthlyFixedIncome) }} / mois a couvrir en variable</p>
            </div>
          </div>

          <!-- Tableau des entrees fixes -->
          <div class="mb-6">
            <h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wider mb-3">Entrees fixes (mensuelles)</h3>
            <div v-if="fixedEntries.length === 0" class="text-center text-gray-400 py-6 text-sm">
              Aucune entree fixe
            </div>
            <table v-else class="w-full">
              <thead>
                <tr class="border-b border-gray-200 text-left text-sm text-gray-500">
                  <th class="pb-3 font-medium">Nom</th>
                  <th class="pb-3 font-medium">Type</th>
                  <th class="pb-3 font-medium">Categorie</th>
                  <th class="pb-3 font-medium text-right">Montant</th>
                  <th class="pb-3 font-medium w-24"></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="entry in fixedEntries"
                  :key="entry.id"
                  class="border-b border-gray-100 hover:bg-gray-50"
                >
                  <td class="py-3 text-sm text-gray-900 font-medium">{{ entry.name }}</td>
                  <td class="py-3 text-sm">
                    <span
                      class="px-2 py-0.5 rounded-full text-xs font-medium"
                      :class="entry.entry_type === 'income' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'"
                    >
                      {{ entry.entry_type === 'income' ? 'Revenu' : 'Depense' }}
                    </span>
                  </td>
                  <td class="py-3 text-sm">
                    <span v-if="entry.category" class="px-2 py-0.5 rounded-full text-xs font-medium" :class="categoryBadgeClass(entry.category)">
                      {{ categoryLabel(entry.category) }}
                    </span>
                    <span v-else class="text-gray-400">—</span>
                  </td>
                  <td class="py-3 text-sm text-right font-medium" :class="entry.entry_type === 'income' ? 'text-green-700' : 'text-red-700'">
                    {{ entry.entry_type === 'income' ? '+' : '-' }}{{ formatMoney(entry.amount) }}
                  </td>
                  <td class="py-3 text-right flex gap-2 justify-end">
                    <button @click="editEntry(entry)" class="text-gray-400 hover:text-indigo-600 text-sm" title="Modifier">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                      </svg>
                    </button>
                    <button @click="deleteEntry(entry.id)" class="text-red-400 hover:text-red-600 text-sm" title="Supprimer">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <!-- Tableau des entrees variables du mois -->
          <div>
            <h3 class="text-sm font-semibold text-gray-700 uppercase tracking-wider mb-3">
              Entrees variables — {{ monthName(selectedMonth) }} {{ selectedYear }}
            </h3>
            <div v-if="monthVariableEntries.length === 0" class="text-center text-gray-400 py-6 text-sm">
              Aucune entree variable pour ce mois
            </div>
            <table v-else class="w-full">
              <thead>
                <tr class="border-b border-gray-200 text-left text-sm text-gray-500">
                  <th class="pb-3 font-medium">Nom</th>
                  <th class="pb-3 font-medium">Type</th>
                  <th class="pb-3 font-medium">Categorie</th>
                  <th class="pb-3 font-medium">Notes</th>
                  <th class="pb-3 font-medium text-right">Montant</th>
                  <th class="pb-3 font-medium w-24"></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="entry in monthVariableEntries"
                  :key="entry.id"
                  class="border-b border-gray-100 hover:bg-gray-50"
                >
                  <td class="py-3 text-sm text-gray-900 font-medium">{{ entry.name }}</td>
                  <td class="py-3 text-sm">
                    <span
                      class="px-2 py-0.5 rounded-full text-xs font-medium"
                      :class="entry.entry_type === 'income' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'"
                    >
                      {{ entry.entry_type === 'income' ? 'Revenu' : 'Depense' }}
                    </span>
                  </td>
                  <td class="py-3 text-sm">
                    <span v-if="entry.category" class="px-2 py-0.5 rounded-full text-xs font-medium" :class="categoryBadgeClass(entry.category)">
                      {{ categoryLabel(entry.category) }}
                    </span>
                    <span v-else class="text-gray-400">—</span>
                  </td>
                  <td class="py-3 text-sm text-gray-500 max-w-xs truncate">{{ entry.notes || '—' }}</td>
                  <td class="py-3 text-sm text-right font-medium" :class="entry.entry_type === 'income' ? 'text-green-700' : 'text-red-700'">
                    {{ entry.entry_type === 'income' ? '+' : '-' }}{{ formatMoney(entry.amount) }}
                  </td>
                  <td class="py-3 text-right flex gap-2 justify-end">
                    <button @click="editEntry(entry)" class="text-gray-400 hover:text-indigo-600 text-sm" title="Modifier">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                      </svg>
                    </button>
                    <button @click="deleteEntry(entry.id)" class="text-red-400 hover:text-red-600 text-sm" title="Supprimer">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </template>

        <!-- ==================== VUE ANNUELLE ==================== -->
        <template v-if="activeView === 'annual'">
          <!-- Selecteur d'annee -->
          <div class="flex items-center justify-center gap-4 mb-6">
            <button @click="selectedYear--" class="p-1 rounded hover:bg-gray-100">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <h2 class="text-lg font-semibold text-gray-900 w-24 text-center">{{ selectedYear }}</h2>
            <button @click="selectedYear++" class="p-1 rounded hover:bg-gray-100">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>

          <!-- Totaux annuels -->
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div class="bg-green-50 rounded-lg p-4">
              <p class="text-sm text-green-600 font-medium">Total revenus</p>
              <p class="text-xl font-bold text-green-900">{{ formatMoney(annualTotalIncome) }}</p>
            </div>
            <div class="bg-red-50 rounded-lg p-4">
              <p class="text-sm text-red-600 font-medium">Total depenses</p>
              <p class="text-xl font-bold text-red-900">{{ formatMoney(annualTotalExpense) }}</p>
            </div>
            <div
              class="rounded-lg p-4"
              :class="annualBalance >= 0 ? 'bg-emerald-50' : 'bg-orange-50'"
            >
              <p class="text-sm font-medium" :class="annualBalance >= 0 ? 'text-emerald-600' : 'text-orange-600'">Solde annuel</p>
              <p class="text-xl font-bold" :class="annualBalance >= 0 ? 'text-emerald-900' : 'text-orange-900'">
                {{ annualBalance >= 0 ? '+' : '' }}{{ formatMoney(annualBalance) }}
              </p>
            </div>
            <div class="bg-indigo-50 rounded-lg p-4">
              <p class="text-sm text-indigo-600 font-medium">Moyenne mensuelle</p>
              <p class="text-xl font-bold text-indigo-900">{{ formatMoney(annualBalance / 12) }}</p>
            </div>
          </div>

          <!-- Grille annuelle mois par mois -->
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-gray-200 text-left text-gray-500">
                  <th class="pb-3 font-medium">Mois</th>
                  <th class="pb-3 font-medium text-right">Revenus fixes</th>
                  <th class="pb-3 font-medium text-right">Revenus var.</th>
                  <th class="pb-3 font-medium text-right text-green-600">Total revenus</th>
                  <th class="pb-3 font-medium text-right">Depenses fixes</th>
                  <th class="pb-3 font-medium text-right">Depenses var.</th>
                  <th class="pb-3 font-medium text-right text-red-600">Total depenses</th>
                  <th class="pb-3 font-medium text-right">Solde</th>
                  <th class="pb-3 font-medium text-right">Cumul</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  v-for="row in annualGrid"
                  :key="row.month"
                  class="border-b border-gray-100 hover:bg-gray-50 cursor-pointer"
                  @click="goToMonth(row.month)"
                >
                  <td class="py-3 font-medium text-gray-900">{{ monthName(row.month) }}</td>
                  <td class="py-3 text-right text-green-600">{{ formatMoney(row.fixedIncome) }}</td>
                  <td class="py-3 text-right text-emerald-600">{{ formatMoney(row.variableIncome) }}</td>
                  <td class="py-3 text-right font-medium text-green-700">{{ formatMoney(row.totalIncome) }}</td>
                  <td class="py-3 text-right text-red-500">{{ formatMoney(row.fixedExpense) }}</td>
                  <td class="py-3 text-right text-orange-500">{{ formatMoney(row.variableExpense) }}</td>
                  <td class="py-3 text-right font-medium text-red-700">{{ formatMoney(row.totalExpense) }}</td>
                  <td class="py-3 text-right font-semibold" :class="row.balance >= 0 ? 'text-green-700' : 'text-red-700'">
                    {{ row.balance >= 0 ? '+' : '' }}{{ formatMoney(row.balance) }}
                  </td>
                  <td class="py-3 text-right font-semibold" :class="row.cumulative >= 0 ? 'text-green-700' : 'text-red-700'">
                    {{ row.cumulative >= 0 ? '+' : '' }}{{ formatMoney(row.cumulative) }}
                  </td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="border-t-2 border-gray-300 font-bold">
                  <td class="py-3 text-gray-900">Total</td>
                  <td class="py-3 text-right text-green-600">{{ formatMoney(monthlyFixedIncome * 12) }}</td>
                  <td class="py-3 text-right text-emerald-600">{{ formatMoney(annualVariableIncomeTotal) }}</td>
                  <td class="py-3 text-right text-green-700">{{ formatMoney(annualTotalIncome) }}</td>
                  <td class="py-3 text-right text-red-500">{{ formatMoney(monthlyFixedExpense * 12) }}</td>
                  <td class="py-3 text-right text-orange-500">{{ formatMoney(annualVariableExpenseTotal) }}</td>
                  <td class="py-3 text-right text-red-700">{{ formatMoney(annualTotalExpense) }}</td>
                  <td class="py-3 text-right" :class="annualBalance >= 0 ? 'text-green-700' : 'text-red-700'">
                    {{ annualBalance >= 0 ? '+' : '' }}{{ formatMoney(annualBalance) }}
                  </td>
                  <td class="py-3"></td>
                </tr>
              </tfoot>
            </table>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud, get } = useApi()
const { list, create, update, destroy } = useCrud('budget_entries')

const entries = ref([])
const showForm = ref(false)
const editingId = ref(null)
const activeView = ref('monthly')

const now = new Date()
const selectedMonth = ref(now.getMonth() + 1)
const selectedYear = ref(now.getFullYear())

const months = [
  { value: 1, label: 'Janvier' }, { value: 2, label: 'Fevrier' }, { value: 3, label: 'Mars' },
  { value: 4, label: 'Avril' }, { value: 5, label: 'Mai' }, { value: 6, label: 'Juin' },
  { value: 7, label: 'Juillet' }, { value: 8, label: 'Aout' }, { value: 9, label: 'Septembre' },
  { value: 10, label: 'Octobre' }, { value: 11, label: 'Novembre' }, { value: 12, label: 'Decembre' },
]

const years = computed(() => {
  const current = new Date().getFullYear()
  return Array.from({ length: 7 }, (_, i) => current - 3 + i)
})

const incomeCategories = [
  { value: 'salaire', label: 'Salaire' },
  { value: 'freelance', label: 'Freelance' },
  { value: 'loyer_percu', label: 'Loyer percu' },
  { value: 'investissement', label: 'Investissement' },
  { value: 'autre_revenu', label: 'Autre revenu' },
]

const expenseCategories = [
  { value: 'loyer', label: 'Loyer' },
  { value: 'credit', label: 'Credit' },
  { value: 'assurance', label: 'Assurance' },
  { value: 'abonnement', label: 'Abonnement' },
  { value: 'impot', label: 'Impots' },
  { value: 'taxe_fonciere', label: 'Taxe fonciere' },
  { value: 'charge', label: 'Charges' },
  { value: 'transport', label: 'Transport' },
  { value: 'sante', label: 'Sante' },
  { value: 'education', label: 'Education' },
  { value: 'autre_depense', label: 'Autre depense' },
]

const allCategories = [...incomeCategories, ...expenseCategories]
const categoryLabels = Object.fromEntries(allCategories.map(c => [c.value, c.label]))

const categoryColors = {
  salaire: 'bg-green-100 text-green-700',
  freelance: 'bg-emerald-100 text-emerald-700',
  loyer_percu: 'bg-teal-100 text-teal-700',
  investissement: 'bg-cyan-100 text-cyan-700',
  autre_revenu: 'bg-lime-100 text-lime-700',
  loyer: 'bg-red-100 text-red-700',
  credit: 'bg-rose-100 text-rose-700',
  assurance: 'bg-yellow-100 text-yellow-700',
  abonnement: 'bg-blue-100 text-blue-700',
  impot: 'bg-orange-100 text-orange-700',
  taxe_fonciere: 'bg-amber-100 text-amber-700',
  charge: 'bg-pink-100 text-pink-700',
  transport: 'bg-violet-100 text-violet-700',
  sante: 'bg-fuchsia-100 text-fuchsia-700',
  education: 'bg-indigo-100 text-indigo-700',
  autre_depense: 'bg-gray-100 text-gray-700',
}

const defaultForm = {
  name: '',
  amount: '',
  entry_type: '',
  recurrence: 'fixed',
  category: '',
  month: '',
  year: '',
  notes: '',
}

const form = reactive({ ...defaultForm })

const categoryLabel = (value) => categoryLabels[value] || value
const categoryBadgeClass = (value) => categoryColors[value] || 'bg-gray-100 text-gray-700'
const monthName = (m) => months.find(mo => mo.value === m)?.label || ''

const formatMoney = (val) => {
  const num = parseFloat(val) || 0
  return num.toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' €'
}

// --- Donnees filtrees ---

const fixedEntries = computed(() =>
  entries.value.filter(e => e.recurrence === 'fixed').sort((a, b) => a.name.localeCompare(b.name, 'fr'))
)

const variableEntries = computed(() =>
  entries.value.filter(e => e.recurrence === 'variable')
)

const monthVariableEntries = computed(() =>
  variableEntries.value
    .filter(e => e.month === selectedMonth.value && e.year === selectedYear.value)
    .sort((a, b) => a.name.localeCompare(b.name, 'fr'))
)

// --- Calculs mensuels ---

const monthlyFixedIncome = computed(() =>
  fixedEntries.value.filter(e => e.entry_type === 'income').reduce((s, e) => s + parseFloat(e.amount), 0)
)

const monthlyFixedExpense = computed(() =>
  fixedEntries.value.filter(e => e.entry_type === 'expense').reduce((s, e) => s + parseFloat(e.amount), 0)
)

const monthlyVariableIncome = computed(() =>
  monthVariableEntries.value.filter(e => e.entry_type === 'income').reduce((s, e) => s + parseFloat(e.amount), 0)
)

const monthlyVariableExpense = computed(() =>
  monthVariableEntries.value.filter(e => e.entry_type === 'expense').reduce((s, e) => s + parseFloat(e.amount), 0)
)

const monthlyTotalIncome = computed(() => monthlyFixedIncome.value + monthlyVariableIncome.value)
const monthlyTotalExpense = computed(() => monthlyFixedExpense.value + monthlyVariableExpense.value)
const monthlyBalance = computed(() => monthlyTotalIncome.value - monthlyTotalExpense.value)

// --- Moyenne lissee ---

const hasVariableData = computed(() => variableEntries.value.length > 0)

const avgVariableIncome = (nMonths) => {
  const result = []
  let m = selectedMonth.value
  let y = selectedYear.value
  for (let i = 0; i < nMonths; i++) {
    const monthEntries = variableEntries.value.filter(e => e.month === m && e.year === y && e.entry_type === 'income')
    result.push(monthEntries.reduce((s, e) => s + parseFloat(e.amount), 0))
    m--
    if (m === 0) { m = 12; y-- }
  }
  return result.reduce((a, b) => a + b, 0) / nMonths
}

// --- Calculs annuels ---

const variableForYear = computed(() =>
  variableEntries.value.filter(e => e.year === selectedYear.value)
)

const annualVariableIncomeTotal = computed(() =>
  variableForYear.value.filter(e => e.entry_type === 'income').reduce((s, e) => s + parseFloat(e.amount), 0)
)

const annualVariableExpenseTotal = computed(() =>
  variableForYear.value.filter(e => e.entry_type === 'expense').reduce((s, e) => s + parseFloat(e.amount), 0)
)

const annualTotalIncome = computed(() => monthlyFixedIncome.value * 12 + annualVariableIncomeTotal.value)
const annualTotalExpense = computed(() => monthlyFixedExpense.value * 12 + annualVariableExpenseTotal.value)
const annualBalance = computed(() => annualTotalIncome.value - annualTotalExpense.value)

const annualGrid = computed(() => {
  let cumulative = 0
  return Array.from({ length: 12 }, (_, i) => {
    const m = i + 1
    const monthVar = variableForYear.value.filter(e => e.month === m)
    const varIncome = monthVar.filter(e => e.entry_type === 'income').reduce((s, e) => s + parseFloat(e.amount), 0)
    const varExpense = monthVar.filter(e => e.entry_type === 'expense').reduce((s, e) => s + parseFloat(e.amount), 0)
    const totalIncome = monthlyFixedIncome.value + varIncome
    const totalExpense = monthlyFixedExpense.value + varExpense
    const balance = totalIncome - totalExpense
    cumulative += balance
    return {
      month: m,
      fixedIncome: monthlyFixedIncome.value,
      variableIncome: varIncome,
      totalIncome,
      fixedExpense: monthlyFixedExpense.value,
      variableExpense: varExpense,
      totalExpense,
      balance,
      cumulative,
    }
  })
})

// --- Navigation ---

const prevMonth = () => {
  if (selectedMonth.value === 1) {
    selectedMonth.value = 12
    selectedYear.value--
  } else {
    selectedMonth.value--
  }
}

const nextMonth = () => {
  if (selectedMonth.value === 12) {
    selectedMonth.value = 1
    selectedYear.value++
  } else {
    selectedMonth.value++
  }
}

const goToMonth = (month) => {
  selectedMonth.value = month
  activeView.value = 'monthly'
}

// --- CRUD ---

const fetchEntries = async () => {
  entries.value = await list()
}

const openForm = () => {
  if (showForm.value && !editingId.value) {
    showForm.value = false
    return
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm, month: selectedMonth.value, year: selectedYear.value })
  showForm.value = true
}

const saveEntry = async () => {
  const data = { budget_entry: { ...form } }
  if (form.recurrence === 'fixed') {
    data.budget_entry.month = null
    data.budget_entry.year = null
  }
  if (editingId.value) {
    await update(editingId.value, data)
  } else {
    await create(data)
  }
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = false
  await fetchEntries()
}

const editEntry = (entry) => {
  editingId.value = entry.id
  Object.assign(form, {
    name: entry.name,
    amount: entry.amount,
    entry_type: entry.entry_type,
    recurrence: entry.recurrence,
    category: entry.category || '',
    month: entry.month || selectedMonth.value,
    year: entry.year || selectedYear.value,
    notes: entry.notes || '',
  })
  showForm.value = true
}

const cancelEdit = () => {
  editingId.value = null
  Object.assign(form, { ...defaultForm })
  showForm.value = false
}

const deleteEntry = async (id) => {
  await destroy(id)
  await fetchEntries()
}

onMounted(fetchEntries)
</script>
