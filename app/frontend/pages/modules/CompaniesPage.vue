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
                <input v-model="form.name" type="text" required placeholder="ex: Ma Societe SAS" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Forme juridique</label>
                <select v-model="form.legal_form" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option value="">-- Choisir --</option>
                  <option v-for="f in legalForms" :key="f.value" :value="f.value">{{ f.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Statut</label>
                <select v-model="form.status" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option v-for="s in statuses" :key="s.value" :value="s.value">{{ s.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Activite principale</label>
                <input v-model="form.activity" type="text" placeholder="ex: Conseil en informatique" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date de creation</label>
                <input v-model="form.creation_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nombre d'employes</label>
                <input v-model.number="form.employees_count" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Identification -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Identification</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">SIREN</label>
                <input v-model="form.siren" type="text" placeholder="123 456 789" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">SIRET</label>
                <input v-model="form.siret" type="text" placeholder="123 456 789 00012" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">N° TVA intracommunautaire</label>
                <input v-model="form.vat_number" type="text" placeholder="FR12345678901" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">RCS</label>
                <input v-model="form.rcs" type="text" placeholder="Paris B 123 456 789" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Financier -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Informations financieres</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Capital social</label>
                <input v-model.number="form.capital" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Chiffre d'affaires</label>
                <input v-model.number="form.revenue" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Adresse -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Adresse du siege</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div class="sm:col-span-2 lg:col-span-2">
                <label class="block text-xs text-gray-500 mb-1">Adresse</label>
                <input v-model="form.address_line1" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Complement</label>
                <input v-model="form.address_line2" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Code postal</label>
                <input v-model="form.postal_code" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Ville</label>
                <input v-model="form.city" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Pays</label>
                <input v-model="form.country" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Contact -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Contact</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Email</label>
                <input v-model="form.email" type="email" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Telephone</label>
                <input v-model="form.phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Site web</label>
                <input v-model="form.website" type="url" placeholder="https://..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Notes -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Notes</h3>
            <textarea v-model="form.notes" rows="3" placeholder="Notes supplementaires..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
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

      <!-- Fiches des entreprises -->
      <div v-for="company in companies" :key="company.id" class="bg-white rounded-xl shadow-sm mb-6 overflow-hidden">
        <div class="p-6">
          <!-- Header -->
          <div class="flex items-start justify-between mb-4">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <h2 class="text-xl font-bold text-gray-900">{{ company.name }}</h2>
                <span v-if="company.legal_form" class="text-xs px-2 py-0.5 rounded-full font-medium" :class="legalFormBadge(company.legal_form)">
                  {{ legalFormLabel(company.legal_form) }}
                </span>
                <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="statusBadge(company.status)">
                  {{ statusLabel(company.status) }}
                </span>
              </div>
              <p v-if="company.activity" class="text-sm text-gray-500">{{ company.activity }}</p>
              <p v-if="company.address_line1" class="text-sm text-gray-400 mt-1">
                {{ company.address_line1 }}{{ company.address_line2 ? ', ' + company.address_line2 : '' }}
                <br />{{ company.postal_code }} {{ company.city }}{{ company.country && company.country !== 'France' ? ', ' + company.country : '' }}
              </p>
            </div>
            <div class="flex gap-1 items-center">
              <button @click="openQuoteModal(company)" class="bg-indigo-100 text-indigo-700 hover:bg-indigo-200 px-3 py-1 rounded-lg text-xs font-medium transition-colors" title="Creer un devis">
                Devis
              </button>
              <button @click="openInvoiceModal(company)" class="bg-blue-100 text-blue-700 hover:bg-blue-200 px-3 py-1 rounded-lg text-xs font-medium transition-colors" title="Creer une facture">
                Facture
              </button>
              <button @click="editCompany(company)" class="text-gray-400 hover:text-indigo-600 p-1" title="Modifier">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
              </button>
              <button @click="deleteCompany(company.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
              </button>
            </div>
          </div>

          <!-- Identification -->
          <div v-if="hasIdentification(company)" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 mb-5">
            <div v-if="company.siren" class="bg-gray-50 rounded-lg p-3">
              <span class="text-xs text-gray-500 block">SIREN</span>
              <span class="text-sm font-semibold text-gray-900">{{ company.siren }}</span>
            </div>
            <div v-if="company.siret" class="bg-gray-50 rounded-lg p-3">
              <span class="text-xs text-gray-500 block">SIRET</span>
              <span class="text-sm font-semibold text-gray-900">{{ company.siret }}</span>
            </div>
            <div v-if="company.vat_number" class="bg-gray-50 rounded-lg p-3">
              <span class="text-xs text-gray-500 block">N° TVA</span>
              <span class="text-sm font-semibold text-gray-900">{{ company.vat_number }}</span>
            </div>
            <div v-if="company.rcs" class="bg-gray-50 rounded-lg p-3">
              <span class="text-xs text-gray-500 block">RCS</span>
              <span class="text-sm font-semibold text-gray-900">{{ company.rcs }}</span>
            </div>
            <div v-if="company.creation_date" class="bg-gray-50 rounded-lg p-3">
              <span class="text-xs text-gray-500 block">Date de creation</span>
              <span class="text-sm font-semibold text-gray-900">{{ formatDate(company.creation_date) }}</span>
            </div>
            <div v-if="company.employees_count !== null && company.employees_count !== undefined" class="bg-gray-50 rounded-lg p-3">
              <span class="text-xs text-gray-500 block">Employes</span>
              <span class="text-sm font-semibold text-gray-900">{{ company.employees_count }}</span>
            </div>
          </div>

          <!-- Finances -->
          <div v-if="hasFinancials(company)" class="mb-5">
            <h3 class="text-sm font-semibold text-gray-700 mb-2">Finances</h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
              <div v-if="company.capital" class="bg-blue-50 rounded-lg p-3">
                <span class="text-xs text-blue-600 block">Capital social</span>
                <span class="text-sm font-semibold text-blue-900">{{ formatCurrency(company.capital) }}</span>
              </div>
              <div v-if="company.revenue" class="bg-green-50 rounded-lg p-3">
                <span class="text-xs text-green-600 block">Chiffre d'affaires</span>
                <span class="text-sm font-semibold text-green-900">{{ formatCurrency(company.revenue) }}</span>
              </div>
            </div>
          </div>

          <!-- Contact -->
          <div v-if="hasContact(company)" class="mb-5">
            <h3 class="text-sm font-semibold text-gray-700 mb-2">Contact</h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
              <div v-if="company.email" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Email</span>
                <a :href="'mailto:' + company.email" class="text-sm font-semibold text-indigo-600 hover:text-indigo-800">{{ company.email }}</a>
              </div>
              <div v-if="company.phone" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Telephone</span>
                <a :href="'tel:' + company.phone" class="text-sm font-semibold text-gray-900">{{ company.phone }}</a>
              </div>
              <div v-if="company.website" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Site web</span>
                <a :href="company.website" target="_blank" rel="noopener" class="text-sm font-semibold text-indigo-600 hover:text-indigo-800 truncate block">{{ company.website }}</a>
              </div>
            </div>
          </div>

          <!-- Notes -->
          <div v-if="company.notes" class="mb-5">
            <h3 class="text-sm font-semibold text-gray-700 mb-2">Notes</h3>
            <p class="text-sm text-gray-600 whitespace-pre-line">{{ company.notes }}</p>
          </div>

          <!-- Devis -->
          <div v-if="companyQuotes(company.id).length > 0" class="mb-5">
            <h3 class="text-sm font-semibold text-gray-700 mb-2">Devis</h3>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="text-left text-xs text-gray-500 border-b">
                    <th class="pb-2 pr-4">Numero</th>
                    <th class="pb-2 pr-4">Client</th>
                    <th class="pb-2 pr-4">Objet</th>
                    <th class="pb-2 pr-4 text-right">Total TTC</th>
                    <th class="pb-2 pr-4">Date</th>
                    <th class="pb-2 pr-4">Statut</th>
                    <th class="pb-2"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="q in companyQuotes(company.id)" :key="q.id" class="border-b border-gray-100 last:border-0">
                    <td class="py-2 pr-4 font-medium text-gray-900">{{ q.number }}</td>
                    <td class="py-2 pr-4 text-gray-600">{{ q.client_name }}</td>
                    <td class="py-2 pr-4 text-gray-600">{{ q.subject || '-' }}</td>
                    <td class="py-2 pr-4 text-right font-semibold text-gray-900">{{ formatCurrency(q.total_ttc) }}</td>
                    <td class="py-2 pr-4 text-gray-500">{{ formatDate(q.issue_date) }}</td>
                    <td class="py-2 pr-4">
                      <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="quoteStatusBadge(q.status)">
                        {{ quoteStatusLabel(q.status) }}
                      </span>
                    </td>
                    <td class="py-2">
                      <div class="flex items-center gap-1">
                        <a :href="q.pdf_url" target="_blank" class="text-indigo-600 hover:text-indigo-800 p-1" title="Voir le PDF">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                        </a>
                        <template v-if="q.status === 'pending'">
                          <button @click="acceptQuote(company.id, q.id)" class="text-green-600 hover:text-green-800 p-1" title="Accepter">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
                          </button>
                          <button @click="refuseQuote(company.id, q.id)" class="text-red-500 hover:text-red-700 p-1" title="Refuser">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                          </button>
                        </template>
                        <button v-if="q.status === 'accepted'" @click="invoiceFromQuote(company.id, q.id)" class="bg-blue-100 text-blue-700 hover:bg-blue-200 px-2 py-0.5 rounded text-xs font-medium transition-colors" title="Generer une facture depuis ce devis">
                          Facturer
                        </button>
                        <button @click="duplicateQuote(company, q)" class="text-gray-400 hover:text-indigo-600 p-1" title="Dupliquer">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                        </button>
                        <button @click="deleteQuote(company.id, q.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Factures -->
          <div v-if="companyInvoices(company.id).length > 0" class="mb-5">
            <h3 class="text-sm font-semibold text-gray-700 mb-2">Factures</h3>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="text-left text-xs text-gray-500 border-b">
                    <th class="pb-2 pr-4">Numero</th>
                    <th class="pb-2 pr-4">Client</th>
                    <th class="pb-2 pr-4">Objet</th>
                    <th class="pb-2 pr-4 text-right">Total TTC</th>
                    <th class="pb-2 pr-4">Date</th>
                    <th class="pb-2 pr-4">Echeance</th>
                    <th class="pb-2 pr-4">Statut</th>
                    <th class="pb-2"></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="inv in companyInvoices(company.id)" :key="inv.id" class="border-b border-gray-100 last:border-0">
                    <td class="py-2 pr-4 font-medium text-gray-900">{{ inv.number }}</td>
                    <td class="py-2 pr-4 text-gray-600">{{ inv.client_name }}</td>
                    <td class="py-2 pr-4 text-gray-600">{{ inv.subject || '-' }}</td>
                    <td class="py-2 pr-4 text-right font-semibold text-gray-900">{{ formatCurrency(inv.total_ttc) }}</td>
                    <td class="py-2 pr-4 text-gray-500">{{ formatDate(inv.issue_date) }}</td>
                    <td class="py-2 pr-4 text-gray-500">{{ inv.due_date ? formatDate(inv.due_date) : '-' }}</td>
                    <td class="py-2 pr-4">
                      <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="invoiceStatusBadge(inv.status)">
                        {{ invoiceStatusLabel(inv.status) }}
                      </span>
                    </td>
                    <td class="py-2">
                      <div class="flex items-center gap-1">
                        <a :href="inv.pdf_url" target="_blank" class="text-indigo-600 hover:text-indigo-800 p-1" title="Voir le PDF">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                        </a>
                        <template v-if="inv.status === 'pending'">
                          <select @change="(e) => { markInvoicePaid(company.id, inv.id, e.target.value); e.target.value = '' }" class="bg-green-100 text-green-700 text-xs rounded px-1 py-0.5 font-medium border-0 cursor-pointer">
                            <option value="" selected>Payee...</option>
                            <option v-for="pm in paymentMethods" :key="pm.value" :value="pm.value">{{ pm.label }}</option>
                          </select>
                        </template>
                        <span v-else-if="inv.payment_method" class="text-xs text-gray-400">{{ paymentMethodLabel(inv.payment_method) }}</span>
                        <button @click="deleteInvoice(company.id, inv.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Documents associes -->
          <div>
            <div class="flex items-center justify-between mb-2">
              <h3 class="text-sm font-semibold text-gray-700">Documents</h3>
              <button
                @click="toggleDocForm(company.id)"
                class="text-indigo-600 hover:text-indigo-800 text-xs font-medium"
              >
                {{ activeDocForm === company.id ? 'Fermer' : '+ Ajouter un document' }}
              </button>
            </div>

            <!-- Formulaire d'upload document -->
            <div v-if="activeDocForm === company.id" class="bg-gray-50 rounded-lg p-4 mb-3">
              <form @submit.prevent="uploadDocument(company.id)" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label class="block text-xs text-gray-500 mb-1">Nom du document *</label>
                  <input v-model="docForm.name" type="text" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div>
                  <label class="block text-xs text-gray-500 mb-1">Categorie</label>
                  <select v-model="docForm.category" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                    <option value="">-- Choisir --</option>
                    <option v-for="c in docCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
                  </select>
                </div>
                <div>
                  <label class="block text-xs text-gray-500 mb-1">Date du document</label>
                  <input v-model="docForm.document_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div>
                  <label class="block text-xs text-gray-500 mb-1">Fichier *</label>
                  <input ref="docFileInput" type="file" required @change="onDocFileSelected" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white" />
                </div>
                <div class="sm:col-span-2">
                  <label class="block text-xs text-gray-500 mb-1">Notes</label>
                  <input v-model="docForm.notes" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div class="sm:col-span-2">
                  <button type="submit" :disabled="docUploading" class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50">
                    {{ docUploading ? 'Envoi en cours...' : 'Envoyer' }}
                  </button>
                </div>
              </form>
            </div>

            <!-- Liste des documents -->
            <div v-if="documents.length > 0" class="space-y-2">
              <div
                v-for="doc in documents"
                :key="doc.id"
                class="flex items-center justify-between bg-gray-50 rounded-lg p-3"
              >
                <div class="flex-1 min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="text-sm font-medium text-gray-900 truncate">{{ doc.name }}</span>
                    <span v-if="doc.category" class="text-xs bg-indigo-100 text-indigo-700 px-2 py-0.5 rounded-full">{{ docCategoryLabel(doc.category) }}</span>
                  </div>
                  <div class="flex items-center gap-3 mt-0.5">
                    <span v-if="doc.document_date" class="text-xs text-gray-500">{{ formatDate(doc.document_date) }}</span>
                    <span v-if="doc.file_name" class="text-xs text-gray-400">{{ doc.file_name }}</span>
                  </div>
                </div>
                <div class="flex items-center gap-2 ml-4">
                  <a v-if="doc.download_url" :href="doc.download_url" class="text-indigo-600 hover:text-indigo-800 p-1" title="Telecharger">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                  </a>
                  <button @click="deleteDocument(doc.id)" class="text-red-500 hover:text-red-700 p-1" title="Supprimer">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                  </button>
                </div>
              </div>
            </div>
            <p v-else class="text-xs text-gray-400">Aucun document associe.</p>
          </div>
        </div>
      </div>
    </div>

    <!-- Modale creation devis -->
    <div v-if="showQuoteModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="showQuoteModal = false">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-3xl max-h-[90vh] overflow-y-auto m-4 p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-lg font-bold text-gray-900">Nouveau devis — {{ quoteCompany?.name }}</h2>
          <button @click="showQuoteModal = false" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
        </div>

        <form @submit.prevent="saveQuote" class="space-y-6">
          <!-- Infos client -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Client</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nom du client *</label>
                <input v-model="quoteForm.client_name" type="text" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Email</label>
                <input v-model="quoteForm.client_email" type="email" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Telephone</label>
                <input v-model="quoteForm.client_phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">SIRET</label>
                <input v-model="quoteForm.client_siret" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">N° TVA</label>
                <input v-model="quoteForm.client_vat_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Adresse</label>
                <input v-model="quoteForm.client_address_line1" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Code postal</label>
                <input v-model="quoteForm.client_postal_code" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Ville</label>
                <input v-model="quoteForm.client_city" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Details du devis -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Details du devis</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Objet</label>
                <input v-model="quoteForm.subject" type="text" placeholder="ex: Prestation de conseil" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date d'emission</label>
                <input v-model="quoteForm.issue_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date de validite</label>
                <input v-model="quoteForm.validity_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Taux TVA (%)</label>
                <input v-model.number="quoteForm.tva_rate" type="number" step="0.01" min="0" :disabled="quoteForm.tva_exempt" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 disabled:bg-gray-100 disabled:text-gray-400" />
              </div>
              <div class="flex items-center gap-2 self-end pb-2">
                <input v-model="quoteForm.tva_exempt" type="checkbox" id="quote-tva-exempt" @change="onQuoteTvaExemptChange" class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500" />
                <label for="quote-tva-exempt" class="text-sm text-gray-700">Exonere de TVA</label>
              </div>
            </div>
            <p v-if="quoteForm.tva_exempt" class="text-xs text-amber-600 mt-2">TVA non applicable, art. 293 B du CGI</p>
          </section>

          <!-- Lignes du devis -->
          <section>
            <div class="flex items-center justify-between mb-3 border-b pb-2">
              <h3 class="text-sm font-semibold text-gray-700">Lignes du devis</h3>
              <button type="button" @click="addQuoteItem" class="text-indigo-600 hover:text-indigo-800 text-xs font-medium">
                + Ajouter une ligne
              </button>
            </div>
            <div v-for="(item, index) in quoteForm.items" :key="index" class="bg-gray-50 rounded-lg p-3 mb-2">
              <div class="grid grid-cols-12 gap-2 items-end">
                <div class="col-span-4">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Description *</label>
                  <input v-model="item.description" type="text" required placeholder="Prestation..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div class="col-span-1">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Qte *</label>
                  <input v-model.number="item.quantity" type="number" step="0.01" min="0.01" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div class="col-span-2">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Unite</label>
                  <select v-model="item.unit" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                    <option v-for="u in unitTypes" :key="u.value" :value="u.value">{{ u.label }}</option>
                  </select>
                </div>
                <div class="col-span-2">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Prix unit. HT *</label>
                  <input v-model.number="item.unit_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
                </div>
                <div class="col-span-2 text-right text-sm font-semibold text-gray-700 py-2">
                  {{ formatCurrency(computeLineTotal(item)) }}
                </div>
                <div class="col-span-1">
                  <button v-if="quoteForm.items.length > 1" type="button" @click="removeQuoteItem(index)" class="text-red-500 hover:text-red-700 p-2">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </div>
              </div>
              <div class="grid grid-cols-12 gap-2 mt-1 items-center">
                <div class="col-span-4"></div>
                <div class="col-span-2">
                  <select v-model="item.discount_type" class="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-indigo-500 bg-white text-gray-500">
                    <option value="none">Pas de remise</option>
                    <option value="percent">Remise %</option>
                    <option value="amount">Remise fixe</option>
                  </select>
                </div>
                <div class="col-span-2">
                  <input v-if="item.discount_type && item.discount_type !== 'none'" v-model.number="item.discount_value" type="number" step="0.01" min="0" :placeholder="item.discount_type === 'percent' ? '%' : 'EUR'" class="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-indigo-500" />
                </div>
                <div class="col-span-4"></div>
              </div>
            </div>
          </section>

          <!-- Totaux -->
          <section class="bg-gray-50 rounded-lg p-4">
            <div class="flex justify-end">
              <div class="w-64 space-y-1">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Total HT</span>
                  <span class="font-semibold text-gray-900">{{ formatCurrency(quoteComputedTotalHT) }}</span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">{{ quoteForm.tva_exempt ? 'TVA (exoneree)' : 'TVA (' + quoteForm.tva_rate + '%)' }}</span>
                  <span class="font-semibold text-gray-900">{{ formatCurrency(quoteComputedTVA) }}</span>
                </div>
                <div class="flex justify-between text-sm font-bold border-t pt-1">
                  <span class="text-gray-900">Total TTC</span>
                  <span class="text-gray-900">{{ formatCurrency(quoteComputedTotalTTC) }}</span>
                </div>
              </div>
            </div>
          </section>

          <!-- Notes et conditions -->
          <section>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Conditions de paiement</label>
                <textarea v-model="quoteForm.conditions" rows="2" placeholder="ex: Paiement a 30 jours..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Notes</label>
                <textarea v-model="quoteForm.notes" rows="2" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"></textarea>
              </div>
            </div>
          </section>

          <div class="flex gap-2 justify-end">
            <button type="button" @click="showQuoteModal = false" class="bg-gray-200 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">
              Annuler
            </button>
            <button type="submit" :disabled="quoteSaving" class="bg-green-600 text-white px-6 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50">
              {{ quoteSaving ? 'Generation...' : 'Generer le devis' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Modale creation facture -->
    <div v-if="showInvoiceModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" @click.self="showInvoiceModal = false">
      <div class="bg-white rounded-xl shadow-xl w-full max-w-3xl max-h-[90vh] overflow-y-auto m-4 p-6">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-lg font-bold text-gray-900">Nouvelle facture — {{ invoiceCompany?.name }}</h2>
          <button @click="showInvoiceModal = false" class="text-gray-400 hover:text-gray-600">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
          </button>
        </div>

        <form @submit.prevent="saveInvoice" class="space-y-6">
          <!-- Infos client -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Client</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nom du client *</label>
                <input v-model="invoiceForm.client_name" type="text" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Email</label>
                <input v-model="invoiceForm.client_email" type="email" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Telephone</label>
                <input v-model="invoiceForm.client_phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">SIRET</label>
                <input v-model="invoiceForm.client_siret" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">N° TVA</label>
                <input v-model="invoiceForm.client_vat_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Adresse</label>
                <input v-model="invoiceForm.client_address_line1" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Code postal</label>
                <input v-model="invoiceForm.client_postal_code" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Ville</label>
                <input v-model="invoiceForm.client_city" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
            </div>
          </section>

          <!-- Details facture -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Details de la facture</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Objet</label>
                <input v-model="invoiceForm.subject" type="text" placeholder="ex: Prestation de conseil" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date d'emission</label>
                <input v-model="invoiceForm.issue_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date d'echeance</label>
                <input v-model="invoiceForm.due_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Taux TVA (%)</label>
                <input v-model.number="invoiceForm.tva_rate" type="number" step="0.01" min="0" :disabled="invoiceForm.tva_exempt" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100 disabled:text-gray-400" />
              </div>
              <div class="flex items-center gap-2 self-end pb-2">
                <input v-model="invoiceForm.tva_exempt" type="checkbox" id="invoice-tva-exempt" @change="onInvoiceTvaExemptChange" class="w-4 h-4 text-blue-600 border-gray-300 rounded focus:ring-blue-500" />
                <label for="invoice-tva-exempt" class="text-sm text-gray-700">Exonere de TVA</label>
              </div>
            </div>
            <p v-if="invoiceForm.tva_exempt" class="text-xs text-amber-600 mt-2">TVA non applicable, art. 293 B du CGI</p>
          </section>

          <!-- Lignes -->
          <section>
            <div class="flex items-center justify-between mb-3 border-b pb-2">
              <h3 class="text-sm font-semibold text-gray-700">Lignes de la facture</h3>
              <button type="button" @click="addInvoiceItem" class="text-blue-600 hover:text-blue-800 text-xs font-medium">
                + Ajouter une ligne
              </button>
            </div>
            <div v-for="(item, index) in invoiceForm.items" :key="index" class="bg-gray-50 rounded-lg p-3 mb-2">
              <div class="grid grid-cols-12 gap-2 items-end">
                <div class="col-span-4">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Description *</label>
                  <input v-model="item.description" type="text" required placeholder="Prestation..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
                <div class="col-span-1">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Qte *</label>
                  <input v-model.number="item.quantity" type="number" step="0.01" min="0.01" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
                <div class="col-span-2">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Unite</label>
                  <select v-model="item.unit" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 bg-white">
                    <option v-for="u in unitTypes" :key="u.value" :value="u.value">{{ u.label }}</option>
                  </select>
                </div>
                <div class="col-span-2">
                  <label v-if="index === 0" class="block text-xs text-gray-500 mb-1">Prix unit. HT *</label>
                  <input v-model.number="item.unit_price" type="number" step="0.01" min="0" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" />
                </div>
                <div class="col-span-2 text-right text-sm font-semibold text-gray-700 py-2">
                  {{ formatCurrency(computeLineTotal(item)) }}
                </div>
                <div class="col-span-1">
                  <button v-if="invoiceForm.items.length > 1" type="button" @click="removeInvoiceItem(index)" class="text-red-500 hover:text-red-700 p-2">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                </div>
              </div>
              <div class="grid grid-cols-12 gap-2 mt-1 items-center">
                <div class="col-span-4"></div>
                <div class="col-span-2">
                  <select v-model="item.discount_type" class="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-blue-500 bg-white text-gray-500">
                    <option value="none">Pas de remise</option>
                    <option value="percent">Remise %</option>
                    <option value="amount">Remise fixe</option>
                  </select>
                </div>
                <div class="col-span-2">
                  <input v-if="item.discount_type && item.discount_type !== 'none'" v-model.number="item.discount_value" type="number" step="0.01" min="0" :placeholder="item.discount_type === 'percent' ? '%' : 'EUR'" class="w-full px-2 py-1 border border-gray-200 rounded text-xs focus:outline-none focus:ring-1 focus:ring-blue-500" />
                </div>
                <div class="col-span-4"></div>
              </div>
            </div>
          </section>

          <!-- Totaux -->
          <section class="bg-gray-50 rounded-lg p-4">
            <div class="flex justify-end">
              <div class="w-64 space-y-1">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Total HT</span>
                  <span class="font-semibold text-gray-900">{{ formatCurrency(invoiceComputedTotalHT) }}</span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">{{ invoiceForm.tva_exempt ? 'TVA (exoneree)' : 'TVA (' + invoiceForm.tva_rate + '%)' }}</span>
                  <span class="font-semibold text-gray-900">{{ formatCurrency(invoiceComputedTVA) }}</span>
                </div>
                <div class="flex justify-between text-sm font-bold border-t pt-1">
                  <span class="text-gray-900">Total TTC</span>
                  <span class="text-gray-900">{{ formatCurrency(invoiceComputedTotalTTC) }}</span>
                </div>
              </div>
            </div>
          </section>

          <!-- Notes et conditions -->
          <section>
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Conditions de paiement</label>
                <textarea v-model="invoiceForm.conditions" rows="2" placeholder="ex: Paiement a 30 jours..." class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"></textarea>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Notes</label>
                <textarea v-model="invoiceForm.notes" rows="2" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"></textarea>
              </div>
            </div>
          </section>

          <div class="flex gap-2 justify-end">
            <button type="button" @click="showInvoiceModal = false" class="bg-gray-200 text-gray-700 px-6 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium">
              Annuler
            </button>
            <button type="submit" :disabled="invoiceSaving" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium disabled:opacity-50">
              {{ invoiceSaving ? 'Generation...' : 'Generer la facture' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import apiClient from '../../plugins/axios'

const { useCrud, get, delete: del } = useApi()
const { list, destroy } = useCrud('companies')

const companies = ref([])
const showForm = ref(false)
const editingId = ref(null)
const documents = ref([])
const activeDocForm = ref(null)
const docUploading = ref(false)
const docFileInput = ref(null)
const selectedDocFile = ref(null)

// Quotes
const quotes = ref({})
const showQuoteModal = ref(false)
const quoteCompany = ref(null)
const quoteSaving = ref(false)

// Invoices
const invoices = ref({})
const showInvoiceModal = ref(false)
const invoiceCompany = ref(null)
const invoiceSaving = ref(false)

const legalForms = [
  { value: 'sas', label: 'SAS' },
  { value: 'sarl', label: 'SARL' },
  { value: 'eurl', label: 'EURL' },
  { value: 'sasu', label: 'SASU' },
  { value: 'sa', label: 'SA' },
  { value: 'sci', label: 'SCI' },
  { value: 'auto_entrepreneur', label: 'Auto-entrepreneur' },
  { value: 'association', label: 'Association' },
  { value: 'autre', label: 'Autre' },
]

const statuses = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'en_creation', label: 'En cours de creation' },
  { value: 'radiee', label: 'Radiee' },
]

const docCategories = [
  { value: 'invoice', label: 'Facture' },
  { value: 'quote', label: 'Devis' },
  { value: 'contract', label: 'Contrat' },
  { value: 'kbis', label: 'Kbis' },
  { value: 'statutes', label: 'Statuts' },
  { value: 'other', label: 'Autre' },
]

const defaultForm = {
  name: '', legal_form: '', status: 'active', activity: '',
  creation_date: '', employees_count: null,
  siren: '', siret: '', vat_number: '', rcs: '',
  capital: null, revenue: null,
  address_line1: '', address_line2: '', postal_code: '', city: '', country: 'France',
  email: '', phone: '', website: '', notes: '',
}

const form = reactive({ ...defaultForm })

const docForm = reactive({ name: '', category: '', document_date: '', notes: '' })

const unitTypes = [
  { value: 'unite', label: 'Unite' },
  { value: 'heure', label: 'Heure' },
  { value: 'jour', label: 'Jour' },
  { value: 'mois', label: 'Mois' },
  { value: 'forfait', label: 'Forfait' },
  { value: 'kg', label: 'kg' },
  { value: 'm2', label: 'm²' },
]

const defaultQuoteItem = () => ({ description: '', quantity: 1, unit: 'unite', unit_price: null, discount_type: 'none', discount_value: null })

const quoteForm = reactive({
  client_name: '', client_email: '', client_phone: '',
  client_siret: '', client_vat_number: '',
  client_address_line1: '', client_postal_code: '', client_city: '',
  subject: '', issue_date: '', validity_date: '',
  tva_rate: 20, tva_exempt: false, notes: '', conditions: '',
  items: [defaultQuoteItem()],
})

const computeLineTotal = (item) => {
  let subtotal = (item.quantity || 0) * (item.unit_price || 0)
  if (item.discount_type === 'percent' && item.discount_value) {
    subtotal *= (1 - item.discount_value / 100)
  } else if (item.discount_type === 'amount' && item.discount_value) {
    subtotal = Math.max(0, subtotal - item.discount_value)
  }
  return Math.round(subtotal * 100) / 100
}

const quoteComputedTotalHT = computed(() => {
  return quoteForm.items.reduce((sum, item) => sum + computeLineTotal(item), 0)
})

const quoteComputedTVA = computed(() => {
  return Math.round(quoteComputedTotalHT.value * (quoteForm.tva_rate || 0) / 100 * 100) / 100
})

const quoteComputedTotalTTC = computed(() => {
  return quoteComputedTotalHT.value + quoteComputedTVA.value
})

const defaultInvoiceItem = () => ({ description: '', quantity: 1, unit: 'unite', unit_price: null, discount_type: 'none', discount_value: null })

const paymentMethods = [
  { value: 'virement', label: 'Virement' },
  { value: 'cheque', label: 'Cheque' },
  { value: 'cb', label: 'Carte bancaire' },
  { value: 'especes', label: 'Especes' },
  { value: 'prelevement', label: 'Prelevement' },
  { value: 'autre', label: 'Autre' },
]

const invoiceForm = reactive({
  client_name: '', client_email: '', client_phone: '',
  client_siret: '', client_vat_number: '',
  client_address_line1: '', client_postal_code: '', client_city: '',
  subject: '', issue_date: '', due_date: '',
  tva_rate: 20, tva_exempt: false, notes: '', conditions: '',
  items: [defaultInvoiceItem()],
})

const invoiceComputedTotalHT = computed(() => {
  return invoiceForm.items.reduce((sum, item) => sum + computeLineTotal(item), 0)
})

const invoiceComputedTVA = computed(() => {
  return Math.round(invoiceComputedTotalHT.value * (invoiceForm.tva_rate || 0) / 100 * 100) / 100
})

const invoiceComputedTotalTTC = computed(() => {
  return invoiceComputedTotalHT.value + invoiceComputedTVA.value
})

const fetchCompanies = async () => {
  companies.value = await list()
}

const fetchDocuments = async () => {
  const data = await get('/documents', { params: { domain: 'companies' } })
  if (data) documents.value = data
}

const fetchQuotes = async (companyId) => {
  try {
    const data = await get(`/companies/${companyId}/quotes`)
    if (data) quotes.value[companyId] = data
  } catch (e) {
    console.error('Erreur chargement devis:', e)
  }
}

const fetchAllQuotes = async () => {
  for (const company of companies.value) {
    await fetchQuotes(company.id)
  }
}

const companyQuotes = (companyId) => {
  return quotes.value[companyId] || []
}

const fetchInvoices = async (companyId) => {
  try {
    const data = await get(`/companies/${companyId}/invoices`)
    if (data) invoices.value[companyId] = data
  } catch (e) {
    console.error('Erreur chargement factures:', e)
  }
}

const fetchAllInvoices = async () => {
  for (const company of companies.value) {
    await fetchInvoices(company.id)
  }
}

const companyInvoices = (companyId) => {
  return invoices.value[companyId] || []
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

// Quotes
const openQuoteModal = (company) => {
  quoteCompany.value = company
  const today = new Date().toISOString().split('T')[0]
  const validity = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  const isAutoEntrepreneur = company.legal_form === 'auto_entrepreneur'
  Object.assign(quoteForm, {
    client_name: '', client_email: '', client_phone: '',
    client_siret: '', client_vat_number: '',
    client_address_line1: '', client_postal_code: '', client_city: '',
    subject: '', issue_date: today, validity_date: validity,
    tva_rate: isAutoEntrepreneur ? 0 : 20,
    tva_exempt: isAutoEntrepreneur,
    notes: '', conditions: '',
    items: [defaultQuoteItem()],
  })
  showQuoteModal.value = true
}

const onQuoteTvaExemptChange = () => {
  if (quoteForm.tva_exempt) {
    quoteForm.tva_rate = 0
  } else {
    quoteForm.tva_rate = 20
  }
}

const addQuoteItem = () => {
  quoteForm.items.push(defaultQuoteItem())
}

const removeQuoteItem = (index) => {
  quoteForm.items.splice(index, 1)
}

const saveQuote = async () => {
  if (!quoteCompany.value) return
  quoteSaving.value = true
  try {
    const payload = {
      client_name: quoteForm.client_name,
      client_email: quoteForm.client_email,
      client_phone: quoteForm.client_phone,
      client_siret: quoteForm.client_siret,
      client_vat_number: quoteForm.client_vat_number,
      client_address_line1: quoteForm.client_address_line1,
      client_postal_code: quoteForm.client_postal_code,
      client_city: quoteForm.client_city,
      subject: quoteForm.subject,
      issue_date: quoteForm.issue_date,
      validity_date: quoteForm.validity_date,
      tva_rate: quoteForm.tva_rate,
      notes: quoteForm.notes,
      conditions: quoteForm.conditions,
      quote_items_attributes: quoteForm.items.map((item, i) => ({
        description: item.description,
        quantity: item.quantity,
        unit: item.unit,
        unit_price: item.unit_price,
        discount_type: item.discount_type || 'none',
        discount_value: item.discount_value || 0,
        position: i,
      })),
    }
    await apiClient.post(`/companies/${quoteCompany.value.id}/quotes`, payload)
    showQuoteModal.value = false
    await fetchQuotes(quoteCompany.value.id)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur creation devis:', e)
  } finally {
    quoteSaving.value = false
  }
}

const acceptQuote = async (companyId, quoteId) => {
  try {
    await apiClient.patch(`/companies/${companyId}/quotes/${quoteId}/accept`)
    await fetchQuotes(companyId)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur acceptation devis:', e)
  }
}

const refuseQuote = async (companyId, quoteId) => {
  try {
    await apiClient.patch(`/companies/${companyId}/quotes/${quoteId}/refuse`)
    await fetchQuotes(companyId)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur refus devis:', e)
  }
}

const deleteQuote = async (companyId, quoteId) => {
  if (!confirm('Supprimer ce devis ?')) return
  try {
    await apiClient.delete(`/companies/${companyId}/quotes/${quoteId}`)
    await fetchQuotes(companyId)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur suppression devis:', e)
  }
}

const duplicateQuote = (company, quote) => {
  quoteCompany.value = company
  const today = new Date().toISOString().split('T')[0]
  const validity = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  const isAutoEntrepreneur = company.legal_form === 'auto_entrepreneur'
  Object.assign(quoteForm, {
    client_name: quote.client_name || '',
    client_email: quote.client_email || '',
    client_phone: quote.client_phone || '',
    client_siret: quote.client_siret || '',
    client_vat_number: quote.client_vat_number || '',
    client_address_line1: quote.client_address_line1 || '',
    client_postal_code: quote.client_postal_code || '',
    client_city: quote.client_city || '',
    subject: quote.subject || '',
    issue_date: today,
    validity_date: validity,
    tva_rate: quote.tva_rate ?? (isAutoEntrepreneur ? 0 : 20),
    tva_exempt: quote.tva_rate === 0 || quote.tva_rate === '0',
    notes: quote.notes || '',
    conditions: quote.conditions || '',
    items: (quote.items || []).map(item => ({
      description: item.description,
      quantity: item.quantity,
      unit: item.unit,
      unit_price: item.unit_price,
      discount_type: item.discount_type || 'none',
      discount_value: item.discount_value || null,
    })),
  })
  if (quoteForm.items.length === 0) quoteForm.items = [defaultQuoteItem()]
  showQuoteModal.value = true
}

const quoteStatusLabel = (status) => {
  const labels = { pending: 'En attente', accepted: 'Accepte', refused: 'Refuse' }
  return labels[status] || status
}

const quoteStatusBadge = (status) => {
  const colors = {
    pending: 'bg-yellow-100 text-yellow-700',
    accepted: 'bg-green-100 text-green-700',
    refused: 'bg-red-100 text-red-700',
  }
  return colors[status] || 'bg-gray-100 text-gray-500'
}

// Invoices
const openInvoiceModal = (company) => {
  invoiceCompany.value = company
  const today = new Date().toISOString().split('T')[0]
  const dueDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0]
  const isAutoEntrepreneur = company.legal_form === 'auto_entrepreneur'
  Object.assign(invoiceForm, {
    client_name: '', client_email: '', client_phone: '',
    client_siret: '', client_vat_number: '',
    client_address_line1: '', client_postal_code: '', client_city: '',
    subject: '', issue_date: today, due_date: dueDate,
    tva_rate: isAutoEntrepreneur ? 0 : 20,
    tva_exempt: isAutoEntrepreneur,
    notes: '', conditions: '',
    items: [defaultInvoiceItem()],
  })
  showInvoiceModal.value = true
}

const onInvoiceTvaExemptChange = () => {
  if (invoiceForm.tva_exempt) {
    invoiceForm.tva_rate = 0
  } else {
    invoiceForm.tva_rate = 20
  }
}

const addInvoiceItem = () => {
  invoiceForm.items.push(defaultInvoiceItem())
}

const removeInvoiceItem = (index) => {
  invoiceForm.items.splice(index, 1)
}

const saveInvoice = async () => {
  if (!invoiceCompany.value) return
  invoiceSaving.value = true
  try {
    const payload = {
      client_name: invoiceForm.client_name,
      client_email: invoiceForm.client_email,
      client_phone: invoiceForm.client_phone,
      client_siret: invoiceForm.client_siret,
      client_vat_number: invoiceForm.client_vat_number,
      client_address_line1: invoiceForm.client_address_line1,
      client_postal_code: invoiceForm.client_postal_code,
      client_city: invoiceForm.client_city,
      subject: invoiceForm.subject,
      issue_date: invoiceForm.issue_date,
      due_date: invoiceForm.due_date,
      tva_rate: invoiceForm.tva_rate,
      notes: invoiceForm.notes,
      conditions: invoiceForm.conditions,
      invoice_items_attributes: invoiceForm.items.map((item, i) => ({
        description: item.description,
        quantity: item.quantity,
        unit: item.unit,
        unit_price: item.unit_price,
        discount_type: item.discount_type || 'none',
        discount_value: item.discount_value || 0,
        position: i,
      })),
    }
    await apiClient.post(`/companies/${invoiceCompany.value.id}/invoices`, payload)
    showInvoiceModal.value = false
    await fetchInvoices(invoiceCompany.value.id)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur creation facture:', e)
  } finally {
    invoiceSaving.value = false
  }
}

const invoiceFromQuote = async (companyId, quoteId) => {
  try {
    await apiClient.post(`/companies/${companyId}/invoices/from_quote/${quoteId}`)
    await fetchInvoices(companyId)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur creation facture depuis devis:', e)
  }
}

const markInvoicePaid = async (companyId, invoiceId, paymentMethod) => {
  try {
    await apiClient.patch(`/companies/${companyId}/invoices/${invoiceId}/mark_paid`, { payment_method: paymentMethod })
    await fetchInvoices(companyId)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur marquage facture payee:', e)
  }
}

const deleteInvoice = async (companyId, invoiceId) => {
  if (!confirm('Supprimer cette facture ?')) return
  try {
    await apiClient.delete(`/companies/${companyId}/invoices/${invoiceId}`)
    await fetchInvoices(companyId)
    await fetchDocuments()
  } catch (e) {
    console.error('Erreur suppression facture:', e)
  }
}

const invoiceStatusLabel = (status) => {
  const labels = { pending: 'En attente', paid: 'Payee' }
  return labels[status] || status
}

const invoiceStatusBadge = (status) => {
  const colors = {
    pending: 'bg-orange-100 text-orange-700',
    paid: 'bg-green-100 text-green-700',
  }
  return colors[status] || 'bg-gray-100 text-gray-500'
}

const paymentMethodLabel = (val) => {
  const found = paymentMethods.find(p => p.value === val)
  return found ? found.label : val
}

// Documents
const toggleDocForm = (companyId) => {
  if (activeDocForm.value === companyId) {
    activeDocForm.value = null
  } else {
    activeDocForm.value = companyId
    Object.assign(docForm, { name: '', category: '', document_date: '', notes: '' })
    selectedDocFile.value = null
  }
}

const onDocFileSelected = (event) => {
  selectedDocFile.value = event.target.files[0]
}

const uploadDocument = async () => {
  if (!selectedDocFile.value) return
  docUploading.value = true
  const formData = new FormData()
  formData.append('domain', 'companies')
  formData.append('name', docForm.name)
  formData.append('file', selectedDocFile.value)
  if (docForm.category) formData.append('category', docForm.category)
  if (docForm.document_date) formData.append('document_date', docForm.document_date)
  if (docForm.notes) formData.append('notes', docForm.notes)
  try {
    const response = await apiClient.post('/documents', formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    documents.value.unshift(response.data)
    activeDocForm.value = null
    Object.assign(docForm, { name: '', category: '', document_date: '', notes: '' })
    selectedDocFile.value = null
    if (docFileInput.value) docFileInput.value.value = ''
  } catch (e) {
    console.error('Erreur upload document:', e)
  } finally {
    docUploading.value = false
  }
}

const deleteDocument = async (id) => {
  if (!confirm('Supprimer ce document ?')) return
  await del(`/documents/${id}`)
  documents.value = documents.value.filter(d => d.id !== id)
}

const docCategoryLabel = (val) => {
  const found = docCategories.find(c => c.value === val)
  return found ? found.label : val
}

// Formatters
const formatDate = (val) => {
  if (!val) return null
  return new Date(val).toLocaleDateString('fr-FR')
}

const formatCurrency = (val) => {
  if (val === null || val === undefined) return null
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(val)
}

const legalFormLabel = (val) => {
  const found = legalForms.find(f => f.value === val)
  return found ? found.label : val
}

const legalFormBadge = (val) => {
  const colors = {
    sas: 'bg-blue-100 text-blue-700',
    sarl: 'bg-purple-100 text-purple-700',
    eurl: 'bg-cyan-100 text-cyan-700',
    sasu: 'bg-indigo-100 text-indigo-700',
    sa: 'bg-violet-100 text-violet-700',
    sci: 'bg-amber-100 text-amber-700',
    auto_entrepreneur: 'bg-yellow-100 text-yellow-700',
    association: 'bg-teal-100 text-teal-700',
    autre: 'bg-gray-100 text-gray-500',
  }
  return colors[val] || 'bg-gray-100 text-gray-500'
}

const statusLabel = (val) => {
  const found = statuses.find(s => s.value === val)
  return found ? found.label : val
}

const statusBadge = (val) => {
  const colors = {
    active: 'bg-green-100 text-green-700',
    inactive: 'bg-gray-100 text-gray-600',
    en_creation: 'bg-orange-100 text-orange-700',
    radiee: 'bg-red-100 text-red-700',
  }
  return colors[val] || 'bg-gray-100 text-gray-500'
}

const hasIdentification = (c) => {
  return c.siren || c.siret || c.vat_number || c.rcs || c.creation_date || (c.employees_count !== null && c.employees_count !== undefined)
}

const hasFinancials = (c) => {
  return c.capital || c.revenue
}

const hasContact = (c) => {
  return c.email || c.phone || c.website
}

onMounted(async () => {
  await fetchCompanies()
  await fetchDocuments()
  await fetchAllQuotes()
  await fetchAllInvoices()
})
</script>
