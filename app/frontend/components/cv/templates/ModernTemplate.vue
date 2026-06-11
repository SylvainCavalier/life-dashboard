<template>
  <div class="cv-root cv-modern" :data-color="accentColor">
    <aside class="cv-sidebar">
      <img v-if="photoDataUrl" :src="photoDataUrl" alt="" class="cv-photo cv-photo-centered" />
      <h1 class="cv-name">{{ profile.full_name || '—' }}</h1>
      <p v-if="profile.occupation" class="cv-occupation">{{ profile.occupation }}</p>

      <h2 class="cv-section-title">Contact</h2>
      <div class="cv-contact">
        <span v-if="profile.age" class="cv-contact-item">{{ profile.age }} ans</span>
        <span v-if="profile.email" class="cv-contact-item">{{ profile.email }}</span>
        <span v-if="profile.mobile_phone || profile.phone" class="cv-contact-item">{{ profile.mobile_phone || profile.phone }}</span>
        <span v-if="profile.full_address" class="cv-contact-item">{{ profile.full_address }}</span>
      </div>

      <template v-if="groupedSkills.length">
        <h2 class="cv-section-title">Compétences</h2>
        <div v-for="group in groupedSkills" :key="group.category" class="cv-skill-group">
          <div class="cv-skill-group-label">{{ categoryLabel(group.category) }}</div>
          <div class="cv-skill-tags">
            <span v-for="s in group.items" :key="s.id" class="cv-skill-tag">
              {{ s.name }}<span v-if="s.level" class="lvl">{{ s.level }}</span>
            </span>
          </div>
        </div>
      </template>

      <template v-if="interests.length && !interestsDetailed">
        <h2 class="cv-section-title">Centres d'intérêt</h2>
        <div class="cv-interests-list">
          <span v-for="i in interests" :key="i.id" class="cv-interest">{{ i.name }}</span>
        </div>
      </template>
    </aside>

    <main class="cv-main">
      <p v-if="pitch" class="cv-pitch">{{ pitch }}</p>

      <section v-if="experiences.length">
        <h2 class="cv-section-title">Expériences professionnelles</h2>
        <div v-for="exp in experiences" :key="exp.id" class="cv-entry">
          <div class="cv-entry-title">{{ exp.title }} — {{ exp.company }}</div>
          <div class="cv-entry-meta" v-if="exp.location">{{ exp.location }}</div>
          <div class="cv-entry-dates">{{ formatYearRange(exp.start_year, exp.end_year) }}</div>
          <div v-if="exp.description" class="cv-entry-desc">{{ exp.description }}</div>
        </div>
      </section>

      <section v-if="formations.length">
        <h2 class="cv-section-title">Formations &amp; travaux</h2>
        <div v-for="f in formations" :key="f.id" class="cv-entry">
          <div class="cv-entry-title">{{ f.title }}<span v-if="f.institution"> — {{ f.institution }}</span></div>
          <div class="cv-entry-meta">
            {{ categoryLabel(f.category) }}<span v-if="f.location"> · {{ f.location }}</span>
          </div>
          <div class="cv-entry-dates" v-if="f.start_year || f.end_year">{{ formatYearRange(f.start_year, f.end_year) }}</div>
          <div v-if="f.description" class="cv-entry-desc">{{ f.description }}</div>
        </div>
      </section>

      <section v-if="interests.length && interestsDetailed">
        <h2 class="cv-section-title">Centres d'intérêt</h2>
        <div v-for="i in interests" :key="i.id" class="cv-entry">
          <div class="cv-entry-title">{{ i.name }}</div>
          <div v-if="i.description" class="cv-entry-desc">{{ i.description }}</div>
        </div>
      </section>
    </main>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { formatYearRange, categoryLabel, groupSkillsByCategory } from './helpers.js'

const props = defineProps({
  profile: { type: Object, default: () => ({}) },
  experiences: { type: Array, default: () => [] },
  formations: { type: Array, default: () => [] },
  skills: { type: Array, default: () => [] },
  interests: { type: Array, default: () => [] },
  photoDataUrl: { type: String, default: null },
  pitch: { type: String, default: null },
  accentColor: { type: String, default: 'indigo' },
  interestsDetailed: { type: Boolean, default: false },
})

const groupedSkills = computed(() => groupSkillsByCategory(props.skills))
</script>
