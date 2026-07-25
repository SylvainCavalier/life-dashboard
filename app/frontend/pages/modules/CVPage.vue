<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-5xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-3">
          <span class="text-3xl">📄</span>
          <div>
            <h1 class="text-2xl font-bold text-gray-900">Mon CV</h1>
            <p class="text-sm text-gray-500">Expériences, formations, compétences et centres d'intérêt</p>
          </div>
        </div>
        <button
          @click="showPreview = true"
          class="bg-indigo-600 text-white text-sm px-4 py-2 rounded-lg hover:bg-indigo-700 transition"
        >
          👁 Aperçu & export PDF
        </button>
      </div>

      <!-- Infos personnelles (lecture seule, depuis PersonalProfile) -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Informations personnelles</h2>
          <router-link to="/profile" class="text-xs text-indigo-600 hover:text-indigo-800">Modifier dans Profil →</router-link>
        </div>
        <div class="flex flex-col md:flex-row gap-6">
          <!-- Photo slot -->
          <div class="flex-shrink-0 flex flex-col items-center gap-2">
            <div class="relative w-32 h-32 rounded-full overflow-hidden bg-gray-100 border-2 border-dashed border-gray-300 flex items-center justify-center">
              <img v-if="settings.photo_data_url" :src="settings.photo_data_url" alt="Photo CV" class="w-full h-full object-cover" />
              <span v-else class="text-gray-400 text-xs text-center px-2">Aucune photo</span>
              <div v-if="photoUploading" class="absolute inset-0 bg-white/70 flex items-center justify-center text-xs text-gray-600">Upload...</div>
            </div>
            <input ref="photoInput" type="file" accept="image/jpeg,image/png,image/webp" class="hidden" @change="onPhotoSelected" />
            <div class="flex gap-2">
              <button @click="$refs.photoInput.click()" :disabled="photoUploading" class="text-xs text-indigo-600 hover:text-indigo-800 disabled:opacity-50">
                {{ settings.photo_data_url ? 'Changer' : 'Ajouter' }}
              </button>
              <button v-if="settings.photo_data_url" @click="removePhoto" :disabled="photoUploading" class="text-xs text-red-500 hover:text-red-700">
                Supprimer
              </button>
            </div>
            <div v-if="photoError" class="text-xs text-red-600 text-center">{{ photoError }}</div>
          </div>

          <!-- Profile fields -->
          <div v-if="profile && (profile.first_name || profile.last_name)" class="flex-1 grid grid-cols-2 md:grid-cols-4 gap-4 text-sm content-start">
            <div>
              <div class="text-xs text-gray-500">Nom complet</div>
              <div class="font-medium text-gray-900">{{ profile.full_name }}</div>
            </div>
            <div>
              <div class="text-xs text-gray-500">Âge</div>
              <div class="font-medium text-gray-900">{{ profile.age ?? '—' }}{{ profile.age ? ' ans' : '' }}</div>
            </div>
            <div>
              <div class="text-xs text-gray-500">Email</div>
              <div class="font-medium text-gray-900">{{ profile.email || '—' }}</div>
            </div>
            <div>
              <div class="text-xs text-gray-500">Téléphone</div>
              <div class="font-medium text-gray-900">{{ profile.mobile_phone || profile.phone || '—' }}</div>
            </div>
            <div class="col-span-2 md:col-span-4">
              <div class="text-xs text-gray-500">Adresse</div>
              <div class="font-medium text-gray-900">{{ profile.full_address || '—' }}</div>
            </div>
          </div>
          <div v-else class="flex-1 text-sm text-gray-400 italic">
            Aucune information personnelle. <router-link to="/profile" class="text-indigo-600 hover:underline">Renseigner mon profil</router-link>.
          </div>
        </div>
      </section>

      <!-- Accroche -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-2">
          <h2 class="text-lg font-semibold text-gray-900">Accroche</h2>
          <span class="text-xs text-gray-400">2-3 lignes qui te résument — affichée en haut du CV</span>
        </div>
        <textarea
          v-model="pitchDraft"
          @blur="savePitch"
          rows="3"
          placeholder="Ex. Développeur full-stack passionné par les produits utiles. 8 ans d'expérience en Rails/Vue, spécialisé dans les apps à forte logique métier."
          class="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-200"
        ></textarea>
        <div v-if="pitchSaving" class="text-xs text-gray-400 mt-1">Enregistrement...</div>
      </section>

      <!-- Expériences professionnelles -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Expériences professionnelles</h2>
          <button @click="openExperienceForm(null, null)" class="text-sm bg-black text-white px-3 py-1.5 rounded-lg hover:bg-gray-800 transition">
            + Ajouter
          </button>
        </div>

        <div v-if="experienceForm.open && PRO_CATEGORIES.includes(experienceForm.category)" class="bg-gray-50 rounded-lg p-4 mb-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
            <input v-model="experienceForm.title" placeholder="Titre du poste *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="experienceForm.company" placeholder="Entreprise *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="experienceForm.location" placeholder="Lieu" class="border rounded-lg px-3 py-2 text-sm" />
            <select v-model="experienceForm.category" class="border rounded-lg px-3 py-2 text-sm">
              <option :value="null">— Catégorie —</option>
              <option v-for="cat in experienceCategories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
            </select>
            <div class="grid grid-cols-2 gap-2">
              <input v-model.number="experienceForm.start_year" type="number" min="1900" :max="maxYear" placeholder="Année de début *" class="border rounded-lg px-3 py-2 text-sm" />
              <input v-model.number="experienceForm.end_year" type="number" min="1900" :max="maxYear + 10" placeholder="Année de fin (vide = en cours)" class="border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div class="flex items-center gap-4">
              <span class="text-sm text-gray-500">Domaine(s) :</span>
              <label v-for="d in experienceDomains" :key="d.value" class="flex items-center gap-1.5 text-sm cursor-pointer">
                <input type="checkbox" :value="d.value" v-model="experienceForm.domain" class="accent-indigo-600" />
                {{ d.label }}
              </label>
            </div>
          </div>
          <textarea v-model="experienceForm.description" rows="3" placeholder="Description, missions, résultats..." class="w-full border rounded-lg px-3 py-2 text-sm mb-3"></textarea>
          <div class="flex justify-end gap-2">
            <button @click="experienceForm.open = false" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
            <button @click="saveExperience" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
              {{ experienceForm.id ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>

        <div v-if="experiencesProf.length === 0 && !(experienceForm.open && PRO_CATEGORIES.includes(experienceForm.category))" class="text-sm text-gray-400 italic text-center py-4">
          Aucune expérience enregistrée
        </div>
        <ul class="space-y-3">
          <li v-for="exp in experiencesProf" :key="exp.id" class="border border-gray-100 rounded-lg p-4 hover:bg-gray-50 transition">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="font-semibold text-gray-900">{{ exp.title }}</span>
                  <span v-if="exp.category" class="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-600">{{ categoryLabel(exp.category) }}</span>
                  <span v-for="d in (exp.domain || [])" :key="d" class="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded-full bg-amber-50 text-amber-600">{{ domainLabel(d) }}</span>
                </div>
                <div class="text-sm text-gray-600">{{ exp.company }}<span v-if="exp.location"> · {{ exp.location }}</span></div>
                <div class="text-xs text-gray-400 mt-0.5">{{ formatYearRange(exp.start_year, exp.end_year) }}</div>
                <p v-if="exp.description" class="text-sm text-gray-700 mt-2 whitespace-pre-line">{{ exp.description }}</p>
              </div>
              <div class="flex gap-2 text-xs">
                <button @click="openExperienceForm(exp)" class="text-blue-500 hover:text-blue-700">Modifier</button>
                <button @click="deleteExperience(exp.id)" class="text-red-400 hover:text-red-600">Supprimer</button>
              </div>
            </div>
          </li>
        </ul>
      </section>

      <!-- Conférences & Interventions -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Conférences & Interventions</h2>
          <button @click="openExperienceForm(null, 'intervention')" class="text-sm bg-black text-white px-3 py-1.5 rounded-lg hover:bg-gray-800 transition">
            + Ajouter
          </button>
        </div>

        <div v-if="experienceForm.open && experienceForm.category === 'intervention'" class="bg-gray-50 rounded-lg p-4 mb-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
            <input v-model="experienceForm.title" placeholder="Titre / intitulé *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="experienceForm.company" placeholder="Organisateur *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="experienceForm.location" placeholder="Lieu" class="border rounded-lg px-3 py-2 text-sm" />
            <div class="grid grid-cols-2 gap-2">
              <input v-model.number="experienceForm.start_year" type="number" min="1900" :max="maxYear" placeholder="Année *" class="border rounded-lg px-3 py-2 text-sm" />
              <input v-model.number="experienceForm.end_year" type="number" min="1900" :max="maxYear + 10" placeholder="Année de fin (si différente)" class="border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div class="flex items-center gap-4">
              <span class="text-sm text-gray-500">Domaine(s) :</span>
              <label v-for="d in experienceDomains" :key="d.value" class="flex items-center gap-1.5 text-sm cursor-pointer">
                <input type="checkbox" :value="d.value" v-model="experienceForm.domain" class="accent-indigo-600" />
                {{ d.label }}
              </label>
            </div>
          </div>
          <textarea v-model="experienceForm.description" rows="3" placeholder="Description, contexte, public..." class="w-full border rounded-lg px-3 py-2 text-sm mb-3"></textarea>
          <div class="flex justify-end gap-2">
            <button @click="experienceForm.open = false" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
            <button @click="saveExperience" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
              {{ experienceForm.id ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>

        <div v-if="experiencesConf.length === 0 && !(experienceForm.open && experienceForm.category === 'intervention')" class="text-sm text-gray-400 italic text-center py-4">
          Aucune intervention enregistrée
        </div>
        <ul class="space-y-3">
          <li v-for="exp in experiencesConf" :key="exp.id" class="border border-gray-100 rounded-lg p-4 hover:bg-gray-50 transition">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="font-semibold text-gray-900">{{ exp.title }}</span>
                  <span v-for="d in (exp.domain || [])" :key="d" class="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded-full bg-amber-50 text-amber-600">{{ domainLabel(d) }}</span>
                </div>
                <div class="text-sm text-gray-600">{{ exp.company }}<span v-if="exp.location"> · {{ exp.location }}</span></div>
                <div class="text-xs text-gray-400 mt-0.5">{{ formatYearRange(exp.start_year, exp.end_year) }}</div>
                <p v-if="exp.description" class="text-sm text-gray-700 mt-2 whitespace-pre-line">{{ exp.description }}</p>
              </div>
              <div class="flex gap-2 text-xs">
                <button @click="openExperienceForm(exp)" class="text-blue-500 hover:text-blue-700">Modifier</button>
                <button @click="deleteExperience(exp.id)" class="text-red-400 hover:text-red-600">Supprimer</button>
              </div>
            </div>
          </li>
        </ul>
      </section>

      <!-- Publications -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Publications & Médias</h2>
          <button @click="openExperienceForm(null, 'media')" class="text-sm bg-black text-white px-3 py-1.5 rounded-lg hover:bg-gray-800 transition">
            + Ajouter
          </button>
        </div>

        <div v-if="experienceForm.open && experienceForm.category === 'media'" class="bg-gray-50 rounded-lg p-4 mb-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
            <input v-model="experienceForm.title" placeholder="Titre / intitulé *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="experienceForm.company" placeholder="Média / éditeur *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="experienceForm.location" placeholder="Support (web, presse, TV...)" class="border rounded-lg px-3 py-2 text-sm" />
            <div class="grid grid-cols-2 gap-2">
              <input v-model.number="experienceForm.start_year" type="number" min="1900" :max="maxYear" placeholder="Année *" class="border rounded-lg px-3 py-2 text-sm" />
              <input v-model.number="experienceForm.end_year" type="number" min="1900" :max="maxYear + 10" placeholder="Année de fin (si différente)" class="border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div class="flex items-center gap-4">
              <span class="text-sm text-gray-500">Domaine(s) :</span>
              <label v-for="d in experienceDomains" :key="d.value" class="flex items-center gap-1.5 text-sm cursor-pointer">
                <input type="checkbox" :value="d.value" v-model="experienceForm.domain" class="accent-indigo-600" />
                {{ d.label }}
              </label>
            </div>
          </div>
          <textarea v-model="experienceForm.description" rows="3" placeholder="Sujet, contexte, lien..." class="w-full border rounded-lg px-3 py-2 text-sm mb-3"></textarea>
          <div class="flex justify-end gap-2">
            <button @click="experienceForm.open = false" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
            <button @click="saveExperience" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
              {{ experienceForm.id ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>

        <div v-if="experiencesPub.length === 0 && !(experienceForm.open && experienceForm.category === 'media')" class="text-sm text-gray-400 italic text-center py-4">
          Aucune publication enregistrée
        </div>
        <ul class="space-y-3">
          <li v-for="exp in experiencesPub" :key="exp.id" class="border border-gray-100 rounded-lg p-4 hover:bg-gray-50 transition">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="font-semibold text-gray-900">{{ exp.title }}</span>
                  <span v-for="d in (exp.domain || [])" :key="d" class="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded-full bg-amber-50 text-amber-600">{{ domainLabel(d) }}</span>
                </div>
                <div class="text-sm text-gray-600">{{ exp.company }}<span v-if="exp.location"> · {{ exp.location }}</span></div>
                <div class="text-xs text-gray-400 mt-0.5">{{ formatYearRange(exp.start_year, exp.end_year) }}</div>
                <p v-if="exp.description" class="text-sm text-gray-700 mt-2 whitespace-pre-line">{{ exp.description }}</p>
              </div>
              <div class="flex gap-2 text-xs">
                <button @click="openExperienceForm(exp)" class="text-blue-500 hover:text-blue-700">Modifier</button>
                <button @click="deleteExperience(exp.id)" class="text-red-400 hover:text-red-600">Supprimer</button>
              </div>
            </div>
          </li>
        </ul>
      </section>

      <!-- Formations -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Formations & travaux</h2>
          <button @click="openFormationForm()" class="text-sm bg-black text-white px-3 py-1.5 rounded-lg hover:bg-gray-800 transition">
            + Ajouter
          </button>
        </div>

        <div v-if="formationForm.open" class="bg-gray-50 rounded-lg p-4 mb-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
            <input v-model="formationForm.title" placeholder="Intitulé *" class="border rounded-lg px-3 py-2 text-sm" />
            <input v-model="formationForm.institution" placeholder="Établissement / organisme" class="border rounded-lg px-3 py-2 text-sm" />
            <select v-model="formationForm.category" class="border rounded-lg px-3 py-2 text-sm">
              <option v-for="cat in formationCategories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
            </select>
            <input v-model="formationForm.location" placeholder="Lieu" class="border rounded-lg px-3 py-2 text-sm" />
            <div class="grid grid-cols-2 gap-2 col-span-1 md:col-span-2">
              <input v-model.number="formationForm.start_year" type="number" min="1900" :max="maxYear" placeholder="Année de début" class="border rounded-lg px-3 py-2 text-sm" />
              <input v-model.number="formationForm.end_year" type="number" min="1900" :max="maxYear + 10" placeholder="Année de fin" class="border rounded-lg px-3 py-2 text-sm" />
            </div>
          </div>
          <textarea v-model="formationForm.description" rows="3" placeholder="Spécialité, sujet du mémoire, mention..." class="w-full border rounded-lg px-3 py-2 text-sm mb-3"></textarea>
          <div class="flex justify-end gap-2">
            <button @click="formationForm.open = false" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
            <button @click="saveFormation" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
              {{ formationForm.id ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>

        <div v-if="formations.length === 0 && !formationForm.open" class="text-sm text-gray-400 italic text-center py-4">
          Aucune formation enregistrée
        </div>
        <ul class="space-y-3">
          <li v-for="f in formations" :key="f.id" class="border border-gray-100 rounded-lg p-4 hover:bg-gray-50 transition">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <span class="font-semibold text-gray-900">{{ f.title }}</span>
                  <span class="text-[10px] uppercase tracking-wide px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-600">{{ categoryLabel(f.category) }}</span>
                </div>
                <div class="text-sm text-gray-600">{{ f.institution }}<span v-if="f.location"> · {{ f.location }}</span></div>
                <div class="text-xs text-gray-400 mt-0.5">{{ formatYearRange(f.start_year, f.end_year) }}</div>
                <p v-if="f.description" class="text-sm text-gray-700 mt-2 whitespace-pre-line">{{ f.description }}</p>
              </div>
              <div class="flex gap-2 text-xs">
                <button @click="openFormationForm(f)" class="text-blue-500 hover:text-blue-700">Modifier</button>
                <button @click="deleteFormation(f.id)" class="text-red-400 hover:text-red-600">Supprimer</button>
              </div>
            </div>
          </li>
        </ul>
      </section>

      <!-- Compétences -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Compétences</h2>
          <button @click="openSkillForm()" class="text-sm bg-black text-white px-3 py-1.5 rounded-lg hover:bg-gray-800 transition">
            + Ajouter
          </button>
        </div>

        <div v-if="skillForm.open" class="bg-gray-50 rounded-lg p-4 mb-4">
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
            <input v-model="skillForm.name" placeholder="Compétence *" class="border rounded-lg px-3 py-2 text-sm" />
            <select v-model="skillForm.category" class="border rounded-lg px-3 py-2 text-sm">
              <option v-for="cat in skillCategories" :key="cat.value" :value="cat.value">{{ cat.label }}</option>
            </select>
            <input v-model="skillForm.level" type="text" placeholder="Niveau (libre, ex: B2, expert, 5 ans...)" class="border rounded-lg px-3 py-2 text-sm" />
          </div>
          <div class="flex justify-end gap-2">
            <button @click="skillForm.open = false" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
            <button @click="saveSkill" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
              {{ skillForm.id ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>

        <div v-if="skills.length === 0 && !skillForm.open" class="text-sm text-gray-400 italic text-center py-4">
          Aucune compétence enregistrée
        </div>
        <div v-else class="space-y-4">
          <div v-for="group in groupedSkills" :key="group.category">
            <div class="text-xs uppercase tracking-wide text-gray-500 mb-2">{{ categoryLabel(group.category) }}</div>
            <div class="flex flex-wrap gap-2">
              <span
                v-for="skill in group.items"
                :key="skill.id"
                class="inline-flex items-center gap-2 bg-indigo-50 text-indigo-700 text-sm px-3 py-1 rounded-full"
              >
                {{ skill.name }}
                <span v-if="skill.level" class="text-[10px] uppercase tracking-wide text-indigo-400">{{ skill.level }}</span>
                <button @click="openSkillForm(skill)" class="text-indigo-400 hover:text-indigo-700" title="Modifier">✎</button>
                <button @click="deleteSkill(skill.id)" class="text-indigo-400 hover:text-red-500" title="Supprimer">×</button>
              </span>
            </div>
          </div>
        </div>
      </section>

      <!-- Centres d'intérêt -->
      <section class="bg-white rounded-xl shadow-sm p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold text-gray-900">Activités & centres d'intérêt</h2>
          <button @click="openInterestForm()" class="text-sm bg-black text-white px-3 py-1.5 rounded-lg hover:bg-gray-800 transition">
            + Ajouter
          </button>
        </div>

        <div v-if="interestForm.open" class="bg-gray-50 rounded-lg p-4 mb-4">
          <input v-model="interestForm.name" placeholder="Activité / centre d'intérêt *" class="w-full border rounded-lg px-3 py-2 text-sm mb-3" />
          <textarea v-model="interestForm.description" rows="2" placeholder="Description (optionnel)" class="w-full border rounded-lg px-3 py-2 text-sm mb-3"></textarea>
          <div class="flex justify-end gap-2">
            <button @click="interestForm.open = false" class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5">Annuler</button>
            <button @click="saveInterest" class="bg-black text-white text-sm px-3 py-1.5 rounded-lg hover:bg-gray-800">
              {{ interestForm.id ? 'Modifier' : 'Ajouter' }}
            </button>
          </div>
        </div>

        <div v-if="interests.length === 0 && !interestForm.open" class="text-sm text-gray-400 italic text-center py-4">
          Aucun centre d'intérêt enregistré
        </div>
        <ul class="space-y-2">
          <li v-for="int in interests" :key="int.id" class="border border-gray-100 rounded-lg p-3 hover:bg-gray-50 transition flex items-start justify-between gap-4">
            <div class="flex-1">
              <div class="font-medium text-gray-900">{{ int.name }}</div>
              <p v-if="int.description" class="text-sm text-gray-600 mt-0.5">{{ int.description }}</p>
            </div>
            <div class="flex gap-2 text-xs">
              <button @click="openInterestForm(int)" class="text-blue-500 hover:text-blue-700">Modifier</button>
              <button @click="deleteInterest(int.id)" class="text-red-400 hover:text-red-600">Supprimer</button>
            </div>
          </li>
        </ul>
      </section>
    </div>

    <!-- Modal Aperçu & export -->
    <CVPreviewModal
      v-if="showPreview"
      :profile="profile"
      :experiences="experiences"
      :formations="formations"
      :skills="skills"
      :interests="interests"
      :photo-data-url="settings.photo_data_url"
      :pitch="settings.pitch"
      :initial-template="settings.default_template"
      :initial-color="settings.default_color"
      @close="showPreview = false"
      @settings-saved="onSettingsSaved"
    />
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import CVPreviewModal from '../../components/cv/CVPreviewModal.vue'
import { PRO_EXPERIENCE_CATEGORIES } from '../../components/cv/templates/helpers.js'

const { useCrud, get, patch } = useApi()
const experienceCrud = useCrud('cv_experiences')
const formationCrud  = useCrud('cv_formations')
const skillCrud      = useCrud('cv_skills')
const interestCrud   = useCrud('cv_interests')

const profile = ref({})
const experiences = ref([])
const formations = ref([])
const skills = ref([])
const interests = ref([])
const settings = ref({ default_template: 'classic', default_color: 'indigo' })

const showPreview = ref(false)

const experienceCategories = [
  { value: 'emploi',       label: 'Emploi salarié' },
  { value: 'freelance',    label: 'Mission freelance' },
  { value: 'intervention', label: 'Intervention / conférence' },
  { value: 'media',        label: 'Presse & médias' },
  { value: 'associatif',   label: 'Associatif / bénévolat' },
]

const experienceDomains = [
  { value: 'dev',            label: 'Développement' },
  { value: 'droit',          label: 'Droit du travail' },
  { value: 'desinformation', label: 'Désinformation' },
]

const formationCategories = [
  { value: 'diplome',       label: 'Diplôme' },
  { value: 'memoire',       label: 'Mémoire' },
  { value: 'seminaire',     label: 'Séminaire' },
  { value: 'certification', label: 'Certification' },
  { value: 'autre',         label: 'Autre' },
]

const skillCategories = [
  { value: 'informatique', label: 'Informatique' },
  { value: 'langue',       label: 'Langue' },
  { value: 'permis',       label: 'Permis' },
  { value: 'secourisme',   label: 'Secourisme' },
  { value: 'autre',        label: 'Autre' },
]

const categoryLabel = (value) => {
  const all = [...experienceCategories, ...formationCategories, ...skillCategories]
  return all.find(c => c.value === value)?.label || value
}

const domainLabel = (value) => experienceDomains.find(d => d.value === value)?.label || value

// ---- Experience filters ----
const PRO_CATEGORIES = PRO_EXPERIENCE_CATEGORIES
const experiencesProf = computed(() => experiences.value.filter(e => PRO_CATEGORIES.includes(e.category)))
const experiencesConf = computed(() => experiences.value.filter(e => e.category === 'intervention'))
const experiencesPub  = computed(() => experiences.value.filter(e => e.category === 'media'))

// ---- Forms state ----
const emptyExperience = (defaultCategory = null) => ({ open: false, id: null, title: '', company: '', location: '', start_year: null, end_year: null, description: '', category: defaultCategory, domain: [] })
const emptyFormation  = () => ({ open: false, id: null, title: '', institution: '', category: 'diplome', location: '', start_year: null, end_year: null, description: '' })

const maxYear = new Date().getFullYear() + 1
const emptySkill      = () => ({ open: false, id: null, name: '', category: 'informatique', level: '' })
const emptyInterest   = () => ({ open: false, id: null, name: '', description: '' })

const experienceForm = reactive(emptyExperience())
const formationForm  = reactive(emptyFormation())
const skillForm      = reactive(emptySkill())
const interestForm   = reactive(emptyInterest())

const groupedSkills = computed(() => {
  const order = skillCategories.map(c => c.value)
  const groups = {}
  for (const s of skills.value) {
    const key = s.category || 'autre'
    if (!groups[key]) groups[key] = []
    groups[key].push(s)
  }
  return order
    .filter(c => groups[c]?.length)
    .map(c => ({ category: c, items: groups[c] }))
})

// ---- Fetch ----
const fetchAll = async () => {
  const data = await get('/cv/data')
  profile.value = data.profile || {}
  experiences.value = data.experiences || []
  formations.value = data.formations || []
  skills.value = data.skills || []
  interests.value = data.interests || []
  settings.value = data.settings || { default_template: 'classic', default_color: 'indigo' }
  pitchDraft.value = settings.value.pitch || ''
}

// ---- Experience ----
const openExperienceForm = (exp = null, defaultCategory = null) => {
  Object.assign(experienceForm, exp
    ? { open: true, ...exp, domain: exp.domain || [] }
    : { ...emptyExperience(defaultCategory), open: true }
  )
}
const saveExperience = async () => {
  if (!experienceForm.title || !experienceForm.company || !experienceForm.start_year) return
  const payload = { cv_experience: {
    title: experienceForm.title, company: experienceForm.company, location: experienceForm.location || null,
    start_year: experienceForm.start_year, end_year: experienceForm.end_year || null, description: experienceForm.description || null,
    category: experienceForm.category || null, domain: experienceForm.domain,
  }}
  if (experienceForm.id) await experienceCrud.update(experienceForm.id, payload)
  else                   await experienceCrud.create(payload)
  Object.assign(experienceForm, emptyExperience())
  await fetchAll()
}
const deleteExperience = async (id) => {
  if (!confirm('Supprimer cette expérience ?')) return
  await experienceCrud.destroy(id); await fetchAll()
}

// ---- Formation ----
const openFormationForm = (f = null) => {
  Object.assign(formationForm, f ? { open: true, ...f } : { ...emptyFormation(), open: true })
}
const saveFormation = async () => {
  if (!formationForm.title) return
  const payload = { cv_formation: {
    title: formationForm.title, institution: formationForm.institution || null, category: formationForm.category,
    location: formationForm.location || null, start_year: formationForm.start_year || null,
    end_year: formationForm.end_year || null, description: formationForm.description || null,
  }}
  if (formationForm.id) await formationCrud.update(formationForm.id, payload)
  else                   await formationCrud.create(payload)
  Object.assign(formationForm, emptyFormation())
  await fetchAll()
}
const deleteFormation = async (id) => {
  if (!confirm('Supprimer cette formation ?')) return
  await formationCrud.destroy(id); await fetchAll()
}

// ---- Skill ----
const openSkillForm = (s = null) => {
  Object.assign(skillForm, s ? { open: true, ...s, level: s.level || '' } : { ...emptySkill(), open: true })
}
const saveSkill = async () => {
  if (!skillForm.name) return
  const payload = { cv_skill: {
    name: skillForm.name, category: skillForm.category, level: skillForm.level || null,
  }}
  if (skillForm.id) await skillCrud.update(skillForm.id, payload)
  else               await skillCrud.create(payload)
  Object.assign(skillForm, emptySkill())
  await fetchAll()
}
const deleteSkill = async (id) => {
  await skillCrud.destroy(id); await fetchAll()
}

// ---- Interest ----
const openInterestForm = (i = null) => {
  Object.assign(interestForm, i ? { open: true, ...i } : { ...emptyInterest(), open: true })
}
const saveInterest = async () => {
  if (!interestForm.name) return
  const payload = { cv_interest: { name: interestForm.name, description: interestForm.description || null } }
  if (interestForm.id) await interestCrud.update(interestForm.id, payload)
  else                  await interestCrud.create(payload)
  Object.assign(interestForm, emptyInterest())
  await fetchAll()
}
const deleteInterest = async (id) => {
  if (!confirm('Supprimer ce centre d\'intérêt ?')) return
  await interestCrud.destroy(id); await fetchAll()
}

const onSettingsSaved = (newSettings) => {
  settings.value = { ...settings.value, ...newSettings }
  if (newSettings.pitch !== undefined) pitchDraft.value = newSettings.pitch || ''
}

// ---- Pitch ----
const pitchDraft = ref('')
const pitchSaving = ref(false)
const savePitch = async () => {
  if ((pitchDraft.value || '') === (settings.value.pitch || '')) return
  pitchSaving.value = true
  try {
    const data = await patch('/cv_setting', { cv_setting: { pitch: pitchDraft.value || null } })
    settings.value = { ...settings.value, ...data }
  } finally {
    pitchSaving.value = false
  }
}

// ---- Photo upload ----
const photoInput = ref(null)
const photoUploading = ref(false)
const photoError = ref(null)

const csrfToken = () => document.querySelector('meta[name="csrf-token"]')?.content || ''

const onPhotoSelected = async (event) => {
  const file = event.target.files?.[0]
  if (!file) return
  if (file.size > 5 * 1024 * 1024) {
    photoError.value = 'Fichier trop volumineux (max 5 Mo)'
    return
  }
  photoError.value = null
  photoUploading.value = true
  try {
    const formData = new FormData()
    formData.append('cv_setting[photo]', file)
    const response = await fetch('/api/cv_setting', {
      method: 'PATCH',
      credentials: 'same-origin',
      headers: { 'Accept': 'application/json', 'X-CSRF-Token': csrfToken() },
      body: formData,
    })
    if (!response.ok) {
      const data = await response.json().catch(() => ({}))
      throw new Error(data.errors?.join(', ') || `Erreur ${response.status}`)
    }
    const data = await response.json()
    settings.value = { ...settings.value, ...data }
  } catch (e) {
    photoError.value = e.message || 'Erreur upload'
  } finally {
    photoUploading.value = false
    if (photoInput.value) photoInput.value.value = ''
  }
}

const removePhoto = async () => {
  if (!confirm('Supprimer la photo ?')) return
  photoUploading.value = true
  photoError.value = null
  try {
    const response = await fetch('/api/cv_setting/photo', {
      method: 'DELETE',
      credentials: 'same-origin',
      headers: { 'Accept': 'application/json', 'X-CSRF-Token': csrfToken() },
    })
    if (!response.ok) throw new Error(`Erreur ${response.status}`)
    const data = await response.json()
    settings.value = { ...settings.value, ...data }
  } catch (e) {
    photoError.value = e.message || 'Erreur suppression'
  } finally {
    photoUploading.value = false
  }
}

// ---- Helpers ----
const formatYearRange = (start, end) => {
  if (!start && !end) return ''
  const s = start ? String(start) : ''
  const e = end ? String(end) : "Aujourd'hui"
  if (s && end && Number(start) === Number(end)) return s
  return s ? `${s} — ${e}` : e
}

onMounted(fetchAll)
</script>
