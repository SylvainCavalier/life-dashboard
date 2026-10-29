<template>
  <!-- 1. Choix du fichier, envoi, analyse -->
  <div v-if="step !== 'review'" class="bg-white rounded-xl shadow-sm p-6">
    <div class="flex items-start justify-between gap-4 mb-4">
      <div>
        <h2 class="text-lg font-semibold">Importer un contrat</h2>
        <p class="text-sm text-gray-500">Déposez le PDF du contrat (conditions particulières de préférence) ou une photo : Mistral en extrait la fiche, les garanties et ce qui est assuré. Vous relisez avant que rien ne soit enregistré.</p>
      </div>
      <button @click="cancel" class="text-sm text-gray-500 hover:text-gray-700 flex-shrink-0">Annuler</button>
    </div>

    <label
      v-if="step === 'choose'"
      class="block border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition"
      :class="dragging ? 'border-blue-400 bg-blue-50' : 'border-gray-300 hover:border-gray-400'"
      @dragover.prevent="dragging = true"
      @dragleave.prevent="dragging = false"
      @drop.prevent="onDrop"
    >
      <input type="file" accept="application/pdf,image/jpeg,image/png,image/webp" class="hidden" @change="onFileSelected" />
      <span class="block text-sm font-medium text-gray-700">Choisir ou glisser un fichier</span>
      <span class="block text-xs text-gray-400 mt-1">PDF, JPEG, PNG ou WebP, 45 Mo max</span>
    </label>

    <div v-else-if="step === 'upload' || step === 'analyze'" class="py-6 text-center">
      <p class="text-sm text-gray-700 font-medium">{{ fileName }}</p>
      <template v-if="step === 'upload'">
        <div class="w-full max-w-sm mx-auto bg-gray-100 rounded-full h-2 mt-3">
          <div class="bg-blue-500 h-2 rounded-full transition-all" :style="{ width: progress + '%' }"></div>
        </div>
        <p class="text-xs text-gray-400 mt-2">Envoi du fichier... {{ progress }} %</p>
      </template>
      <template v-else>
        <div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin mx-auto mt-3"></div>
        <p class="text-xs text-gray-400 mt-2">Lecture du contrat par Mistral (jusqu'à une minute pour un long document ou un scan)...</p>
      </template>
    </div>

    <div v-else-if="step === 'failed'" class="py-4">
      <p class="text-sm text-red-600 mb-3">{{ error }}</p>
      <button @click="reset" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition">Essayer un autre fichier</button>
    </div>
  </div>

  <!-- 2. Relecture : formulaire pre-rempli, garanties et biens extraits -->
  <InsuranceForm
    v-else
    :key="importId"
    :initial="draft.insurance"
    title="Vérifier le contrat importé"
    submit-label="Créer l'assurance"
    :saving="saving"
    :errors="errors"
    @submit="confirm"
    @cancel="cancel"
  >
    <template #intro>
      <p class="text-sm text-blue-800 bg-blue-50 rounded-lg px-3 py-2 mb-4">
        Extrait de « {{ fileName }} ». Relisez et corrigez : les champs vides ne figuraient pas dans le document. Le fichier sera rangé dans les documents du contrat.
      </p>
    </template>

    <!-- Garanties -->
    <div>
      <h3 class="text-sm font-medium text-gray-700 mb-2">Garanties trouvées ({{ keptCoverages.length }}/{{ coverages.length }} retenues)</h3>
      <p v-if="!coverages.length" class="text-sm text-gray-400">Aucune garantie détaillée dans ce document : vous pourrez les ajouter depuis la fiche.</p>
      <ul class="space-y-2">
        <li v-for="(coverage, index) in coverages" :key="index" class="border rounded-lg p-3" :class="coverage.keep ? 'bg-white' : 'bg-gray-50 opacity-60'">
          <div class="flex items-center gap-3 mb-2">
            <input v-model="coverage.keep" type="checkbox" class="rounded" title="Retenir cette garantie" />
            <input v-model="coverage.name" type="text" class="flex-1 border rounded-lg px-2 py-1 text-sm font-medium" />
            <select v-model="coverage.included" class="border rounded-lg px-2 py-1 text-sm">
              <option :value="true">Couverte</option>
              <option :value="false">Non couverte</option>
            </select>
          </div>
          <div v-if="coverage.keep" class="grid grid-cols-1 sm:grid-cols-2 gap-2 pl-7">
            <input v-model="coverage.ceiling" type="text" placeholder="Plafond" class="border rounded-lg px-2 py-1 text-xs" />
            <input v-model="coverage.deductible" type="text" placeholder="Franchise" class="border rounded-lg px-2 py-1 text-xs" />
            <textarea v-model="coverage.conditions" rows="2" placeholder="Conditions et exclusions" class="sm:col-span-2 border rounded-lg px-2 py-1 text-xs"></textarea>
          </div>
        </li>
      </ul>
    </div>

    <!-- Biens assures -->
    <div>
      <h3 class="text-sm font-medium text-gray-700 mb-2">Ce qui est assuré ({{ keptItems.length }}/{{ items.length }} retenus)</h3>
      <p v-if="!items.length" class="text-sm text-gray-400">Rien trouvé : vous pourrez l'ajouter depuis la fiche.</p>
      <ul class="space-y-2">
        <li v-for="(item, index) in items" :key="index" class="border rounded-lg p-3" :class="item.keep ? 'bg-white' : 'bg-gray-50 opacity-60'">
          <div class="flex flex-wrap items-center gap-3">
            <input v-model="item.keep" type="checkbox" class="rounded" title="Retenir" />
            <select v-model="item.kind" class="border rounded-lg px-2 py-1 text-sm">
              <option v-for="k in itemKinds" :key="k.value" :value="k.value">{{ k.label }}</option>
            </select>
            <input v-model="item.name" type="text" class="flex-1 min-w-[160px] border rounded-lg px-2 py-1 text-sm font-medium" />
            <select v-if="item.kind === 'logement'" v-model="item.property_id" class="border rounded-lg px-2 py-1 text-sm" title="Bien de la page Immobilier">
              <option :value="null">-- Bien non lié --</option>
              <option v-for="p in properties" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
            <select v-if="item.kind === 'vehicule'" v-model="item.vehicle_id" class="border rounded-lg px-2 py-1 text-sm" title="Véhicule de la page Véhicules">
              <option :value="null">-- Véhicule non lié --</option>
              <option v-for="v in vehicles" :key="v.id" :value="v.id">{{ v.name }}</option>
            </select>
          </div>
          <p v-if="item.keep && (item.description || item.value)" class="text-xs text-gray-500 mt-1 pl-7">
            {{ item.description }}<template v-if="item.value"> · valeur {{ formatEuros(item.value) }}</template>
          </p>
        </li>
      </ul>
    </div>

    <!-- Document -->
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
      <div class="sm:col-span-2">
        <label class="block text-sm font-medium text-gray-700 mb-1">Nom du document</label>
        <input v-model="documentForm.name" type="text" class="w-full border rounded-lg px-3 py-2 text-sm" />
      </div>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">Catégorie</label>
        <select v-model="documentForm.category" class="w-full border rounded-lg px-3 py-2 text-sm">
          <option v-for="c in insuranceDocCategories" :key="c.value" :value="c.value">{{ c.label }}</option>
        </select>
      </div>
    </div>
  </InsuranceForm>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount } from 'vue'
