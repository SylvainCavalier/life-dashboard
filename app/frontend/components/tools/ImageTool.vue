<template>
  <div>
    <FileDropZone
      v-if="!source"
      accept="image/*"
      icon="🖼️"
      label="Cliquez ou glissez une image ici"
      hint="JPG, PNG, WebP... Recadrage, redimensionnement, conversion, fond transparent"
      @file="loadFile"
    />

    <template v-else>
      <div class="bg-white rounded-xl shadow-sm p-4 mb-4 flex flex-wrap items-center gap-4">
        <div class="min-w-0 flex-1">
          <p class="font-semibold text-gray-900 truncate">{{ source.name }}</p>
          <p class="text-xs text-gray-400">{{ source.width }} × {{ source.height }} px · {{ humanSize(source.size) }}</p>
        </div>
        <button
          @click="source = null"
          class="text-sm px-3 py-2 rounded-lg border border-gray-200 text-gray-700 hover:bg-gray-50"
        >
          Autre image
        </button>
      </div>

      <div class="flex flex-wrap gap-2 mb-4">
        <button
          v-for="tool in TOOLS"
          :key="tool.key"
          @click="activeTool = tool.key"
          class="text-sm px-4 py-2 rounded-lg transition-colors"
          :class="activeTool === tool.key ? 'bg-gray-900 text-white' : 'bg-white text-gray-600 shadow-sm hover:bg-gray-100'"
        >
          <span class="mr-1">{{ tool.icon }}</span>{{ tool.label }}
        </button>
      </div>

      <!-- Recree a chaque nouvelle image (cle = id) -->
      <component
        :is="currentTool.component"
        :key="`${activeTool}-${source.id}`"
        :source="source"
        @replace="replaceSource"
      />
    </template>

    <div v-if="error" class="bg-red-50 text-red-700 text-sm rounded-lg px-4 py-3 mt-4">{{ error }}</div>
  </div>
</template>

<script setup>
import { ref, shallowRef, computed } from 'vue'
import FileDropZone from './FileDropZone.vue'
import ImageCrop from './image/ImageCrop.vue'
import ImageTransparency from './image/ImageTransparency.vue'
import { loadImageSource } from './image/imageSource'
import { humanSize } from './files'

const TOOLS = [
  { key: 'crop', label: 'Recadrer et redimensionner', icon: '✂️', component: ImageCrop },
  { key: 'transparency', label: 'Fond transparent', icon: '🪄', component: ImageTransparency },
]

const source = shallowRef(null)
const activeTool = ref('crop')
const error = ref(null)

const currentTool = computed(() => TOOLS.find(t => t.key === activeTool.value))

const loadFile = async (file) => {
  error.value = null
  try {
    source.value = await loadImageSource(file)
  } catch (e) {
    error.value = e.message
  }
}

// Un outil peut passer son resultat a un autre (ex. fond retire, puis recadrage).
const replaceSource = async ({ file, tool }) => {
  await loadFile(file)
  if (tool) activeTool.value = tool
}
</script>
