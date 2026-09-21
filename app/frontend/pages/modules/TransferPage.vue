<template>
  <div class="min-h-screen bg-gray-50 p-6">
    <div class="max-w-3xl mx-auto">
      <!-- Retour -->
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Transfert de fichiers</h1>
        <p class="text-sm text-gray-500 mt-1">
          Envoyez un fichier, recuperez un lien de partage. Suppression automatique apres {{ defaultRetentionDays }} jours.
        </p>
      </div>

      <!-- Zone d'upload -->
      <div
        class="bg-white rounded-xl shadow-sm p-6 mb-6"
        @dragover.prevent="dragging = true"
        @dragleave.prevent="dragging = false"
        @drop.prevent="onDrop"
      >
        <div
          :class="[
            'border-2 border-dashed rounded-xl p-10 text-center transition-colors cursor-pointer',
            dragging ? 'border-black bg-gray-50' : 'border-gray-200 hover:border-gray-300'
          ]"
          @click="fileInput?.click()"
        >
          <div class="text-4xl mb-3">&#128228;</div>
          <p v-if="!selectedFile" class="text-sm text-gray-500">
            Glissez un fichier ici ou <span class="text-gray-900 font-medium underline">parcourez votre ordinateur</span>
          </p>
          <p v-else class="text-sm text-gray-900 font-medium">
            {{ selectedFile.name }}
            <span class="text-gray-400 font-normal">({{ formatSize(selectedFile.size) }})</span>
          </p>
          <input ref="fileInput" type="file" class="hidden" @change="onFileSelected" />
        </div>

        <div v-if="selectedFile" class="mt-4">
          <input
            v-model="label"
            type="text"
            placeholder="Description (optionnel) : pour qui, pourquoi..."
            class="w-full border rounded-lg px-3 py-2 text-sm mb-3"
            @keyup.enter="startUpload"
          />

          <!-- Progression -->
          <div v-if="uploading" class="mb-3">
            <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
              <div class="h-full bg-black transition-all duration-200" :style="{ width: progress + '%' }"></div>
            </div>
            <p class="text-xs text-gray-400 mt-1">Envoi en cours... {{ progress }} %</p>
          </div>

          <div class="flex justify-end gap-2">
            <button
              :disabled="uploading"
              class="text-sm text-gray-500 hover:text-gray-700 px-4 py-2 disabled:opacity-40"
              @click="resetSelection"
            >
              Annuler
            </button>
            <button
              :disabled="uploading"
              class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition disabled:opacity-40"
              @click="startUpload"
            >
              {{ uploading ? 'Envoi...' : 'Envoyer' }}
            </button>
          </div>
        </div>

        <p v-if="uploadError" class="text-sm text-red-500 mt-3">{{ uploadError }}</p>
      </div>

      <!-- Dernier lien genere -->
      <div v-if="lastTransfer" class="bg-green-50 border-2 border-green-200 rounded-xl p-5 mb-6">
        <p class="text-sm font-medium text-green-900 mb-2">Lien pret a etre partage</p>
        <div class="flex items-center gap-2">
          <input
            :value="lastTransfer.share_url"
            readonly
            class="flex-1 bg-white border rounded-lg px-3 py-2 text-sm font-mono text-gray-700"
            @focus="$event.target.select()"
          />
          <button
            class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition whitespace-nowrap"
            @click="copyLink(lastTransfer)"
          >
            {{ copiedId === lastTransfer.id ? 'Copie !' : 'Copier' }}
          </button>
        </div>
      </div>

      <!-- Liste des transferts -->
      <h2 class="text-lg font-semibold text-gray-900 mb-3">Transferts en cours</h2>

      <div v-if="transfers.length === 0" class="text-center text-gray-400 py-12 bg-white rounded-xl shadow-sm">
        Aucun fichier partage
      </div>

      <div v-else class="space-y-3">
        <div
          v-for="transfer in transfers"
          :key="transfer.id"
          :class="[
            'bg-white rounded-xl shadow-sm p-5',
            transfer.expired ? 'opacity-50' : ''
          ]"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="min-w-0">
              <h3 class="font-medium text-gray-900 truncate">{{ transfer.file_name }}</h3>
              <p class="text-xs text-gray-400 mt-1">
                {{ formatSize(transfer.file_size) }}
                <span v-if="transfer.label"> &middot; {{ transfer.label }}</span>
              </p>
              <p class="text-xs mt-2">
                <span :class="transfer.expired ? 'text-red-400' : 'text-gray-500'">
                  {{ expiryLabel(transfer) }}
                </span>
                <span class="text-gray-300"> &middot; </span>
                <span class="text-gray-500">{{ downloadLabel(transfer) }}</span>
              </p>
            </div>

            <div class="flex gap-2 flex-shrink-0">
              <button
                v-if="!transfer.expired"
                class="text-xs border rounded-lg px-3 py-1.5 text-gray-600 hover:bg-gray-50 transition"
                @click="copyLink(transfer)"
              >
                {{ copiedId === transfer.id ? 'Copie !' : 'Copier le lien' }}
              </button>
              <button
                class="text-xs text-red-400 hover:text-red-600 px-2 py-1.5"
                @click="revoke(transfer)"
              >
                Revoquer
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useApi } from '../../composables/useApi'
import { useDirectUpload } from '../../composables/useDirectUpload'

