<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-4xl mx-auto">
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
            <span class="text-3xl">👤</span>
            <h1 class="text-2xl font-bold text-gray-900">Mon profil</h1>
          </div>
          <button
            v-if="!editing"
            @click="startEditing"
            class="bg-indigo-600 text-white px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors text-sm font-medium"
          >
            {{ profileExists ? 'Modifier' : 'Remplir mon profil' }}
          </button>
          <div v-else class="flex gap-2">
            <button
              @click="saveProfile"
              class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors text-sm font-medium"
            >
              Enregistrer
            </button>
            <button
              @click="cancelEdit"
              class="bg-gray-300 text-gray-700 px-4 py-2 rounded-lg hover:bg-gray-400 transition-colors text-sm font-medium"
            >
              Annuler
            </button>
          </div>
        </div>

        <!-- Mode lecture -->
        <div v-if="!editing">
          <div v-if="!profileExists" class="text-center text-gray-400 py-12">
            Aucun profil enregistre. Cliquez sur "Remplir mon profil" pour commencer.
          </div>

          <div v-else class="space-y-8">
            <!-- Identite -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Identite</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.first_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Prenom</span>
                  <span class="text-sm text-gray-900">{{ profile.first_name }}</span>
                </div>
                <div v-if="profile.last_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Nom</span>
                  <span class="text-sm text-gray-900">{{ profile.last_name }}</span>
                </div>
                <div v-if="profile.maiden_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Nom de naissance</span>
                  <span class="text-sm text-gray-900">{{ profile.maiden_name }}</span>
                </div>
                <div v-if="profile.birth_date" class="flex flex-col">
                  <span class="text-xs text-gray-500">Date de naissance</span>
                  <span class="text-sm text-gray-900">{{ formatDate(profile.birth_date) }}</span>
                </div>
                <div v-if="profile.birth_city" class="flex flex-col">
                  <span class="text-xs text-gray-500">Ville de naissance</span>
                  <span class="text-sm text-gray-900">{{ profile.birth_city }}</span>
                </div>
                <div v-if="profile.birth_country" class="flex flex-col">
                  <span class="text-xs text-gray-500">Pays de naissance</span>
                  <span class="text-sm text-gray-900">{{ profile.birth_country }}</span>
                </div>
                <div v-if="profile.nationality" class="flex flex-col">
                  <span class="text-xs text-gray-500">Nationalite</span>
                  <span class="text-sm text-gray-900">{{ profile.nationality }}</span>
                </div>
                <div v-if="profile.gender" class="flex flex-col">
                  <span class="text-xs text-gray-500">Genre</span>
                  <span class="text-sm text-gray-900">{{ genderLabel(profile.gender) }}</span>
                </div>
              </div>
            </section>

            <!-- Contact -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Contact</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.email" class="flex flex-col">
                  <span class="text-xs text-gray-500">Email</span>
                  <span class="text-sm text-gray-900">{{ profile.email }}</span>
                </div>
                <div v-if="profile.phone" class="flex flex-col">
                  <span class="text-xs text-gray-500">Telephone</span>
                  <span class="text-sm text-gray-900">{{ profile.phone }}</span>
                </div>
                <div v-if="profile.mobile_phone" class="flex flex-col">
                  <span class="text-xs text-gray-500">Mobile</span>
                  <span class="text-sm text-gray-900">{{ profile.mobile_phone }}</span>
                </div>
                <div v-if="profile.address_line1" class="flex flex-col">
                  <span class="text-xs text-gray-500">Adresse</span>
                  <span class="text-sm text-gray-900">{{ profile.address_line1 }}</span>
                </div>
                <div v-if="profile.address_line2" class="flex flex-col">
                  <span class="text-xs text-gray-500">Complement</span>
                  <span class="text-sm text-gray-900">{{ profile.address_line2 }}</span>
                </div>
                <div v-if="profile.city" class="flex flex-col">
                  <span class="text-xs text-gray-500">Ville</span>
                  <span class="text-sm text-gray-900">{{ profile.city }}</span>
                </div>
                <div v-if="profile.postal_code" class="flex flex-col">
                  <span class="text-xs text-gray-500">Code postal</span>
                  <span class="text-sm text-gray-900">{{ profile.postal_code }}</span>
                </div>
                <div v-if="profile.state" class="flex flex-col">
                  <span class="text-xs text-gray-500">Region</span>
                  <span class="text-sm text-gray-900">{{ profile.state }}</span>
                </div>
                <div v-if="profile.country" class="flex flex-col">
                  <span class="text-xs text-gray-500">Pays</span>
                  <span class="text-sm text-gray-900">{{ profile.country }}</span>
                </div>
              </div>
            </section>

            <!-- Documents officiels -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Documents officiels</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.social_security_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° Securite sociale</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.social_security_number ? profile.social_security_number : '••••••••' }}
                    <button @click="toggleSensitive('social_security_number')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
                <div v-if="profile.passport_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° Passeport</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.passport_number ? profile.passport_number : '••••••••' }}
                    <button @click="toggleSensitive('passport_number')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
                <div v-if="profile.passport_expiry" class="flex flex-col">
                  <span class="text-xs text-gray-500">Expiration passeport</span>
                  <span class="text-sm text-gray-900">{{ formatDate(profile.passport_expiry) }}</span>
                </div>
                <div v-if="profile.national_id_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° Carte d'identite</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.national_id_number ? profile.national_id_number : '••••••••' }}
                    <button @click="toggleSensitive('national_id_number')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
                <div v-if="profile.national_id_expiry" class="flex flex-col">
                  <span class="text-xs text-gray-500">Expiration CNI</span>
                  <span class="text-sm text-gray-900">{{ formatDate(profile.national_id_expiry) }}</span>
                </div>
                <div v-if="profile.driver_license_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° Permis de conduire</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.driver_license_number ? profile.driver_license_number : '••••••••' }}
                    <button @click="toggleSensitive('driver_license_number')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
                <div v-if="profile.driver_license_expiry" class="flex flex-col">
                  <span class="text-xs text-gray-500">Expiration permis</span>
                  <span class="text-sm text-gray-900">{{ formatDate(profile.driver_license_expiry) }}</span>
                </div>
                <div v-if="profile.tax_id" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° Fiscal</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.tax_id ? profile.tax_id : '••••••••' }}
                    <button @click="toggleSensitive('tax_id')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
              </div>
            </section>

            <!-- Professionnel -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Professionnel</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.occupation" class="flex flex-col">
                  <span class="text-xs text-gray-500">Metier</span>
                  <span class="text-sm text-gray-900">{{ profile.occupation }}</span>
                </div>
                <div v-if="profile.employer" class="flex flex-col">
                  <span class="text-xs text-gray-500">Employeur</span>
                  <span class="text-sm text-gray-900">{{ profile.employer }}</span>
                </div>
                <div v-if="profile.employer_address" class="flex flex-col">
                  <span class="text-xs text-gray-500">Adresse employeur</span>
                  <span class="text-sm text-gray-900">{{ profile.employer_address }}</span>
                </div>
                <div v-if="profile.professional_email" class="flex flex-col">
                  <span class="text-xs text-gray-500">Email professionnel</span>
                  <span class="text-sm text-gray-900">{{ profile.professional_email }}</span>
                </div>
                <div v-if="profile.professional_phone" class="flex flex-col">
                  <span class="text-xs text-gray-500">Tel professionnel</span>
                  <span class="text-sm text-gray-900">{{ profile.professional_phone }}</span>
                </div>
                <div v-if="profile.siret_number" class="flex flex-col">
                  <span class="text-xs text-gray-500">N° SIRET</span>
                  <span class="text-sm text-gray-900">{{ profile.siret_number }}</span>
                </div>
              </div>
            </section>

            <!-- Famille -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Famille</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.marital_status" class="flex flex-col">
                  <span class="text-xs text-gray-500">Situation familiale</span>
                  <span class="text-sm text-gray-900">{{ maritalLabel(profile.marital_status) }}</span>
                </div>
                <div v-if="profile.spouse_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Nom du conjoint</span>
                  <span class="text-sm text-gray-900">{{ profile.spouse_name }}</span>
                </div>
                <div v-if="profile.number_of_children != null" class="flex flex-col">
                  <span class="text-xs text-gray-500">Nombre d'enfants</span>
                  <span class="text-sm text-gray-900">{{ profile.number_of_children }}</span>
                </div>
                <div v-if="profile.emergency_contact_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Contact d'urgence</span>
                  <span class="text-sm text-gray-900">{{ profile.emergency_contact_name }}</span>
                </div>
                <div v-if="profile.emergency_contact_phone" class="flex flex-col">
                  <span class="text-xs text-gray-500">Tel urgence</span>
                  <span class="text-sm text-gray-900">{{ profile.emergency_contact_phone }}</span>
                </div>
                <div v-if="profile.emergency_contact_relationship" class="flex flex-col">
                  <span class="text-xs text-gray-500">Lien</span>
                  <span class="text-sm text-gray-900">{{ profile.emergency_contact_relationship }}</span>
                </div>
              </div>
            </section>

            <!-- Bancaire -->
            <section>
              <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Bancaire</h2>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                <div v-if="profile.bank_name" class="flex flex-col">
                  <span class="text-xs text-gray-500">Banque</span>
                  <span class="text-sm text-gray-900">{{ profile.bank_name }}</span>
                </div>
                <div v-if="profile.iban" class="flex flex-col">
                  <span class="text-xs text-gray-500">IBAN</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.iban ? profile.iban : '••••••••' }}
                    <button @click="toggleSensitive('iban')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
                <div v-if="profile.bic" class="flex flex-col">
                  <span class="text-xs text-gray-500">BIC</span>
                  <span class="text-sm text-gray-900 flex items-center gap-2">
                    {{ sensitiveVisible.bic ? profile.bic : '••••••••' }}
                    <button @click="toggleSensitive('bic')" class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                    </button>
                  </span>
                </div>
              </div>
            </section>
          </div>
        </div>

        <!-- Mode edition -->
        <form v-else @submit.prevent="saveProfile" class="space-y-8">
          <!-- Identite -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Identite</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Prenom</label>
                <input v-model="form.first_name" type="text" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nom</label>
                <input v-model="form.last_name" type="text" required class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nom de naissance</label>
                <input v-model="form.maiden_name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Date de naissance</label>
                <input v-model="form.birth_date" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Ville de naissance</label>
                <input v-model="form.birth_city" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Pays de naissance</label>
                <input v-model="form.birth_country" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nationalite</label>
                <input v-model="form.nationality" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Genre</label>
                <select v-model="form.gender" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option v-for="opt in genderOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
              </div>
            </div>
          </section>

          <!-- Contact -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Contact</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input v-model="form.email" type="email" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Telephone</label>
                <input v-model="form.phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Mobile</label>
                <input v-model="form.mobile_phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Adresse</label>
                <input v-model="form.address_line1" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Complement d'adresse</label>
                <input v-model="form.address_line2" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Ville</label>
                <input v-model="form.city" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Code postal</label>
                <input v-model="form.postal_code" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Region</label>
                <input v-model="form.state" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Pays</label>
                <input v-model="form.country" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Documents officiels -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Documents officiels</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° Securite sociale</label>
                <input v-model="form.social_security_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° Passeport</label>
                <input v-model="form.passport_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Expiration passeport</label>
                <input v-model="form.passport_expiry" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° Carte d'identite</label>
                <input v-model="form.national_id_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Expiration CNI</label>
                <input v-model="form.national_id_expiry" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° Permis de conduire</label>
                <input v-model="form.driver_license_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Expiration permis</label>
                <input v-model="form.driver_license_expiry" type="date" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° Fiscal</label>
                <input v-model="form.tax_id" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Professionnel -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Professionnel</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Metier</label>
                <input v-model="form.occupation" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Employeur</label>
                <input v-model="form.employer" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Adresse employeur</label>
                <input v-model="form.employer_address" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email professionnel</label>
                <input v-model="form.professional_email" type="email" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Tel professionnel</label>
                <input v-model="form.professional_phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">N° SIRET</label>
                <input v-model="form.siret_number" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Famille -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Famille</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Situation familiale</label>
                <select v-model="form.marital_status" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white">
                  <option v-for="opt in maritalOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
                </select>
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nom du conjoint</label>
                <input v-model="form.spouse_name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Nombre d'enfants</label>
                <input v-model="form.number_of_children" type="number" min="0" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Contact d'urgence (nom)</label>
                <input v-model="form.emergency_contact_name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Tel urgence</label>
                <input v-model="form.emergency_contact_phone" type="tel" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Lien (ex: pere, conjoint)</label>
                <input v-model="form.emergency_contact_relationship" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>

          <!-- Bancaire -->
          <section>
            <h2 class="text-lg font-semibold text-gray-800 mb-3 border-b pb-2">Bancaire</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Banque</label>
                <input v-model="form.bank_name" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">IBAN</label>
                <input v-model="form.iban" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">BIC</label>
                <input v-model="form.bic" type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500" />
              </div>
            </div>
          </section>
        </form>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'

