<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
      <!-- Retour -->
      <router-link to="/companies" class="inline-flex items-center text-sm text-gray-500 hover:text-gray-700 mb-6">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
        </svg>
        Retour aux entreprises
      </router-link>

      <div v-if="company">
        <!-- En-tete entreprise -->
        <div class="bg-white rounded-xl shadow-sm p-6 mb-6">
          <div class="flex items-start justify-between mb-4">
            <div>
              <div class="flex items-center gap-2 mb-1">
                <h1 class="text-2xl font-bold text-gray-900">{{ company.trade_name }}</h1>
                <span v-if="company.legal_form" class="text-xs px-2 py-0.5 rounded-full font-medium" :class="legalFormBadge(company.legal_form)">
                  {{ legalFormLabel(company.legal_form) }}
                </span>
                <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="statusBadge(company.status)">
                  {{ statusLabel(company.status) }}
                </span>
              </div>
              <p v-if="company.legal_representative_name" class="text-sm text-gray-500">Representant legal : {{ company.legal_representative_name }}</p>
              <p v-if="company.activity" class="text-sm text-gray-500">{{ company.activity }}</p>
              <p v-if="company.address_line1" class="text-sm text-gray-400 mt-1">
                {{ company.address_line1 }}{{ company.address_line2 ? ', ' + company.address_line2 : '' }},
                {{ company.postal_code }} {{ company.city }}{{ company.country && company.country !== 'France' ? ', ' + company.country : '' }}
              </p>
            </div>
          </div>

          <!-- Identification -->
          <div v-if="hasIdentification" class="mb-5">
            <h3 class="text-sm font-semibold text-gray-700 mb-2">Identification</h3>
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
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
              <div v-if="company.ape_code" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Code APE / NAF</span>
                <span class="text-sm font-semibold text-gray-900">{{ company.ape_code }}</span>
              </div>
              <div v-if="company.idcc" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">IDCC</span>
                <span class="text-sm font-semibold text-gray-900">{{ company.idcc }}</span>
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
          </div>

          <!-- Finances -->
          <div v-if="company.capital || company.revenue" class="mb-5">
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
          <div v-if="company.email || company.phone || company.website" class="mb-5">
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

          <!-- Apercu budget -->
          <div v-if="company.budget" class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div class="bg-green-50 rounded-lg p-3">
              <span class="text-xs text-green-600 block">CA encaisse</span>
              <span class="text-lg font-bold text-green-900">{{ formatCurrency(company.budget.revenue_collected) }}</span>
            </div>
            <div class="bg-orange-50 rounded-lg p-3">
              <span class="text-xs text-orange-600 block">En attente de paiement</span>
              <span class="text-lg font-bold text-orange-900">{{ formatCurrency(company.budget.revenue_pending) }}</span>
            </div>
            <div class="bg-indigo-50 rounded-lg p-3">
              <span class="text-xs text-indigo-600 block">Devis acceptes non factures</span>
              <span class="text-lg font-bold text-indigo-900">{{ formatCurrency(company.budget.accepted_not_invoiced) }}</span>
            </div>
          </div>
        </div>

        <!-- Onglets -->
        <div class="bg-white rounded-xl shadow-sm overflow-hidden">
          <div class="flex border-b overflow-x-auto">
            <button
              v-for="tab in tabs"
              :key="tab.key"
              @click="selectTab(tab.key)"
              class="px-5 py-3 text-sm font-medium whitespace-nowrap transition-colors"
              :class="activeTab === tab.key ? 'text-indigo-600 border-b-2 border-indigo-600' : 'text-gray-500 hover:text-gray-700'"
            >
              {{ tab.label }}
            </button>
          </div>

          <div class="p-6">
            <!-- BUDGET -->
            <div v-show="activeTab === 'budget'">
              <div v-if="company.budget" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <div class="bg-green-50 rounded-lg p-4">
                  <span class="text-xs text-green-600 block mb-1">CA encaisse (factures payees)</span>
                  <span class="text-2xl font-bold text-green-900">{{ formatCurrency(company.budget.revenue_collected) }}</span>
                </div>
                <div class="bg-orange-50 rounded-lg p-4">
                  <span class="text-xs text-orange-600 block mb-1">En attente de paiement</span>
                  <span class="text-2xl font-bold text-orange-900">{{ formatCurrency(company.budget.revenue_pending) }}</span>
                </div>
                <div class="bg-indigo-50 rounded-lg p-4">
                  <span class="text-xs text-indigo-600 block mb-1">Devis acceptes non factures</span>
                  <span class="text-2xl font-bold text-indigo-900">{{ formatCurrency(company.budget.accepted_not_invoiced) }}</span>
                </div>
                <div class="bg-gray-50 rounded-lg p-4">
                  <span class="text-xs text-gray-500 block mb-1">Nombre de devis</span>
                  <span class="text-2xl font-bold text-gray-900">{{ company.budget.quotes_count }}</span>
                </div>
                <div class="bg-gray-50 rounded-lg p-4">
                  <span class="text-xs text-gray-500 block mb-1">Nombre de factures</span>
                  <span class="text-2xl font-bold text-gray-900">{{ company.budget.invoices_count }}</span>
                </div>
              </div>
            </div>

            <!-- DEVIS -->
            <div v-show="activeTab === 'quotes'">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-sm font-semibold text-gray-700">Devis</h3>
                <button @click="openQuoteModal()" class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium">+ Nouveau devis</button>
              </div>
              <div v-if="quotes.length" class="overflow-x-auto">
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
                    <tr v-for="q in quotes" :key="q.id" class="border-b border-gray-100 last:border-0">
                      <td class="py-2 pr-4 font-medium text-gray-900">{{ q.number }}</td>
                      <td class="py-2 pr-4 text-gray-600">{{ q.client_name }}</td>
                      <td class="py-2 pr-4 text-gray-600">{{ q.subject || '-' }}</td>
                      <td class="py-2 pr-4 text-right font-semibold text-gray-900">{{ formatCurrency(q.total_ttc) }}</td>
                      <td class="py-2 pr-4 text-gray-500">{{ formatDate(q.issue_date) }}</td>
                      <td class="py-2 pr-4">
                        <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="quoteStatusBadge(q.status)">{{ quoteStatusLabel(q.status) }}</span>
                      </td>
                      <td class="py-2">
                        <div class="flex items-center gap-1">
                          <a :href="q.pdf_url" target="_blank" class="text-indigo-600 hover:text-indigo-800 p-1" title="Voir le PDF">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                          </a>
                          <template v-if="q.status === 'pending'">
                            <button @click="acceptQuote(q.id)" class="text-green-600 hover:text-green-800 p-1" title="Accepter">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>
                            </button>
                            <button @click="refuseQuote(q.id)" class="text-red-500 hover:text-red-700 p-1" title="Refuser">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
                            </button>
                          </template>
                          <button v-if="q.status === 'accepted'" @click="invoiceFromQuote(q.id)" class="bg-blue-100 text-blue-700 hover:bg-blue-200 px-2 py-0.5 rounded text-xs font-medium transition-colors" title="Generer une facture">Facturer</button>
                          <button @click="duplicateQuote(q)" class="text-gray-400 hover:text-indigo-600 p-1" title="Dupliquer">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
                          </button>
                          <button @click="deleteQuote(q.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p v-else class="text-sm text-gray-400">Aucun devis.</p>
            </div>

            <!-- FACTURES -->
            <div v-show="activeTab === 'invoices'">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-sm font-semibold text-gray-700">Factures</h3>
                <button @click="openInvoiceModal()" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium">+ Nouvelle facture</button>
              </div>
              <div v-if="invoices.length" class="overflow-x-auto">
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
                    <tr v-for="inv in invoices" :key="inv.id" class="border-b border-gray-100 last:border-0">
                      <td class="py-2 pr-4 font-medium text-gray-900">{{ inv.number }}</td>
                      <td class="py-2 pr-4 text-gray-600">{{ inv.client_name }}</td>
                      <td class="py-2 pr-4 text-gray-600">{{ inv.subject || '-' }}</td>
                      <td class="py-2 pr-4 text-right font-semibold text-gray-900">{{ formatCurrency(inv.total_ttc) }}</td>
                      <td class="py-2 pr-4 text-gray-500">{{ formatDate(inv.issue_date) }}</td>
                      <td class="py-2 pr-4 text-gray-500">{{ inv.due_date ? formatDate(inv.due_date) : '-' }}</td>
                      <td class="py-2 pr-4">
                        <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="invoiceStatusBadge(inv.status)">{{ invoiceStatusLabel(inv.status) }}</span>
                      </td>
                      <td class="py-2">
                        <div class="flex items-center gap-1">
                          <a :href="inv.pdf_url" target="_blank" class="text-indigo-600 hover:text-indigo-800 p-1" title="Voir le PDF">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                          </a>
                          <template v-if="inv.status === 'pending'">
                            <select @change="(e) => { markInvoicePaid(inv.id, e.target.value); e.target.value = '' }" class="bg-green-100 text-green-700 text-xs rounded px-1 py-0.5 font-medium border-0 cursor-pointer">
                              <option value="" selected>Payee...</option>
                              <option v-for="pm in paymentMethods" :key="pm.value" :value="pm.value">{{ pm.label }}</option>
                            </select>
                          </template>
                          <span v-else-if="inv.payment_method" class="text-xs text-gray-400">{{ paymentMethodLabel(inv.payment_method) }}</span>
                          <button @click="deleteInvoice(inv.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
              <p v-else class="text-sm text-gray-400">Aucune facture.</p>
            </div>

            <!-- CLIENTS -->
            <div v-show="activeTab === 'clients'">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-sm font-semibold text-gray-700">Clients enregistres</h3>
                <button @click="openClientModal()" class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium">+ Nouveau client</button>
              </div>
              <div v-if="clients.length" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
                <div v-for="c in clients" :key="c.id" class="border border-gray-200 rounded-lg p-4">
                  <div class="flex items-start justify-between">
                    <span class="text-sm font-semibold text-gray-900">{{ c.name }}</span>
                    <div class="flex gap-1">
                      <button @click="openClientModal(c)" class="text-gray-400 hover:text-indigo-600 p-1" title="Modifier">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                      </button>
                      <button @click="deleteClient(c.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                      </button>
                    </div>
                  </div>
                  <div class="mt-1 space-y-0.5 text-xs text-gray-500">
                    <p v-if="c.email">{{ c.email }}</p>
                    <p v-if="c.phone">{{ c.phone }}</p>
                    <p v-if="c.city">{{ c.postal_code }} {{ c.city }}</p>
                    <p v-if="c.siret">SIRET : {{ c.siret }}</p>
                  </div>
                </div>
              </div>
              <p v-else class="text-sm text-gray-400">Aucun client enregistre.</p>
            </div>

            <!-- DOCUMENTS -->
            <div v-show="activeTab === 'documents'">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-sm font-semibold text-gray-700">Documents</h3>
                <button @click="showDocForm = !showDocForm" class="text-indigo-600 hover:text-indigo-800 text-sm font-medium">
                  {{ showDocForm ? 'Fermer' : '+ Ajouter un document' }}
                </button>
              </div>

              <div v-if="showDocForm" class="bg-gray-50 rounded-lg p-4 mb-4">
                <form @submit.prevent="uploadDocument" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Nom du document *</label>
                    <input v-model="docForm.name" type="text" required class="input-field" />
                  </div>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Categorie</label>
                    <select v-model="docForm.category" class="input-field bg-white">
                      <option value="">-- Choisir --</option>
                      <option v-for="c in docCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
                    </select>
                  </div>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Date du document</label>
                    <input v-model="docForm.document_date" type="date" class="input-field" />
                  </div>
                  <div>
                    <label class="block text-xs text-gray-500 mb-1">Fichier *</label>
                    <input ref="docFileInput" type="file" required @change="onDocFileSelected" class="input-field bg-white" />
                  </div>
                  <div class="sm:col-span-2">
                    <label class="block text-xs text-gray-500 mb-1">Notes</label>
                    <input v-model="docForm.notes" type="text" class="input-field" />
                  </div>
                  <div class="sm:col-span-2">
                    <button type="submit" :disabled="docUploading" class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium disabled:opacity-50">
                      {{ docUploading ? 'Envoi en cours...' : 'Envoyer' }}
                    </button>
                  </div>
                </form>
              </div>

              <div v-if="documents.length" class="space-y-2">
                <div v-for="doc in documents" :key="doc.id" class="flex items-center justify-between bg-gray-50 rounded-lg p-3">
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
              <p v-else class="text-sm text-gray-400">Aucun document associe.</p>
            </div>
          </div>
        </div>
      </div>

      <div v-else class="bg-white rounded-xl shadow-sm p-12 text-center text-gray-400">Chargement...</div>
    </div>

    <!-- Modales -->
    <QuoteFormModal v-if="showQuoteModal" :company="company" :clients="clients" :initial-data="quoteInitial" @close="showQuoteModal = false" @saved="onQuoteSaved" />
    <InvoiceFormModal v-if="showInvoiceModal" :company="company" :clients="clients" @close="showInvoiceModal = false" @saved="onInvoiceSaved" />
    <ClientFormModal v-if="showClientModal" :company="company" :client="editingClient" @close="showClientModal = false" @saved="onClientSaved" />
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { useApi } from '../../composables/useApi'
import apiClient from '../../plugins/axios'
import { useFormat, docCategories, paymentMethods } from '../../composables/useFormat'
import QuoteFormModal from '../../components/companies/QuoteFormModal.vue'
import InvoiceFormModal from '../../components/companies/InvoiceFormModal.vue'
import ClientFormModal from '../../components/companies/ClientFormModal.vue'