const { useCrud } = useApi()
const { list, create, destroy } = useCrud('file_transfers')
const { uploadFile } = useDirectUpload()

const defaultRetentionDays = 3

const transfers = ref([])
const selectedFile = ref(null)
const label = ref('')
const fileInput = ref(null)
const dragging = ref(false)
const uploading = ref(false)
const progress = ref(0)
const uploadError = ref('')
const lastTransfer = ref(null)
const copiedId = ref(null)

const fetchTransfers = async () => {
  transfers.value = await list()
}

const onFileSelected = (event) => {
  const file = event.target.files?.[0]
  if (file) selectFile(file)
}

const onDrop = (event) => {
  dragging.value = false
  const file = event.dataTransfer?.files?.[0]
  if (file) selectFile(file)
}

const selectFile = (file) => {
  selectedFile.value = file
  uploadError.value = ''
  lastTransfer.value = null
}

const resetSelection = () => {
  selectedFile.value = null
  label.value = ''
  progress.value = 0
  uploadError.value = ''
  if (fileInput.value) fileInput.value.value = ''
}

const startUpload = async () => {
  if (!selectedFile.value || uploading.value) return

  uploading.value = true
  progress.value = 0
  uploadError.value = ''

  try {
    const blob = await uploadFile(selectedFile.value, (percent) => {
      progress.value = percent
    })

    const transfer = await create({ file: blob.signed_id, label: label.value })
    lastTransfer.value = transfer
    resetSelection()
    await fetchTransfers()
    copyLink(transfer)
  } catch (error) {
    uploadError.value = "L'envoi a echoue. Verifiez votre connexion et reessayez."
    console.error('Upload error:', error)
  } finally {
    uploading.value = false
  }
}

const revoke = async (transfer) => {
  if (!confirm(`Revoquer le lien de "${transfer.file_name}" ? Le fichier sera supprime.`)) return

  await destroy(transfer.id)
  if (lastTransfer.value?.id === transfer.id) lastTransfer.value = null
  await fetchTransfers()
}

const copyLink = async (transfer) => {
  try {
    await navigator.clipboard.writeText(transfer.share_url)
    copiedId.value = transfer.id
    setTimeout(() => {
      if (copiedId.value === transfer.id) copiedId.value = null
    }, 2000)
  } catch {
    // Presse-papier indisponible (contexte non securise) : l'utilisateur copiera a la main
  }
}

const formatSize = (bytes) => {
  if (!bytes) return '0 o'
  const units = ['o', 'Ko', 'Mo', 'Go']
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1)
  return `${(bytes / Math.pow(1024, i)).toFixed(i === 0 ? 0 : 1)} ${units[i]}`
}

const expiryLabel = (transfer) => {
  if (transfer.expired) return 'Expire'

  const remainingMs = new Date(transfer.expires_at) - new Date()
  const hours = Math.floor(remainingMs / 3600000)
  if (hours >= 24) {
    const days = Math.floor(hours / 24)
    return `Expire dans ${days} jour${days > 1 ? 's' : ''}`
  }
  if (hours >= 1) return `Expire dans ${hours} h`
  return 'Expire dans moins d\'une heure'
}

const downloadLabel = (transfer) => {
  if (!transfer.download_count) return 'Jamais telecharge'
  return `${transfer.download_count} telechargement${transfer.download_count > 1 ? 's' : ''}`
}

onMounted(fetchTransfers)
</script>
