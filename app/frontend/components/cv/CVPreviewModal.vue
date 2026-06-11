<template>
  <div class="fixed inset-0 z-50 flex" role="dialog" aria-modal="true">
    <!-- Backdrop -->
    <div class="absolute inset-0 bg-black/50" @click="$emit('close')"></div>

    <!-- Panel -->
    <div class="relative z-10 w-full h-full flex flex-col md:flex-row bg-gray-100">
      <!-- Sidebar controls -->
      <aside class="w-full md:w-80 bg-white border-r border-gray-200 overflow-y-auto p-5 flex flex-col gap-5 shadow-sm">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold">Aperçu CV</h2>
          <button @click="$emit('close')" class="text-gray-400 hover:text-gray-700 text-xl leading-none">×</button>
        </div>

        <!-- Template picker -->
        <div>
          <div class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Template</div>
          <div class="grid grid-cols-2 gap-2">
            <button
              v-for="t in templates" :key="t.value"
              @click="template = t.value"
              class="text-sm px-3 py-2 rounded-lg border transition"
              :class="template === t.value ? 'bg-indigo-50 border-indigo-500 text-indigo-700 font-medium' : 'bg-white border-gray-200 text-gray-700 hover:border-gray-300'"
            >
              {{ t.label }}
            </button>
          </div>
        </div>

        <!-- Color picker -->
        <div>
          <div class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Couleur d'accent</div>
          <div class="flex gap-2">
            <button
              v-for="c in colors" :key="c.value"
              @click="accentColor = c.value"
              :title="c.label"
              class="w-8 h-8 rounded-full border-2 transition"
              :class="accentColor === c.value ? 'border-gray-900' : 'border-gray-200 hover:border-gray-400'"
              :style="{ backgroundColor: c.hex }"
            ></button>
          </div>
        </div>

        <!-- Interests placement -->
        <div>
          <div class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Centres d'intérêt</div>
          <div class="grid grid-cols-2 gap-2">
            <button
              @click="interestsDetailed = false"
              class="text-xs px-2 py-2 rounded-lg border transition"
              :class="!interestsDetailed ? 'bg-indigo-50 border-indigo-500 text-indigo-700 font-medium' : 'bg-white border-gray-200 text-gray-700 hover:border-gray-300'"
              title="Sidebar / bas de page, en tags"
            >
              Aperçu rapide
            </button>
            <button
              @click="interestsDetailed = true"
              class="text-xs px-2 py-2 rounded-lg border transition"
              :class="interestsDetailed ? 'bg-indigo-50 border-indigo-500 text-indigo-700 font-medium' : 'bg-white border-gray-200 text-gray-700 hover:border-gray-300'"
              title="Colonne principale, avec descriptions"
            >
              Détaillé
            </button>
          </div>
        </div>

        <!-- Entries selection -->
        <div class="flex-1 overflow-y-auto">
          <div class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Éléments à afficher</div>
          <div v-for="section in sections" :key="section.key" class="mb-3">
            <label class="flex items-center gap-2 text-sm font-medium text-gray-800 mb-1">
              <input type="checkbox" :checked="isSectionFullyChecked(section.key)" :indeterminate.prop="isSectionPartiallyChecked(section.key)" @change="toggleSection(section.key, $event.target.checked)" />
              {{ section.label }}
              <span class="text-xs text-gray-400">({{ section.items.length }})</span>
            </label>
            <div class="pl-6 space-y-1">
              <label v-for="item in section.items" :key="item.id" class="flex items-start gap-2 text-xs text-gray-600 cursor-pointer hover:text-gray-900">
                <input type="checkbox" class="mt-0.5" v-model="selectedIds[section.key]" :value="item.id" />
                <span>{{ labelFor(section.key, item) }}</span>
              </label>
              <div v-if="section.items.length === 0" class="text-xs text-gray-400 italic">Aucune entrée</div>
            </div>
          </div>
        </div>

        <!-- Warning pages -->
        <div v-if="overflowWarning" class="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-lg p-2">
          ⚠ Le contenu dépasse 2 pages. Décoche certains éléments pour ajuster.
        </div>

        <!-- Actions -->
        <div class="border-t pt-4 space-y-2">
          <button
            @click="exportPdf"
            :disabled="exporting"
            class="w-full bg-indigo-600 text-white text-sm px-4 py-2.5 rounded-lg hover:bg-indigo-700 transition disabled:opacity-50 font-medium"
          >
            <span v-if="exporting">Génération en cours...</span>
            <span v-else>💾 Exporter en PDF</span>
          </button>
          <div v-if="exportError" class="text-xs text-red-600 bg-red-50 border border-red-200 rounded p-2">{{ exportError }}</div>
        </div>
      </aside>

      <!-- Preview area -->
      <div class="flex-1 overflow-auto p-6 bg-gray-300">
        <div class="cv-preview-viewport mx-auto" :style="{ width: '210mm' }">
          <!-- Content (flowing, spans both pages) -->
          <div ref="previewWrap" class="cv-preview-content">
            <component
              :is="currentTemplateComponent"
              :profile="profile"
              :experiences="filteredExperiences"
              :formations="filteredFormations"
              :skills="filteredSkills"
              :interests="filteredInterests"
              :photo-data-url="photoDataUrl"
              :pitch="pitch"
              :accent-color="accentColor"
              :interests-detailed="interestsDetailed"
            />
          </div>

          <!-- Page overlay (separator lines + labels) -->
          <div class="cv-preview-overlay" aria-hidden="true">
            <div class="cv-page-label cv-page-label-1">Page 1</div>
            <div class="cv-page-break"></div>
            <div class="cv-page-label cv-page-label-2">Page 2</div>
            <div class="cv-page-break cv-page-break-limit"></div>
            <div class="cv-page-label cv-page-label-overflow">⚠ Hors CV (> 2 pages)</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, nextTick } from 'vue'