const { get, post, patch } = useApi()

const profile = ref({})
const profileExists = ref(false)
const editing = ref(false)
const sensitiveVisible = reactive({
  social_security_number: false,
  passport_number: false,
  national_id_number: false,
  driver_license_number: false,
  tax_id: false,
  iban: false,
  bic: false,
})

const emptyForm = {
  first_name: '', last_name: '', maiden_name: '', birth_date: '', birth_city: '',
  birth_country: '', nationality: '', gender: '',
  email: '', phone: '', mobile_phone: '', address_line1: '', address_line2: '',
  city: '', postal_code: '', state: '', country: '',
  social_security_number: '', passport_number: '', passport_expiry: '',
  national_id_number: '', national_id_expiry: '', driver_license_number: '',
  driver_license_expiry: '', tax_id: '',
  occupation: '', employer: '', employer_address: '', professional_email: '',
  professional_phone: '', siret_number: '',
  marital_status: '', spouse_name: '', number_of_children: null,
  emergency_contact_name: '', emergency_contact_phone: '', emergency_contact_relationship: '',
  bank_name: '', iban: '', bic: '',
}

const form = reactive({ ...emptyForm })

const genderOptions = [
  { value: '', label: '-- Choisir --' },
  { value: 'male', label: 'Homme' },
  { value: 'female', label: 'Femme' },
  { value: 'other', label: 'Autre' },
]

