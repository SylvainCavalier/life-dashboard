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
          <span class="text-3xl">🏠</span>
          <h1 class="text-2xl font-bold text-gray-900">Immobilier</h1>
          <span class="text-sm text-gray-400">({{ properties.length }} bien{{ properties.length > 1 ? 's' : '' }})</span>
        </div>
        <button
          @click="toggleForm()"
          class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
        >
          {{ showForm ? 'Annuler' : '+ Ajouter un nouveau bien' }}
        </button>
      </div>

      <!-- Formulaire d'ajout / edition -->
      <div v-if="showForm" class="bg-white rounded-xl shadow-sm p-8 mb-6">
        <h2 class="text-lg font-bold text-gray-900 mb-4">{{ editingId ? 'Modifier le bien' : 'Nouveau bien immobilier' }}</h2>
        <form @submit.prevent="saveProperty" class="space-y-6">
          <!-- Infos principales -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Informations principales</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nom du bien *</label>
                <input v-model="form.name" type="text" required placeholder="ex: Appartement Paris 11" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Type de bien *</label>
                <select v-model="form.property_type" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option value="" disabled>-- Choisir --</option>
                  <option v-for="t in propertyTypes" :key="t.value" :value="t.value">{{ t.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Surface (m²)</label>
                <input v-model.number="form.surface" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Nombre de pieces</label>
                <input v-model.number="form.rooms" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Chambres</label>
                <input v-model.number="form.bedrooms" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Salles de bain</label>
                <input v-model.number="form.bathrooms" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Etages</label>
                <input v-model.number="form.floors" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Annee de construction</label>
                <input v-model.number="form.construction_year" type="number" min="1800" max="2030" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Adresse -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Adresse</h3>
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

          <!-- Financier -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Informations financieres</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div>
                <label class="block text-xs text-gray-500 mb-1">Date d'achat</label>
                <input v-model="form.purchase_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Prix d'achat</label>
                <input v-model.number="form.purchase_price" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Valeur actuelle estimee</label>
                <input v-model.number="form.current_value" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Credit restant</label>
                <input v-model.number="form.loan_remaining" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Mensualite</label>
                <input v-model.number="form.monthly_payment" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Mois restants</label>
                <input v-model.number="form.months_remaining" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Charges mensuelles</label>
                <input v-model.number="form.monthly_charges" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-xs text-gray-500 mb-1">Taxe fonciere (annuelle)</label>
                <input v-model.number="form.property_tax" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Location -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Location</h3>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
              <div class="flex items-center gap-2">
                <input v-model="form.rented" type="checkbox" id="rented" class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500" />
                <label for="rented" class="text-sm text-gray-700">Bien en location</label>
              </div>
              <div v-if="form.rented">
                <label class="block text-xs text-gray-500 mb-1">Nom du locataire</label>
                <input v-model="form.tenant_name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div v-if="form.rented">
                <label class="block text-xs text-gray-500 mb-1">Loyer mensuel percu</label>
                <input v-model.number="form.rental_income" type="number" step="0.01" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Photos -->
          <section>
            <h3 class="text-sm font-semibold text-gray-700 mb-3 border-b pb-2">Photos</h3>
            <input ref="photoInput" type="file" multiple accept="image/*" @change="onPhotosSelected" class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white" />
            <div v-if="photoPreview.length > 0" class="flex flex-wrap gap-3 mt-3">
              <div v-for="(src, i) in photoPreview" :key="i" class="relative w-24 h-24 rounded-lg overflow-hidden border border-gray-200">
                <img :src="src" class="w-full h-full object-cover" />
                <button @click="removePreviewPhoto(i)" type="button" class="absolute top-1 right-1 bg-red-500 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs hover:bg-red-600">&times;</button>
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
      <div v-if="properties.length === 0 && !showForm" class="bg-white rounded-xl shadow-sm p-12 text-center">
        <div class="text-5xl mb-4">🏠</div>
        <p class="text-gray-500 mb-4">Aucun bien immobilier enregistre.</p>
        <button @click="toggleForm()" class="bg-indigo-600 text-white px-6 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium">
          + Ajouter un nouveau bien
        </button>
      </div>

      <!-- Fiches des biens -->
      <div v-for="property in properties" :key="property.id" class="bg-white rounded-xl shadow-sm mb-6 overflow-hidden">
        <div class="flex flex-col lg:flex-row">
          <!-- Carousel photos (gauche) -->
          <div class="lg:w-96 flex-shrink-0 bg-gray-100 relative">
            <div v-if="property.photos && property.photos.length > 0" class="relative h-64 lg:h-full min-h-[16rem]">
              <img
                :src="property.photos[carouselIndex[property.id] || 0]?.url"
                :alt="property.name"
                class="w-full h-full object-cover"
              />
              <!-- Navigation carousel -->
              <template v-if="property.photos.length > 1">
                <button
                  @click="prevPhoto(property.id, property.photos.length)"
                  class="absolute left-2 top-1/2 -translate-y-1/2 bg-black/50 text-white rounded-full w-8 h-8 flex items-center justify-center hover:bg-black/70 transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg>
                </button>
                <button
                  @click="nextPhoto(property.id, property.photos.length)"
                  class="absolute right-2 top-1/2 -translate-y-1/2 bg-black/50 text-white rounded-full w-8 h-8 flex items-center justify-center hover:bg-black/70 transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" /></svg>
                </button>
                <!-- Dots -->
                <div class="absolute bottom-3 left-1/2 -translate-x-1/2 flex gap-1.5">
                  <button
                    v-for="(_, i) in property.photos"
                    :key="i"
                    @click="carouselIndex[property.id] = i"
                    :class="(carouselIndex[property.id] || 0) === i ? 'bg-white' : 'bg-white/50'"
                    class="w-2 h-2 rounded-full transition-colors"
                  ></button>
                </div>
              </template>
              <!-- Compteur photos -->
              <span class="absolute top-3 right-3 bg-black/50 text-white text-xs px-2 py-1 rounded-full">
                {{ (carouselIndex[property.id] || 0) + 1 }} / {{ property.photos.length }}
              </span>
            </div>
            <div v-else class="h-64 lg:h-full min-h-[16rem] flex flex-col items-center justify-center text-gray-300">
              <svg class="w-16 h-16 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
              <span class="text-sm">Aucune photo</span>
            </div>
            <!-- Bouton ajouter photos -->
            <div class="absolute bottom-3 left-3">
              <label :for="'photo-upload-' + property.id" class="bg-white/90 text-gray-700 text-xs px-3 py-1.5 rounded-full cursor-pointer hover:bg-white transition-colors shadow-sm font-medium">
                + Photos
              </label>
              <input :id="'photo-upload-' + property.id" type="file" multiple accept="image/*" class="hidden" @change="(e) => uploadPhotos(property.id, e)" />
            </div>
          </div>

          <!-- Infos (droite) -->
          <div class="flex-1 p-6">
            <!-- Header du bien -->
            <div class="flex items-start justify-between mb-4">
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <h2 class="text-xl font-bold text-gray-900">{{ property.name }}</h2>
                  <span class="text-xs px-2 py-0.5 rounded-full font-medium" :class="typeBadge(property.property_type)">
                    {{ typeLabel(property.property_type) }}
                  </span>
                  <span v-if="property.rented" class="text-xs bg-green-100 text-green-700 px-2 py-0.5 rounded-full font-medium">
                    En location
                  </span>
                </div>
                <p v-if="property.address_line1" class="text-sm text-gray-500">
                  {{ property.address_line1 }}{{ property.address_line2 ? ', ' + property.address_line2 : '' }}
                  <br />{{ property.postal_code }} {{ property.city }}{{ property.country && property.country !== 'France' ? ', ' + property.country : '' }}
                </p>
              </div>
              <div class="flex gap-1">
                <button @click="editProperty(property)" class="text-gray-400 hover:text-indigo-600 p-1" title="Modifier">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
                </button>
                <button @click="deleteProperty(property.id)" class="text-gray-400 hover:text-red-600 p-1" title="Supprimer">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" /></svg>
                </button>
              </div>
            </div>

            <!-- Caracteristiques -->
            <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3 mb-5">
              <div v-if="property.surface" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Surface</span>
                <span class="text-sm font-semibold text-gray-900">{{ property.surface }} m²</span>
              </div>
              <div v-if="property.rooms" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Pieces</span>
                <span class="text-sm font-semibold text-gray-900">{{ property.rooms }}</span>
              </div>
              <div v-if="property.bedrooms" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Chambres</span>
                <span class="text-sm font-semibold text-gray-900">{{ property.bedrooms }}</span>
              </div>
              <div v-if="property.bathrooms" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Salles de bain</span>
                <span class="text-sm font-semibold text-gray-900">{{ property.bathrooms }}</span>
              </div>
              <div v-if="property.floors" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Etages</span>
                <span class="text-sm font-semibold text-gray-900">{{ property.floors }}</span>
              </div>
              <div v-if="property.construction_year" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Construction</span>
                <span class="text-sm font-semibold text-gray-900">{{ property.construction_year }}</span>
              </div>
              <div v-if="property.purchase_date" class="bg-gray-50 rounded-lg p-3">
                <span class="text-xs text-gray-500 block">Date d'achat</span>
                <span class="text-sm font-semibold text-gray-900">{{ formatDate(property.purchase_date) }}</span>
              </div>
            </div>

            <!-- Finances -->
            <div v-if="hasFinancials(property)" class="mb-5">
              <h3 class="text-sm font-semibold text-gray-700 mb-2">Finances</h3>
              <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
                <div v-if="property.purchase_price" class="bg-blue-50 rounded-lg p-3">
                  <span class="text-xs text-blue-600 block">Prix d'achat</span>
                  <span class="text-sm font-semibold text-blue-900">{{ formatCurrency(property.purchase_price) }}</span>
                </div>
                <div v-if="property.current_value" class="bg-green-50 rounded-lg p-3">
                  <span class="text-xs text-green-600 block">Valeur actuelle</span>
                  <span class="text-sm font-semibold text-green-900">{{ formatCurrency(property.current_value) }}</span>
                </div>
                <div v-if="property.loan_remaining" class="bg-orange-50 rounded-lg p-3">
                  <span class="text-xs text-orange-600 block">Credit restant</span>
                  <span class="text-sm font-semibold text-orange-900">{{ formatCurrency(property.loan_remaining) }}</span>
                </div>
                <div v-if="property.monthly_payment" class="bg-orange-50 rounded-lg p-3">
                  <span class="text-xs text-orange-600 block">Mensualite</span>
                  <span class="text-sm font-semibold text-orange-900">{{ formatCurrency(property.monthly_payment) }}/mois</span>
                </div>
                <div v-if="property.months_remaining" class="bg-orange-50 rounded-lg p-3">
                  <span class="text-xs text-orange-600 block">Mois restants</span>
                  <span class="text-sm font-semibold text-orange-900">{{ property.months_remaining }} mois</span>
                </div>
                <div v-if="property.monthly_charges" class="bg-gray-50 rounded-lg p-3">
                  <span class="text-xs text-gray-500 block">Charges mensuelles</span>
                  <span class="text-sm font-semibold text-gray-900">{{ formatCurrency(property.monthly_charges) }}/mois</span>
                </div>
                <div v-if="property.property_tax" class="bg-gray-50 rounded-lg p-3">
                  <span class="text-xs text-gray-500 block">Taxe fonciere</span>
                  <span class="text-sm font-semibold text-gray-900">{{ formatCurrency(property.property_tax) }}/an</span>
                </div>
                <div v-if="property.rented && property.rental_income" class="bg-green-50 rounded-lg p-3">
                  <span class="text-xs text-green-600 block">Loyer percu</span>
                  <span class="text-sm font-semibold text-green-900">{{ formatCurrency(property.rental_income) }}/mois</span>
                </div>
              </div>
            </div>

            <!-- Locataire -->
            <div v-if="property.rented && property.tenant_name" class="mb-5">
              <h3 class="text-sm font-semibold text-gray-700 mb-2">Locataire</h3>
              <p class="text-sm text-gray-900">{{ property.tenant_name }}</p>
            </div>

            <!-- Notes -->
            <div v-if="property.notes" class="mb-5">
              <h3 class="text-sm font-semibold text-gray-700 mb-2">Notes</h3>
              <p class="text-sm text-gray-600 whitespace-pre-line">{{ property.notes }}</p>
            </div>

            <!-- Documents associes -->
            <div>
              <div class="flex items-center justify-between mb-2">
                <h3 class="text-sm font-semibold text-gray-700">Documents</h3>
                <button
                  @click="toggleDocForm(property.id)"
                  class="text-indigo-600 hover:text-indigo-800 text-xs font-medium"
                >
                  {{ activeDocForm === property.id ? 'Fermer' : '+ Ajouter un document' }}
                </button>
              </div>

              <!-- Formulaire d'upload document -->
              <div v-if="activeDocForm === property.id" class="bg-gray-50 rounded-lg p-4 mb-3">
                <form @submit.prevent="uploadDocument(property.id)" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
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
              <div v-if="propertyDocuments(property.id).length > 0" class="space-y-2">
                <div
                  v-for="doc in propertyDocuments(property.id)"
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
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import apiClient from '../../plugins/axios'

const { useCrud, get, delete: del } = useApi()
const { list, create, update, destroy } = useCrud('properties')

const properties = ref([])
const showForm = ref(false)
const editingId = ref(null)
const carouselIndex = reactive({})
const documents = ref([])
const activeDocForm = ref(null)
const docUploading = ref(false)
const docFileInput = ref(null)
const selectedDocFile = ref(null)
const photoInput = ref(null)
const selectedPhotos = ref([])
const photoPreview = ref([])

const propertyTypes = [
  { value: 'appartement', label: 'Appartement' },
  { value: 'maison', label: 'Maison' },
  { value: 'studio', label: 'Studio' },
  { value: 'terrain', label: 'Terrain' },
  { value: 'commercial', label: 'Local commercial' },
  { value: 'parking', label: 'Parking' },
  { value: 'cave', label: 'Cave' },
  { value: 'autre', label: 'Autre' },
]

const docCategories = [
  { value: 'lease', label: 'Bail' },
  { value: 'deed', label: 'Acte de vente' },
  { value: 'diagnostic', label: 'Diagnostic' },
  { value: 'insurance', label: 'Assurance' },
  { value: 'invoice', label: 'Facture' },
  { value: 'tax_notice', label: 'Avis d\'imposition' },
  { value: 'other', label: 'Autre' },
]

const defaultForm = {
  name: '', property_type: '',
  address_line1: '', address_line2: '', postal_code: '', city: '', country: 'France',
  surface: null, rooms: null, bedrooms: null, bathrooms: null, floors: null, construction_year: null,
  purchase_date: '', purchase_price: null, current_value: null,
  loan_remaining: null, monthly_payment: null, months_remaining: null,
  monthly_charges: null, property_tax: null,
  rental_income: null, rented: false, tenant_name: '', notes: '',
}

const form = reactive({ ...defaultForm })

const docForm = reactive({ name: '', category: '', document_date: '', notes: '' })

// Fetch
const fetchProperties = async () => {
  properties.value = await list()
}

const fetchDocuments = async () => {
  const data = await get('/documents', { params: { domain: 'real_estate' } })
  if (data) documents.value = data
}

const propertyDocuments = () => {
  return documents.value
}

// Form
const toggleForm = () => {
  if (showForm.value) {
    showForm.value = false
    editingId.value = null
    Object.assign(form, defaultForm)
    selectedPhotos.value = []
    photoPreview.value = []
    return
  }
  Object.assign(form, { ...defaultForm })
  editingId.value = null
  showForm.value = true
}

const editProperty = (property) => {
  Object.keys(defaultForm).forEach((key) => {
    form[key] = property[key] !== null && property[key] !== undefined ? property[key] : defaultForm[key]
  })
  editingId.value = property.id
  selectedPhotos.value = []
  photoPreview.value = []
  showForm.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

const saveProperty = async () => {
  const formData = new FormData()

  Object.keys(defaultForm).forEach((key) => {
    const val = form[key]
    if (val !== null && val !== undefined && val !== '') {
      formData.append(key, val)
    }
  })

  selectedPhotos.value.forEach((file) => {
    formData.append('photos[]', file)
  })

  try {
    if (editingId.value) {
      await apiClient.patch(`/properties/${editingId.value}`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
    } else {
      await apiClient.post('/properties', formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      })
    }
    showForm.value = false
    editingId.value = null
    Object.assign(form, defaultForm)
    selectedPhotos.value = []
    photoPreview.value = []
    await fetchProperties()
  } catch (e) {
    console.error('Erreur sauvegarde:', e)
  }
}

const deleteProperty = async (id) => {
  if (!confirm('Supprimer ce bien immobilier et toutes ses photos ?')) return
  await destroy(id)
  await fetchProperties()
}

// Photos
const onPhotosSelected = (event) => {
  const files = Array.from(event.target.files)
  selectedPhotos.value.push(...files)
  files.forEach((file) => {
    const reader = new FileReader()
    reader.onload = (e) => photoPreview.value.push(e.target.result)
    reader.readAsDataURL(file)
  })
}

const removePreviewPhoto = (index) => {
  selectedPhotos.value.splice(index, 1)
  photoPreview.value.splice(index, 1)
}

const uploadPhotos = async (propertyId, event) => {
  const files = event.target.files
  if (!files.length) return
  const formData = new FormData()
  Array.from(files).forEach((f) => formData.append('photos[]', f))
  try {
    await apiClient.post(`/properties/${propertyId}/add_photos`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    await fetchProperties()
  } catch (e) {
    console.error('Erreur upload photos:', e)
  }
  event.target.value = ''
}

// Carousel
const prevPhoto = (id, count) => {
  const current = carouselIndex[id] || 0
  carouselIndex[id] = (current - 1 + count) % count
}

const nextPhoto = (id, count) => {
  const current = carouselIndex[id] || 0
  carouselIndex[id] = (current + 1) % count
}

// Documents
const toggleDocForm = (propertyId) => {
  if (activeDocForm.value === propertyId) {
    activeDocForm.value = null
  } else {
    activeDocForm.value = propertyId
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
  formData.append('domain', 'real_estate')
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

// Formatters
const formatDate = (val) => {
  if (!val) return null
  return new Date(val).toLocaleDateString('fr-FR')
}

const formatCurrency = (val) => {
  if (val === null || val === undefined) return null
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(val)
}

const typeLabel = (type) => {
  const found = propertyTypes.find(t => t.value === type)
  return found ? found.label : type
}

const typeBadge = (type) => {
  const colors = {
    appartement: 'bg-blue-100 text-blue-700',
    maison: 'bg-purple-100 text-purple-700',
    studio: 'bg-cyan-100 text-cyan-700',
    terrain: 'bg-amber-100 text-amber-700',
    commercial: 'bg-yellow-100 text-yellow-700',
    parking: 'bg-gray-100 text-gray-700',
    cave: 'bg-stone-100 text-stone-700',
    autre: 'bg-gray-100 text-gray-500',
  }
  return colors[type] || 'bg-gray-100 text-gray-500'
}

const docCategoryLabel = (val) => {
  const found = docCategories.find(c => c.value === val)
  return found ? found.label : val
}

const hasFinancials = (p) => {
  return p.purchase_price || p.current_value || p.loan_remaining || p.monthly_payment ||
    p.months_remaining || p.monthly_charges || p.property_tax || (p.rented && p.rental_income)
}

onMounted(async () => {
  await fetchProperties()
  await fetchDocuments()
})
</script>