import { useApi } from '../../composables/useApi'
import { useDirectUpload } from '../../composables/useDirectUpload'
import { itemKinds, insuranceDocCategories, formatEuros } from '../../composables/useInsurances'
import InsuranceForm from './InsuranceForm.vue'

const emit = defineEmits(['created', 'cancel'])

const { get, post, delete: del } = useApi()
const { uploadFile } = useDirectUpload()

const ACCEPTED = ['application/pdf', 'image/jpeg', 'image/png', 'image/webp']
const POLL_MS = 2000

// choose -> upload -> analyze -> review (ou failed)
const step = ref('choose')
const dragging = ref(false)
const fileName = ref('')
const progress = ref(0)
const error = ref('')
const importId = ref(null)
const draft = ref(null)
const coverages = ref([])
const items = ref([])
const documentForm = reactive({ name: '', category: 'other' })
const properties = ref([])
const vehicles = ref([])
const saving = ref(false)
const errors = ref([])
let pollTimer = null

const keptCoverages = computed(() => coverages.value.filter(c => c.keep && c.name.trim()))
const keptItems = computed(() => items.value.filter(i => i.keep && i.name.trim()))

const onFileSelected = (event) => start(event.target.files[0])
const onDrop = (event) => {
  dragging.value = false
  start(event.dataTransfer.files[0])
}