const maritalOptions = [
  { value: '', label: '-- Choisir --' },
  { value: 'single', label: 'Celibataire' },
  { value: 'married', label: 'Marie(e)' },
  { value: 'pacs', label: 'Pacse(e)' },
  { value: 'divorced', label: 'Divorce(e)' },
  { value: 'widowed', label: 'Veuf/Veuve' },
]

const genderLabel = (val) => {
  const opt = genderOptions.find(o => o.value === val)
  return opt ? opt.label : val
}

const maritalLabel = (val) => {
  const opt = maritalOptions.find(o => o.value === val)
  return opt ? opt.label : val
}

const formatDate = (val) => {
  if (!val) return null
  return new Date(val).toLocaleDateString('fr-FR')
}

const toggleSensitive = (field) => {
  sensitiveVisible[field] = !sensitiveVisible[field]
}

const fetchProfile = async () => {
  const data = await get('/personal_profile')
  if (data) {
    profile.value = data
    profileExists.value = true
  }
}

const fillForm = () => {
  Object.keys(emptyForm).forEach(key => {
    form[key] = profile.value[key] || emptyForm[key]
  })
}

const startEditing = () => {
  if (profileExists.value) fillForm()
  editing.value = true
}

const cancelEdit = () => {
  editing.value = false
  if (profileExists.value) fillForm()
  else Object.assign(form, emptyForm)
}

const saveProfile = async () => {
  const payload = { personal_profile: { ...form } }
  if (profileExists.value) {
    const data = await patch('/personal_profile', payload)
    if (data && !data.errors) {
      profile.value = data
      editing.value = false
    }
  } else {
    const data = await post('/personal_profile', payload)
    if (data && !data.errors) {
      profile.value = data
      profileExists.value = true
      editing.value = false
    }
  }
}

onMounted(fetchProfile)
</script>
