<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-7xl mx-auto">
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

      <!-- Alertes anniversaires -->
      <div
        v-for="alert in birthdayAlerts"
        :key="'bday-' + alert.id"
        class="mb-3 flex items-center gap-3 px-4 py-3 bg-purple-50 border border-purple-200 rounded-lg text-sm text-purple-800"
      >
        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 15.546c-.523 0-1.046.151-1.5.454a2.704 2.704 0 01-3 0 2.704 2.704 0 00-3 0 2.704 2.704 0 01-3 0 2.704 2.704 0 00-3 0 2.704 2.704 0 01-3 0A1.75 1.75 0 003 15.546V12a9 9 0 0118 0v3.546zM12 3v1m0 0a3 3 0 013 3H9a3 3 0 013-3z" />
        </svg>
        <span>
          <strong>{{ alert.first_name }} {{ alert.last_name }}</strong>
          {{ alert.message }}
        </span>
      </div>

      <!-- Alertes contacts suivis sans nouvelles -->
      <div
        v-for="alert in contactAlerts"
        :key="'contact-' + alert.id"
        class="mb-3 flex items-center gap-3 px-4 py-3 bg-amber-50 border border-amber-200 rounded-lg text-sm text-amber-800"
      >
        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span>
          <strong>{{ alert.first_name }} {{ alert.last_name }}</strong> — pas de contact depuis {{ alert.days }} jours
        </span>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-8">
        <div class="flex items-center justify-between mb-6">
          <div class="flex items-center gap-3">
            <span class="text-3xl">👥</span>
            <h1 class="text-2xl font-bold text-gray-900">Contacts</h1>
            <span class="text-sm text-gray-400">({{ contacts.length }})</span>
          </div>
          <button
            @click="openForm()"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ showForm ? 'Annuler' : '+ Ajouter' }}
          </button>
        </div>

        <!-- Formulaire d'ajout / édition -->
        <form v-if="showForm" @submit.prevent="saveContact" class="mb-6 p-5 bg-gray-50 rounded-lg">
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
            <input
              v-model="form.last_name"
              type="text"
              placeholder="Nom *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.first_name"
              type="text"
              placeholder="Prénom *"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.birth_date"
              type="date"
              title="Date de naissance"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <select
              v-model="form.gender"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Sexe</option>
              <option value="homme">Homme</option>
              <option value="femme">Femme</option>
              <option value="autre">Autre</option>
            </select>
            <input
              v-model="form.occupation"
              type="text"
              placeholder="Activité"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.city"
              type="text"
              placeholder="Ville"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.phone"
              type="tel"
              placeholder="Téléphone"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.email"
              type="email"
              placeholder="Email"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <div>
              <label class="block text-xs text-gray-500 mb-1">Dernier contact</label>
              <input
                v-model="form.last_contacted_on"
                type="date"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
              />
            </div>
            <select
              v-model="form.relationship_type"
              required
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="" disabled>Type de relation *</option>
              <option v-for="t in relationshipTypes" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
          </div>
          <!-- Adresse & rencontre -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 mt-3">
            <input
              v-model="form.address"
              type="text"
              placeholder="Adresse"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.met_through"
              type="text"
              placeholder="Comment on s'est rencontrés"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="form.met_year"
              type="number"
              placeholder="Année de rencontre"
              min="1900"
              max="2100"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>
          <!-- Réseaux sociaux -->
          <div class="mt-3">
            <p class="text-xs text-gray-500 mb-2 font-medium">Réseaux sociaux (nom d'utilisateur ou lien)</p>
            <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
              <input v-model="form.social_instagram" type="text" placeholder="Instagram"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input v-model="form.social_linkedin" type="text" placeholder="LinkedIn"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input v-model="form.social_twitter" type="text" placeholder="X (Twitter)"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input v-model="form.social_facebook" type="text" placeholder="Facebook"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input v-model="form.social_tiktok" type="text" placeholder="TikTok"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input v-model="form.social_snapchat" type="text" placeholder="Snapchat"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              <input v-model="form.social_youtube" type="text" placeholder="YouTube"
                class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
            </div>
          </div>
          <!-- Champs libres -->
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-3">
            <textarea
              v-model="form.likes"
              placeholder="Aime (centres d'intérêt, passions...)"
              rows="2"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
            <textarea
              v-model="form.dislikes"
              placeholder="Aime pas (à éviter, sujets sensibles...)"
              rows="2"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
            <textarea
              v-model="form.loans"
              placeholder="Prêts (objets, argent...)"
              rows="2"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
            <textarea
              v-model="form.notes"
              placeholder="Notes libres"
              rows="2"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>
          <div class="mt-4 flex gap-2">
            <button
              type="submit"
              class="bg-green-600 text-white px-5 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
            >
              {{ editingId ? 'Modifier' : 'Enregistrer' }}
            </button>
            <button
              type="button"
              @click="showForm = false"
              class="bg-gray-200 text-gray-700 px-5 py-2 rounded-lg hover:bg-gray-300 transition-colors text-sm font-medium"
            >
              Annuler
            </button>
          </div>
        </form>

        <!-- Filtres -->
        <div class="mb-4 p-4 bg-gray-50 rounded-lg">
          <div class="flex items-center gap-2 mb-3">
            <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
            </svg>
            <span class="text-sm font-medium text-gray-600">Filtres</span>
            <button
              v-if="hasActiveFilters"
              @click="clearFilters"
              class="ml-auto text-xs text-indigo-600 hover:text-indigo-800"
            >
              Effacer les filtres
            </button>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <input
              v-model="filterName"
              type="text"
              placeholder="Nom ou prénom"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <input
              v-model="filterCity"
              type="text"
              placeholder="Ville"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
            <select
              v-model="filterType"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Tous les types</option>
              <option v-for="t in relationshipTypes" :key="t.value" :value="t.value">{{ t.label }}</option>
            </select>
            <select
              v-model="filterGender"
              class="px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            >
              <option value="">Tous les sexes</option>
              <option value="homme">Homme</option>
              <option value="femme">Femme</option>
              <option value="autre">Autre</option>
            </select>
          </div>
          <div class="mt-3 flex items-center">
            <label class="inline-flex items-center cursor-pointer gap-2 text-sm text-gray-600">
              <input
                v-model="filterFollowed"
                type="checkbox"
                class="w-4 h-4 text-indigo-600 border-gray-300 rounded focus:ring-indigo-500"
              />
              Afficher uniquement les contacts suivis
            </label>
          </div>
        </div>

        <!-- Tableau -->
        <div v-if="contacts.length === 0" class="text-center text-gray-400 py-12">
          Aucun contact enregistré
        </div>

        <div v-else-if="filteredContacts.length === 0" class="text-center text-gray-400 py-12">
          Aucun contact trouvé
        </div>

        <div v-else class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-gray-200 text-left text-xs text-gray-500 uppercase tracking-wider">
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('last_name')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Nom <span v-html="sortIcon('last_name')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('age')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Âge <span v-html="sortIcon('age')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">Sexe</th>
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('occupation')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Activité <span v-html="sortIcon('occupation')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('city')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Ville <span v-html="sortIcon('city')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">Téléphone</th>
                <th class="pb-3 font-medium">Email</th>
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('birth_date')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Anniversaire <span v-html="sortIcon('birth_date')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('last_contacted_on')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Dernier contact <span v-html="sortIcon('last_contacted_on')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">
                  <button @click="toggleSort('relationship_type')" class="inline-flex items-center gap-1 hover:text-gray-700">
                    Relation <span v-html="sortIcon('relationship_type')"></span>
                  </button>
                </th>
                <th class="pb-3 font-medium">Réseaux</th>
                <th class="pb-3 font-medium w-24"></th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="contact in filteredContacts"
                :key="contact.id"
                class="border-b border-gray-100 hover:bg-gray-50"
              >
                <td class="py-3 text-sm text-gray-900 font-medium whitespace-nowrap">
                  {{ contact.last_name }} {{ contact.first_name }}
                </td>
                <td class="py-3 text-sm text-gray-700">{{ computeAge(contact.birth_date) }}</td>
                <td class="py-3 text-sm text-gray-700">{{ genderLabel(contact.gender) }}</td>
                <td class="py-3 text-sm text-gray-700">{{ contact.occupation || '—' }}</td>
                <td class="py-3 text-sm text-gray-700">{{ contact.city || '—' }}</td>
                <td class="py-3 text-sm text-gray-700 whitespace-nowrap">
                  <a v-if="contact.phone" :href="'tel:' + contact.phone" class="text-indigo-600 hover:underline">{{ contact.phone }}</a>
                  <span v-else>—</span>
                </td>
                <td class="py-3 text-sm text-gray-700">
                  <a v-if="contact.email" :href="'mailto:' + contact.email" class="text-indigo-600 hover:underline">{{ contact.email }}</a>
                  <span v-else>—</span>
                </td>
                <td class="py-3 text-sm text-gray-700 whitespace-nowrap">{{ formatDate(contact.birth_date) }}</td>
                <td class="py-3 text-sm whitespace-nowrap" :class="lastContactColor(contact.last_contacted_on)">
                  {{ formatDate(contact.last_contacted_on) }}
                </td>
                <td class="py-3">
                  <span
                    class="inline-block px-2 py-0.5 rounded-full text-xs font-medium"
                    :class="relationshipBadge(contact.relationship_type)"
                  >
                    {{ relationshipLabel(contact.relationship_type) }}
                  </span>
                </td>
                <td class="py-3">
                  <div class="flex items-center gap-1.5">
                    <a v-if="contact.social_instagram" :href="socialUrl('instagram', contact.social_instagram)" target="_blank" rel="noopener" title="Instagram" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#E4405F"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zM12 0C8.741 0 8.333.014 7.053.072 2.695.272.273 2.69.073 7.052.014 8.333 0 8.741 0 12c0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98C8.333 23.986 8.741 24 12 24c3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98C15.668.014 15.259 0 12 0zm0 5.838a6.162 6.162 0 100 12.324 6.162 6.162 0 000-12.324zM12 16a4 4 0 110-8 4 4 0 010 8zm6.406-11.845a1.44 1.44 0 100 2.881 1.44 1.44 0 000-2.881z"/></svg>
                    </a>
                    <a v-if="contact.social_linkedin" :href="socialUrl('linkedin', contact.social_linkedin)" target="_blank" rel="noopener" title="LinkedIn" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#0A66C2"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433a2.062 2.062 0 01-2.063-2.065 2.064 2.064 0 112.063 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
                    </a>
                    <a v-if="contact.social_twitter" :href="socialUrl('twitter', contact.social_twitter)" target="_blank" rel="noopener" title="X (Twitter)" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#000000"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>
                    </a>
                    <a v-if="contact.social_facebook" :href="socialUrl('facebook', contact.social_facebook)" target="_blank" rel="noopener" title="Facebook" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#1877F2"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>
                    </a>
                    <a v-if="contact.social_tiktok" :href="socialUrl('tiktok', contact.social_tiktok)" target="_blank" rel="noopener" title="TikTok" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#000000"><path d="M12.525.02c1.31-.02 2.61-.01 3.91-.02.08 1.53.63 3.09 1.75 4.17 1.12 1.11 2.7 1.62 4.24 1.79v4.03c-1.44-.05-2.89-.35-4.2-.97-.57-.26-1.1-.59-1.62-.93-.01 2.92.01 5.84-.02 8.75-.08 1.4-.54 2.79-1.35 3.94-1.31 1.92-3.58 3.17-5.91 3.21-1.43.08-2.86-.31-4.08-1.03-2.02-1.19-3.44-3.37-3.65-5.71-.02-.5-.03-1-.01-1.49.18-1.9 1.12-3.72 2.58-4.96 1.66-1.44 3.98-2.13 6.15-1.72.02 1.48-.04 2.96-.04 4.44-.99-.32-2.15-.23-3.02.37-.63.41-1.11 1.04-1.36 1.75-.21.51-.15 1.07-.14 1.61.24 1.64 1.82 3.02 3.5 2.87 1.12-.01 2.19-.66 2.77-1.61.19-.33.4-.67.41-1.06.1-1.79.06-3.57.07-5.36.01-4.03-.01-8.05.02-12.07z"/></svg>
                    </a>
                    <a v-if="contact.social_snapchat" :href="socialUrl('snapchat', contact.social_snapchat)" target="_blank" rel="noopener" title="Snapchat" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#FFFC00"><path d="M12.206.793c.99 0 4.347.276 5.93 3.821.529 1.193.403 3.219.299 4.847l-.003.06c-.012.18-.022.345-.03.51.075.045.203.09.401.09.3-.016.659-.12.922-.214.12-.042.195-.07.288-.07.254 0 .467.137.514.182a.55.55 0 01.182.39c-.003.175-.1.331-.29.472-.12.09-.257.157-.399.225-.276.134-.613.298-.728.567a.602.602 0 00-.018.377c.366 1.282.933 2.073 1.294 2.532.12.153.167.227.167.272a.373.373 0 01-.095.218c-.186.233-.478.39-.84.542a5.04 5.04 0 01-.534.176c-.14.04-.28.08-.415.136a.8.8 0 00-.378.358c-.083.155-.1.366.084.63.015.02.03.038.044.06.239.328.3.655.178.977-.145.381-.57.63-1.244.726-.285.04-.6.04-.942.04h-.12c-.422 0-.853.062-1.275.18-.418.119-.791.298-1.163.476-.397.19-.792.378-1.228.496a4.07 4.07 0 01-.672.104l-.012.001c-.238.02-.48.02-.72 0a4.07 4.07 0 01-.67-.104c-.437-.118-.832-.307-1.228-.497-.373-.178-.746-.357-1.164-.476a4.25 4.25 0 00-1.275-.18h-.12c-.317 0-.636 0-.942-.04-.674-.097-1.099-.346-1.243-.727-.123-.322-.062-.649.177-.977.015-.021.03-.04.044-.06.183-.264.167-.475.084-.63a.8.8 0 00-.378-.357c-.136-.057-.276-.097-.415-.137a5.04 5.04 0 01-.534-.175c-.362-.153-.655-.31-.84-.543a.373.373 0 01-.095-.218c0-.045.046-.12.167-.272.36-.459.928-1.25 1.294-2.532a.602.602 0 00-.018-.377c-.114-.269-.451-.433-.728-.567a2.62 2.62 0 01-.399-.225c-.19-.14-.287-.297-.29-.472a.55.55 0 01.182-.39c.047-.045.26-.182.514-.182.093 0 .168.028.288.07.263.094.622.23.922.214.198 0 .326-.045.4-.09a23.41 23.41 0 01-.032-.57c-.104-1.628-.23-3.654.3-4.848C7.85 1.068 11.216.793 12.207.793z"/></svg>
                    </a>
                    <a v-if="contact.social_youtube" :href="socialUrl('youtube', contact.social_youtube)" target="_blank" rel="noopener" title="YouTube" class="hover:opacity-80">
                      <svg class="w-4 h-4" viewBox="0 0 24 24" fill="#FF0000"><path d="M23.498 6.186a3.016 3.016 0 00-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 00.502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 002.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 002.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>
                    </a>
                    <span v-if="!hasSocials(contact)" class="text-gray-300 text-xs">—</span>
                  </div>
                </td>
                <td class="py-3 text-right whitespace-nowrap">
                  <button
                    @click="toggleFollowed(contact)"
                    class="text-sm mr-2 transition-colors"
                    :class="contact.followed ? 'text-amber-500 hover:text-amber-600' : 'text-gray-300 hover:text-amber-500'"
                    :title="contact.followed ? 'Ne plus suivre' : 'Suivre'"
                  >
                    <svg class="w-4 h-4 inline" :fill="contact.followed ? 'currentColor' : 'none'" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z" />
                    </svg>
                  </button>
                  <button
                    @click="editContact(contact)"
                    class="text-gray-400 hover:text-indigo-600 text-sm mr-2"
                    title="Modifier"
                  >
                    <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                  </button>
                  <button
                    @click="deleteContact(contact.id)"
                    class="text-gray-400 hover:text-red-600 text-sm"
                    title="Supprimer"
                  >
                    <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { useCrud } = useApi()
const { list, create, update, destroy } = useCrud('contacts')

const contacts = ref([])
const showForm = ref(false)
const editingId = ref(null)
const filterName = ref('')
const filterCity = ref('')
const filterType = ref('')
const filterGender = ref('')
const filterFollowed = ref(false)
const sortKey = ref('last_name')
const sortDir = ref('asc')

const relationshipTypes = [
  { value: 'ami', label: 'Ami' },
  { value: 'copine', label: 'Copine' },
  { value: 'famille', label: 'Famille' },
  { value: 'collegue', label: 'Collègue' },
  { value: 'connaissance', label: 'Connaissance' },
  { value: 'client', label: 'Client' },
  { value: 'eleve', label: 'Élève' },
  { value: 'medias', label: 'Médias' },
  { value: 'autre', label: 'Autre' },
]

const defaultForm = {
  first_name: '',
  last_name: '',
  birth_date: '',
  gender: '',
  occupation: '',
  city: '',
  phone: '',
  email: '',
  last_contacted_on: '',
  relationship_type: '',
  notes: '',
  likes: '',
  dislikes: '',
  loans: '',
  address: '',
  met_through: '',
  met_year: '',
  social_instagram: '',
  social_linkedin: '',
  social_twitter: '',
  social_facebook: '',
  social_tiktok: '',
  social_snapchat: '',
  social_youtube: '',
}

const form = reactive({ ...defaultForm })

const hasActiveFilters = computed(() => {
  return filterName.value || filterCity.value || filterType.value || filterGender.value || filterFollowed.value
})

const clearFilters = () => {
  filterName.value = ''
  filterCity.value = ''
  filterType.value = ''
  filterGender.value = ''
  filterFollowed.value = false
}

const toggleSort = (key) => {
  if (sortKey.value === key) {
    sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortKey.value = key
    sortDir.value = 'asc'
  }
}

const sortIcon = (key) => {
  if (sortKey.value !== key) return '<span class="text-gray-300">&#8597;</span>'
  return sortDir.value === 'asc'
    ? '<span class="text-indigo-600">&#9650;</span>'
    : '<span class="text-indigo-600">&#9660;</span>'
}

const filteredContacts = computed(() => {
  let result = contacts.value.filter((c) => {
    const qName = filterName.value.toLowerCase()
    const qCity = filterCity.value.toLowerCase()
    const matchesName =
      !qName ||
      c.last_name.toLowerCase().includes(qName) ||
      c.first_name.toLowerCase().includes(qName)
    const matchesCity = !qCity || (c.city && c.city.toLowerCase().includes(qCity))
    const matchesType = !filterType.value || c.relationship_type === filterType.value
    const matchesGender = !filterGender.value || c.gender === filterGender.value
    const matchesFollowed = !filterFollowed.value || c.followed
    return matchesName && matchesCity && matchesType && matchesGender && matchesFollowed
  })

  const dir = sortDir.value === 'asc' ? 1 : -1
  result.sort((a, b) => {
    let valA, valB
    if (sortKey.value === 'age') {
      valA = a.birth_date ? new Date(a.birth_date).getTime() : 0
      valB = b.birth_date ? new Date(b.birth_date).getTime() : 0
      // Older = higher age, so for age asc we want birth_date desc
      return (valB - valA) * dir
    }
    if (sortKey.value === 'birth_date' || sortKey.value === 'last_contacted_on') {
      valA = a[sortKey.value] ? new Date(a[sortKey.value]).getTime() : 0
      valB = b[sortKey.value] ? new Date(b[sortKey.value]).getTime() : 0
      return (valA - valB) * dir
    }
    valA = (a[sortKey.value] || '').toLowerCase()
    valB = (b[sortKey.value] || '').toLowerCase()
    return valA.localeCompare(valB, 'fr') * dir
  })

  return result
})

const fetchContacts = async () => {
  contacts.value = await list()
}

const openForm = () => {
  if (showForm.value) {
    showForm.value = false
    editingId.value = null
    return
  }
  Object.assign(form, defaultForm)
  editingId.value = null
  showForm.value = true
}

const editContact = (contact) => {
  Object.assign(form, {
    first_name: contact.first_name,
    last_name: contact.last_name,
    birth_date: contact.birth_date || '',
    gender: contact.gender || '',
    occupation: contact.occupation || '',
    city: contact.city || '',
    phone: contact.phone || '',
    email: contact.email || '',
    last_contacted_on: contact.last_contacted_on || '',
    relationship_type: contact.relationship_type,
    notes: contact.notes || '',
    likes: contact.likes || '',
    dislikes: contact.dislikes || '',
    loans: contact.loans || '',
    address: contact.address || '',
    met_through: contact.met_through || '',
    met_year: contact.met_year || '',
    social_instagram: contact.social_instagram || '',
    social_linkedin: contact.social_linkedin || '',
    social_twitter: contact.social_twitter || '',
    social_facebook: contact.social_facebook || '',
    social_tiktok: contact.social_tiktok || '',
    social_snapchat: contact.social_snapchat || '',
    social_youtube: contact.social_youtube || '',
  })
  editingId.value = contact.id
  showForm.value = true
}

const saveContact = async () => {
  const payload = { contact: { ...form } }
  // Remove empty strings to avoid sending blank values
  Object.keys(payload.contact).forEach((key) => {
    if (payload.contact[key] === '') payload.contact[key] = null
  })
  if (editingId.value) {
    await update(editingId.value, payload)
  } else {
    await create(payload)
  }
  showForm.value = false
  editingId.value = null
  Object.assign(form, defaultForm)
  await fetchContacts()
}

const toggleFollowed = async (contact) => {
  await update(contact.id, { contact: { followed: !contact.followed } })
  await fetchContacts()
}

const deleteContact = async (id) => {
  if (!confirm('Supprimer ce contact ?')) return
  await destroy(id)
  await fetchContacts()
}

const computeAge = (birthDate) => {
  if (!birthDate) return '—'
  const today = new Date()
  const birth = new Date(birthDate)
  let age = today.getFullYear() - birth.getFullYear()
  const m = today.getMonth() - birth.getMonth()
  if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--
  return age
}

const formatDate = (date) => {
  if (!date) return '—'
  return new Date(date).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

const genderLabel = (gender) => {
  const map = { homme: 'H', femme: 'F', autre: 'A' }
  return map[gender] || '—'
}

const relationshipLabel = (type) => {
  const found = relationshipTypes.find((t) => t.value === type)
  return found ? found.label : type
}

const relationshipBadge = (type) => {
  const colors = {
    ami: 'bg-blue-100 text-blue-700',
    copine: 'bg-red-100 text-red-700',
    famille: 'bg-purple-100 text-purple-700',
    collegue: 'bg-yellow-100 text-yellow-700',
    connaissance: 'bg-gray-100 text-gray-700',
    client: 'bg-green-100 text-green-700',
    eleve: 'bg-pink-100 text-pink-700',
    medias: 'bg-orange-100 text-orange-700',
    autre: 'bg-gray-100 text-gray-500',
  }
  return colors[type] || 'bg-gray-100 text-gray-500'
}

const hasSocials = (contact) => {
  return contact.social_instagram || contact.social_linkedin || contact.social_twitter ||
    contact.social_facebook || contact.social_tiktok || contact.social_snapchat || contact.social_youtube
}

const socialUrl = (platform, value) => {
  if (!value) return '#'
  if (value.startsWith('http')) return value
  const bases = {
    instagram: 'https://instagram.com/',
    linkedin: 'https://linkedin.com/in/',
    twitter: 'https://x.com/',
    facebook: 'https://facebook.com/',
    tiktok: 'https://tiktok.com/@',
    snapchat: 'https://snapchat.com/add/',
    youtube: 'https://youtube.com/@',
  }
  return bases[platform] + value
}

const birthdayAlerts = computed(() => {
  const today = new Date()
  const alerts = []
  contacts.value.forEach((c) => {
    if (!c.birth_date) return
    const birth = new Date(c.birth_date)
    const thisYear = new Date(today.getFullYear(), birth.getMonth(), birth.getDate())
    const diff = Math.round((thisYear - today) / (1000 * 60 * 60 * 24))
    if (diff >= 0 && diff <= 7) {
      const message = diff === 0 ? 'fête son anniversaire aujourd\'hui !' : `fête son anniversaire dans ${diff} jour${diff > 1 ? 's' : ''}`
      alerts.push({ id: c.id, first_name: c.first_name, last_name: c.last_name, message, diff })
    }
  })
  return alerts.sort((a, b) => a.diff - b.diff)
})

const contactAlerts = computed(() => {
  const today = new Date()
  const alerts = []
  contacts.value.forEach((c) => {
    if (!c.followed) return
    const lastDate = c.last_contacted_on ? new Date(c.last_contacted_on) : null
    if (!lastDate) {
      alerts.push({ id: c.id, first_name: c.first_name, last_name: c.last_name, days: '?' })
      return
    }
    const days = Math.floor((today - lastDate) / (1000 * 60 * 60 * 24))
    if (days > 30) {
      alerts.push({ id: c.id, first_name: c.first_name, last_name: c.last_name, days })
    }
  })
  return alerts.sort((a, b) => {
    if (a.days === '?') return 1
    if (b.days === '?') return -1
    return b.days - a.days
  })
})

const lastContactColor = (date) => {
  if (!date) return 'text-gray-400'
  const days = Math.floor((new Date() - new Date(date)) / (1000 * 60 * 60 * 24))
  if (days <= 30) return 'text-green-600'
  if (days <= 90) return 'text-yellow-600'
  return 'text-red-500'
}

onMounted(fetchContacts)
</script>