import ClassicTemplate from './templates/ClassicTemplate.vue'
import ModernTemplate from './templates/ModernTemplate.vue'
import cvPrintCss from './cv-print.css?raw'
import './cv-print.css'
import { useApi } from '../../composables/useApi'

const props = defineProps({
  profile: { type: Object, default: () => ({}) },
  experiences: { type: Array, default: () => [] },
  formations: { type: Array, default: () => [] },
  skills: { type: Array, default: () => [] },
  interests: { type: Array, default: () => [] },
  photoDataUrl: { type: String, default: null },
  pitch: { type: String, default: null },
  initialTemplate: { type: String, default: 'classic' },
  initialColor: { type: String, default: 'indigo' },
})

const emit = defineEmits(['close', 'settings-saved'])

const { post, patch } = useApi()

const templates = [
  { value: 'classic', label: 'Classique' },
  { value: 'modern',  label: 'Moderne' },
]
const colors = [
  { value: 'indigo',   label: 'Indigo',   hex: '#4f46e5' },
  { value: 'slate',    label: 'Ardoise',  hex: '#475569' },
  { value: 'emerald',  label: 'Émeraude', hex: '#059669' },
  { value: 'bordeaux', label: 'Bordeaux', hex: '#9f1239' },
]

const template = ref(props.initialTemplate || 'classic')
const accentColor = ref(props.initialColor || 'indigo')
const interestsDetailed = ref(false)

const selectedIds = ref({
  experiences: props.experiences.map(e => e.id),
  formations:  props.formations.map(f => f.id),
  skills:      props.skills.map(s => s.id),
  interests:   props.interests.map(i => i.id),
})

const sections = computed(() => [
  { key: 'experiences', label: 'Expériences',   items: props.experiences },
  { key: 'formations',  label: 'Formations',    items: props.formations },
  { key: 'skills',      label: 'Compétences',   items: props.skills },
  { key: 'interests',   label: 'Centres d\'intérêt', items: props.interests },
])

const labelFor = (key, item) => {
  if (key === 'experiences') return `${item.title} — ${item.company}`
  if (key === 'formations')  return `${item.title}${item.institution ? ' — ' + item.institution : ''}`
  if (key === 'skills')      return `${item.name}${item.level ? ' (' + item.level + ')' : ''}`
  return item.name
}

const isSectionFullyChecked = (key) => {
  const items = sections.value.find(s => s.key === key).items
  if (items.length === 0) return false
  return selectedIds.value[key].length === items.length
}
const isSectionPartiallyChecked = (key) => {
  const selected = selectedIds.value[key].length
  const total = sections.value.find(s => s.key === key).items.length
  return selected > 0 && selected < total
}
const toggleSection = (key, checked) => {
  const items = sections.value.find(s => s.key === key).items
  selectedIds.value[key] = checked ? items.map(i => i.id) : []
}

const filterBy = (items, key) => items.filter(i => selectedIds.value[key].includes(i.id))
const filteredExperiences = computed(() => filterBy(props.experiences, 'experiences'))
const filteredFormations  = computed(() => filterBy(props.formations,  'formations'))
const filteredSkills      = computed(() => filterBy(props.skills,      'skills'))
const filteredInterests   = computed(() => filterBy(props.interests,   'interests'))

const currentTemplateComponent = computed(() => template.value === 'modern' ? ModernTemplate : ClassicTemplate)

// Overflow detection (approximation — 2 pages = 594mm content height)
const previewWrap = ref(null)
const overflowWarning = ref(false)
const checkOverflow = async () => {
  await nextTick()
  if (!previewWrap.value) return
  const px2mm = (px) => px * 0.2646
  const heightMm = px2mm(previewWrap.value.scrollHeight)
  overflowWarning.value = heightMm > 594 // 2 x A4 height
}
watch([template, accentColor, interestsDetailed, selectedIds, () => props.experiences, () => props.formations], checkOverflow, { deep: true })
onMounted(checkOverflow)

// Persist settings
let settingsSaveTimer = null
watch([template, accentColor], async ([newTemplate, newColor]) => {
  clearTimeout(settingsSaveTimer)
  settingsSaveTimer = setTimeout(async () => {
    try {
      await patch('/cv_setting', { cv_setting: { default_template: newTemplate, default_color: newColor } })
      emit('settings-saved', { default_template: newTemplate, default_color: newColor })
    } catch (_) { /* non-blocking */ }
  }, 600)
})

// ---- PDF export ----
const exporting = ref(false)
const exportError = ref(null)

const exportPdf = async () => {
  if (!previewWrap.value) return
  exporting.value = true
  exportError.value = null
  try {
    const cvHtml = previewWrap.value.innerHTML
    const fullHtml = `<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="utf-8"/>
<title>CV</title>
<style>${cvPrintCss}</style>
</head>
<body>${cvHtml}</body>
</html>`

    const response = await fetch('/api/cv/export_pdf', {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/pdf',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
      },
      body: JSON.stringify({ html: fullHtml }),
    })

    if (!response.ok) {
      const text = await response.text()
      throw new Error(text || `Erreur ${response.status}`)
    }

    const blob = await response.blob()
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `cv-${new Date().toISOString().slice(0, 10)}.pdf`
    document.body.appendChild(a)
    a.click()
    a.remove()
    URL.revokeObjectURL(url)
  } catch (e) {
    exportError.value = e.message || 'Erreur lors de l\'export PDF'
  } finally {
    exporting.value = false
  }
}
</script>