const route = useRoute()
const companyId = route.params.id

const { get, delete: del } = useApi()
const {
  formatDate, formatCurrency, legalFormLabel, legalFormBadge, statusLabel, statusBadge,
  quoteStatusLabel, quoteStatusBadge, invoiceStatusLabel, invoiceStatusBadge,
  paymentMethodLabel, docCategoryLabel,
} = useFormat()

const company = ref(null)

const hasIdentification = computed(() => {
  const c = company.value
  if (!c) return false
  return c.siren || c.siret || c.vat_number || c.rcs || c.ape_code || c.idcc ||
    c.creation_date || (c.employees_count !== null && c.employees_count !== undefined)
})

const quotes = ref([])
const invoices = ref([])
const clients = ref([])
const documents = ref([])

const tabs = [
  { key: 'budget', label: 'Budget' },
  { key: 'quotes', label: 'Devis' },
  { key: 'invoices', label: 'Factures' },
  { key: 'clients', label: 'Clients' },
  { key: 'documents', label: 'Documents' },
]
const activeTab = ref('budget')
const loaded = reactive({ quotes: false, invoices: false, clients: false, documents: false })

// Modales
const showQuoteModal = ref(false)
const showInvoiceModal = ref(false)
const showClientModal = ref(false)
const quoteInitial = ref(null)
const editingClient = ref(null)