const fail = (message) => {
  error.value = message
  step.value = 'failed'
}

const start = async (file) => {
  if (!file) return
  if (!ACCEPTED.includes(file.type)) return fail('Format non pris en charge : PDF, JPEG, PNG ou WebP.')
  fileName.value = file.name
  progress.value = 0
  step.value = 'upload'
  try {
    const blob = await uploadFile(file, (percent) => { progress.value = percent })
    step.value = 'analyze'
    const created = await post('/insurance_imports', { file: blob.signed_id })
    importId.value = created.id
    poll()
  } catch (e) {
    fail(e.response?.data?.errors?.join(', ') || "L'envoi du fichier a échoué")
  }
}

const poll = async () => {
  try {
    const data = await get(`/insurance_imports/${importId.value}`)
    if (data.in_progress) {
      pollTimer = setTimeout(poll, POLL_MS)
    } else if (data.status === 'done') {
      openReview(data.draft)
    } else {
      fail(data.error || "L'extraction a échoué")
    }
  } catch {
    fail('Import introuvable')
  }
}

const openReview = (data) => {
  draft.value = data
  coverages.value = data.coverages.map(c => ({ ...c, keep: true }))
  items.value = data.items.map(i => ({ ...i, keep: true }))
  Object.assign(documentForm, data.document)
  step.value = 'review'
}

const pick = (entry, keys) => Object.fromEntries(keys.map(key => [key, entry[key]]))

const confirm = async (insurance) => {
  saving.value = true
  errors.value = []
  try {
    const created = await post(`/insurance_imports/${importId.value}/confirm`, {
      insurance,
      coverages: keptCoverages.value.map(c => pick(c, ['name', 'included', 'ceiling', 'deductible', 'conditions'])),
      items: keptItems.value.map(i => pick(i, ['name', 'kind', 'description', 'value', 'property_id', 'vehicle_id'])),
      document: { ...documentForm },
    })
    importId.value = null
    emit('created', created)
  } catch (e) {
    errors.value = e.response?.data?.errors || ['Enregistrement impossible']
  } finally {
    saving.value = false
  }
}

// Abandon : l'import et son fichier sont supprimes.
const discard = async () => {
  clearTimeout(pollTimer)
  if (importId.value) {
    try {
      await del(`/insurance_imports/${importId.value}`)
    } catch {
      // deja supprime ou purge : rien a faire
    }
  }
  importId.value = null
}

const reset = async () => {
  await discard()
  error.value = ''
  step.value = 'choose'
}

const cancel = async () => {
  await discard()
  emit('cancel')
}

onMounted(async () => {
  try {
    properties.value = await get('/properties') || []
  } catch {
    properties.value = []
  }
  try {
    vehicles.value = await get('/vehicles') || []
  } catch {
    vehicles.value = []
  }
})

onBeforeUnmount(() => clearTimeout(pollTimer))
</script>
