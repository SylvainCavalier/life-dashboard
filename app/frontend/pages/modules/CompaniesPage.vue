<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour au dashboard
      </router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <span class="text-3xl">🏢</span>
          <h1 class="text-2xl font-bold text-gray-900">Entreprises</h1>
          <span class="text-sm text-gray-400">({{ companies.length }} entreprise{{ companies.length > 1 ? 's' : '' }})</span>
        </div>
        <button
          @click="toggleForm()"
          class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
        >
          {{ showForm ? 'Annuler' : '+ Ajouter une entreprise' }}
        </button>
      </div>

      <!-- Formulaire d'ajout / edition -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-8 mb-6">
        <h2 class="text-lg font-bold text-gray-900 mb-4">{{ editingId ? 'Modifier l\'entreprise' : 'Nouvelle entreprise' }}</h2>
        <form @submit.prevent="saveCompany" class="space-y-6">
          <!-- Infos principales -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Informations principales</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nom de l'entreprise *</label>
                <input v-model="form.name" type="text" required placeholder="ex: Ma Societe SAS" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Forme juridique</label>
                <select v-model="form.legal_form" class="input-field bg-white">
                  <option value="">-- Choisir --</option>
                  <option v-for="f in legalForms" :key="f.value" :value="f.value">{{ f.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Statut</label>
                <select v-model="form.status" class="input-field bg-white">
                  <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Activite principale</label>
                <input v-model="form.activity" type="text" placeholder="ex: Conseil en informatique" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date de creation</label>
                <input v-model="form.creation_date" type="date" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nombre d'employes</label>
                <input v-model.number="form.employees_count" type="number" min="0" class="input-field" />
              </div>
            </div>
          </section>

          <!-- Identification -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Identification</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">SIREN</label>
                <input v-model="form.siren" type="text" placeholder="123 456 789" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">SIRET</label>
                <input v-model="form.siret" type="text" placeholder="123 456 789 00012" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">N° TVA intracommunautaire</label>
                <input v-model="form.vat_number" type="text" placeholder="FR12345678901" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">RCS</label>
                <input v-model="form.rcs" type="text" placeholder="Paris B 123 456 789" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Code APE / NAF</label>
                <input v-model="form.ape_code" type="text" placeholder="ex: 6201Z" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">IDCC (convention collective)</label>
                <input v-model="form.idcc" type="text" placeholder="ex: 1486" class="input-field" />
              </div>
            </div>
          </section>

          <!-- Financier -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Informations financieres</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Capital social</label>
                <input v-model.number="form.capital" type="number" step="0.01" min="0" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Chiffre d'affaires</label>
                <input v-model.number="form.revenue" type="number" step="0.01" min="0" class="input-field" />
              </div>
            </div>
          </section>

          <!-- Adresse -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Adresse du siege</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div class="sm:col-span-2 lg:col-span-2">
                <label class="block text-xs text-gray-500 mb-1">Adresse</label>
                <input v-model="form.address_line1" type="text" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Complement</label>
                <input v-model="form.address_line2" type="text" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Code postal</label>
                <input v-model="form.postal_code" type="text" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Ville</label>
                <input v-model="form.city" type="text" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Pays</label>
                <input v-model="form.country" type="text" class="input-field" />
              </div>
            </div>
          </section>

          <!-- Contact -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Contact</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Email</label>
                <input v-model="form.email" type="email" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Telephone</label>
                <input v-model="form.phone" type="tel" class="input-field" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Site web</label>
                <input v-model="form.website" type="url" placeholder="https://..." class="input-field" />
              </div>
            </div>
          </section>

          <!-- Notes -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Notes</h3>
            <textarea v-model="form.notes" rows="3" placeholder="Notes supplementaires..." class="input-field"></textarea>
          </section>

          <div class="flex gap-2">
            <button type="submit" class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium">
              {{ editingId ? 'Modifier' : 'Enregistrer' }}
            </button>
            <button type="button" @click="toggleForm()" class="bg-gray-200 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">
              Annuler
            </button>
          </div>
        </form>
      </div>

      <!-- Liste vide -->
      <div v-if="companies.length === 0 && !showForm" class="bg-white rounded-xl shadow-sm p-12 text-center">
        <div class="text-5xl mb-4">🏢</div>
        <p class="text-gray-500 mb-4">Aucune entreprise enregistree.</p>
        <button @click="toggleForm()" class="bg-indigo-600 text-white px-6 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium">
          + Ajouter une entreprise
        </button>
      </div>

      <!-- Cards des entreprises -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div
          v-for="company in companies"
          :key="company.id"
          @click="goToCompany(company.id)"
          class="bg-white rounded-xl shadow-sm p-6 cursor-pointer hover:shadow-md transition-shadow"
        >
          <!-- Header -->
          <div class="flex items-start justify-between mb-3">
            <div class="min-w-0">
              <div class="flex items-center gap-2 mb-1 flex-wrap">
                <h2 class="text-lg font-bold text-gray-900">{{ company.name }}</h2>
                <span v-if="company.legal_form" class="text-xs px-2 py-0.5 rounded-full font-medium" :class="legalFormBadge(company.legal_form)">
                  {{ legalFormLabel(company.legal_form) }}
                </span>
                <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="statusBadge(company.status)">
                  {{ statusLabel(company.status) }}
                </span>
              </div>
              <p v-if="company.activity" class="text-sm text-gray-500">{{ company.activity }}</p>
            </div>
            <div class="flex gap-1 items-center shrink-0">
              <button @click.stop="editCompany(company)" class="text-gray-400 hover:text-indigo-600 p-1" title="Modifier">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
              </button>
              <button @click.stop="deleteCompany(company.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
              </button>
            </div>
          </div>

          <!-- Identification compacte -->
          <div class="flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-500 mb-4">
            <span v-if="company.siret">SIRET : <span class="text-gray-700 font-medium">{{ company.siret }}</span></span>
            <span v-else-if="company.siren">SIREN : <span class="text-gray-700 font-medium">{{ company.siren }}</span></span>
            <span v-if="company.vat_number">TVA : <span class="text-gray-700 font-medium">{{ company.vat_number }}</span></span>
            <span v-if="company.city">{{ company.postal_code }} {{ company.city }}</span>
          </div>

          <!-- Apercu budget -->
          <div v-if="company.budget" class="grid grid-cols-3 gap-2 pt-3 border-t border-gray-100">
            <div>
              <span class="text-xs text-gray-400 block">Encaisse</span>
              <span class="text-sm font-bold text-green-700">{{ formatCurrency(company.budget.revenue_collected) }}</span>
            </div>
            <div>
              <span class="text-xs text-gray-400 block">En attente</span>
              <span class="text-sm font-bold text-orange-600">{{ formatCurrency(company.budget.revenue_pending) }}</span>
            </div>
            <div>
              <span class="text-xs text-gray-400 block">Devis / Factures</span>
              <span class="text-sm font-bold text-gray-700">{{ company.budget.quotes_count }} / {{ company.budget.invoices_count }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useApi } from '../../composables/useApi'
import { useFormat, legalForms, statuses } from '../../composables/useFormat'

const router = useRouter()
const { useCrud } = useApi()
const { list, destroy } = useCrud('companies')
const { formatCurrency, legalFormLabel, legalFormBadge, statusLabel, statusBadge } = useFormat()

const companies = ref([])
const showForm = ref(false)
const editingId = ref(null)

const defaultForm = {
  name: '', legal_form: '', status: 'active', activity: '',
  creation_date: '', employees_count: null,
  siren: '', siret: '', vat_number: '', rcs: '', ape_code: '', idcc: '',
  capital: null, revenue: null,
  address_line1: '', address_line2: '', postal_code: '', city: '', country: 'France',
  email: '', phone: '', website: '', notes: '',
}

const form = reactive({ ...defaultForm })

const fetchCompanies = async () => {
  companies.value = await list()
}

const goToCompany = (id) => {
  router.push({ name: 'CompanyShow', params: { id } })
}

const toggleForm = () => {
  if (showForm.value) {
    showForm.value = false
    editingId.value = null
    Object.assign(form, defaultForm)
    return
  }
  Object.assign(form, { ...defaultForm })
  editingId.value = null
  showForm.value = true
}

const editCompany = (company) => {
  Object.keys(defaultForm).forEach((key) => {
    form[key] = company[key] !== null && company[key] !== undefined ? company[key] : defaultForm[key]
  })
  editingId.value = company.id
  showForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

const saveCompany = async () => {
  const payload = {}
  Object.keys(defaultForm).forEach((key) => {
    const val = form[key]
    if (val !== null && val !== undefined && val !== '') {
      payload[key] = val
    }
  })

  try {
    const { create, update } = useCrud('companies')
    if (editingId.value) {
      await update(editingId.value, payload)
    } else {
      await create(payload)
    }
    showForm.value = false
    editingId.value = null
    Object.assign(form, defaultForm)
    await fetchCompanies()
  } catch (e) {
    console.error('Erreur sauvegarde:', e)
  }
}

const deleteCompany = async (id) => {
  if (!confirm('Supprimer cette entreprise ?')) return
  await destroy(id)
  await fetchCompanies()
}

onMounted(fetchCompanies)
</script>

<style scoped>
.input-field {
  @apply w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500;
}
</style>