// Documents
const showDocForm = ref(false)
const docUploading = ref(false)
const docFileInput = ref(null)
const selectedDocFile = ref(null)
const docForm = reactive({ name: '', category: '', document_date: '', notes: '' })

const fetchCompany = async () => {
  company.value = await get(`/companies/${companyId}`)
}

const refreshBudget = async () => {
  const budget = await get(`/companies/${companyId}/budget`)
  if (company.value) company.value.budget = budget
}

const fetchQuotes = async () => {
  quotes.value = await get(`/companies/${companyId}/quotes`) || []
  loaded.quotes = true
}
const fetchInvoices = async () => {
  invoices.value = await get(`/companies/${companyId}/invoices`) || []
  loaded.invoices = true
}
const fetchClients = async () => {
  clients.value = await get(`/companies/${companyId}/clients`) || []
  loaded.clients = true
}
const fetchDocuments = async () => {
  documents.value = await get('/documents', { params: { domain: 'companies', company_id: companyId } }) || []
  loaded.documents = true
}

const selectTab = (key) => {
  activeTab.value = key
  if (key === 'quotes' && !loaded.quotes) fetchQuotes()
  if (key === 'invoices' && !loaded.invoices) fetchInvoices()
  if (key === 'clients' && !loaded.clients) fetchClients()
  if (key === 'documents' && !loaded.documents) fetchDocuments()
  // Les clients servent au pre-remplissage des devis/factures : on les charge en amont.
  if ((key === 'quotes' || key === 'invoices') && !loaded.clients) fetchClients()
}

// Devis
const openQuoteModal = (initial = null) => {
  quoteInitial.value = initial
  showQuoteModal.value = true
}
const duplicateQuote = (q) => openQuoteModal(q)
const onQuoteSaved = async () => {
  showQuoteModal.value = false
  await fetchQuotes()
  await refreshBudget()
}
const acceptQuote = async (id) => {
  await apiClient.patch(`/companies/${companyId}/quotes/${id}/accept`)
  await fetchQuotes()
  await refreshBudget()
}
const refuseQuote = async (id) => {
  await apiClient.patch(`/companies/${companyId}/quotes/${id}/refuse`)
  await fetchQuotes()
  await refreshBudget()
}
const deleteQuote = async (id) => {
  if (!confirm('Supprimer ce devis ?')) return
  await apiClient.delete(`/companies/${companyId}/quotes/${id}`)
  await fetchQuotes()
  await refreshBudget()
}
const invoiceFromQuote = async (quoteId) => {
  await apiClient.post(`/companies/${companyId}/invoices/from_quote/${quoteId}`)
  loaded.invoices = false
  await fetchInvoices()
  await refreshBudget()
}

// Factures
const openInvoiceModal = () => { showInvoiceModal.value = true }
const onInvoiceSaved = async () => {
  showInvoiceModal.value = false
  await fetchInvoices()
  await refreshBudget()
}
const markInvoicePaid = async (id, paymentMethod) => {
  await apiClient.patch(`/companies/${companyId}/invoices/${id}/mark_paid`, { payment_method: paymentMethod })
  await fetchInvoices()
  await refreshBudget()
}
const deleteInvoice = async (id) => {
  if (!confirm('Supprimer cette facture ?')) return
  await apiClient.delete(`/companies/${companyId}/invoices/${id}`)
  await fetchInvoices()
  await refreshBudget()
}

// Clients
const openClientModal = (client = null) => {
  editingClient.value = client
  showClientModal.value = true
}
const onClientSaved = async () => {
  showClientModal.value = false
  await fetchClients()
}
const deleteClient = async (id) => {
  if (!confirm('Supprimer ce client ?')) return
  await apiClient.delete(`/companies/${companyId}/clients/${id}`)
  await fetchClients()
}

// Documents
const onDocFileSelected = (event) => { selectedDocFile.value = event.target.files[0] }
const uploadDocument = async () => {
  if (!selectedDocFile.value) return
  docUploading.value = true
  const formData = new FormData()
  formData.append('domain', 'companies')
  formData.append('company_id', companyId)
  formData.append('name', docForm.name)
  formData.append('file', selectedDocFile.value)
  if (docForm.category) formData.append('category', docForm.category)
  if (docForm.document_date) formData.append('document_date', docForm.document_date)
  if (docForm.notes) formData.append('notes', docForm.notes)
  try {
    const response = await apiClient.post('/documents', formData, { headers: { 'Content-Type': 'multipart/form-data' } })
    documents.value.unshift(response.data)
    showDocForm.value = false
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

onMounted(fetchCompany)
</script>

<style scoped>
.input-field {
  @apply w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500;
}
</style>
