<template>
  <div class="border rounded-lg bg-white focus-within:ring-2 focus-within:ring-gray-200">
    <!-- Barre d'outils -->
    <div v-if="editor" class="flex flex-wrap items-center gap-1 border-b px-2 py-1.5">
      <button
        v-for="action in marks"
        :key="action.name"
        type="button"
        :title="action.title"
        :class="buttonClass(editor.isActive(action.name))"
        @click="action.run()"
      >
        <span :class="action.style">{{ action.label }}</span>
      </button>

      <span class="mx-1 h-5 w-px bg-gray-200"></span>

      <button type="button" title="Liste à puces" :class="buttonClass(editor.isActive('bulletList'))" @click="chain().toggleBulletList().run()">
        &bull; Liste
      </button>
      <button type="button" title="Liste numérotée" :class="buttonClass(editor.isActive('orderedList'))" @click="chain().toggleOrderedList().run()">
        1. Liste
      </button>

      <span class="mx-1 h-5 w-px bg-gray-200"></span>

      <button
        v-for="align in alignments"
        :key="align.value"
        type="button"
        :title="align.title"
        :class="buttonClass(editor.isActive({ textAlign: align.value }))"
        @click="chain().setTextAlign(align.value).run()"
      >
        <svg viewBox="0 0 16 16" class="w-4 h-4" fill="currentColor" aria-hidden="true">
          <rect v-for="(line, i) in align.lines" :key="i" :x="line[0]" :y="2 + i * 3.5" :width="line[1]" height="1.6" rx="0.5" />
        </svg>
      </button>

      <span class="mx-1 h-5 w-px bg-gray-200"></span>

      <select
        class="text-xs border rounded px-1.5 py-1 text-gray-600 max-w-[9rem]"
        title="Insérer une formule d'appel"
        @change="insertFormula($event)"
      >
        <option value="">Formule d'appel…</option>
        <option v-for="s in SALUTATIONS" :key="s" :value="s">{{ s }}</option>
      </select>
      <select
        class="text-xs border rounded px-1.5 py-1 text-gray-600 max-w-[9rem]"
        title="Insérer une formule de politesse"
        @change="insertFormula($event)"
      >
        <option value="">Formule de politesse…</option>
        <option v-for="c in CLOSINGS" :key="c" :value="c">{{ c }}</option>
      </select>

      <div class="ml-auto flex items-center gap-1">
        <button type="button" title="Annuler" :class="buttonClass(false)" :disabled="!editor.can().undo()" @click="chain().undo().run()">&#8630;</button>
        <button type="button" title="Rétablir" :class="buttonClass(false)" :disabled="!editor.can().redo()" @click="chain().redo().run()">&#8631;</button>
        <VoiceInputButton size="sm" @transcribed="insertDictation" />
      </div>
    </div>

    <EditorContent :editor="editor" class="letter-editor" />
  </div>
</template>

<script setup>
import { watch, onBeforeUnmount } from 'vue'
import { useEditor, EditorContent } from '@tiptap/vue-3'
import VoiceInputButton from '../VoiceInputButton.vue'
import { SALUTATIONS, CLOSINGS, emptyDoc } from './letterFormat'
import { letterExtensions } from './letterExtensions'

// Document Tiptap (JSON) en v-model, limite aux noeuds de letterExtensions.
const props = defineProps({
  modelValue: { type: Object, default: () => emptyDoc() },
})
const emit = defineEmits(['update:modelValue'])

const editor = useEditor({
  content: props.modelValue,
  extensions: letterExtensions(),
  editorProps: {
    attributes: { class: 'prose-letter min-h-[16rem] px-4 py-3 focus:outline-none text-sm' },
  },
  onUpdate: ({ editor }) => emit('update:modelValue', editor.getJSON()),
})

// Chargement d'un autre brouillon : on remplace le contenu sans renvoyer d'evenement.
watch(() => props.modelValue, (value) => {
  if (!editor.value) return
  if (JSON.stringify(value) === JSON.stringify(editor.value.getJSON())) return
  editor.value.commands.setContent(value && value.type ? value : emptyDoc(), { emitUpdate: false })
})

onBeforeUnmount(() => editor.value?.destroy())

const chain = () => editor.value.chain().focus()

const marks = [
  { name: 'bold', label: 'G', title: 'Gras', style: 'font-bold', run: () => chain().toggleBold().run() },
  { name: 'italic', label: 'I', title: 'Italique', style: 'italic', run: () => chain().toggleItalic().run() },
  { name: 'underline', label: 'S', title: 'Souligné', style: 'underline', run: () => chain().toggleUnderline().run() },
]

// Icones : [x, largeur] de chaque trait
const alignments = [
  { value: 'left', title: 'Aligner à gauche', lines: [[1, 14], [1, 9], [1, 12], [1, 8]] },
  { value: 'center', title: 'Centrer', lines: [[1, 14], [3.5, 9], [2, 12], [4, 8]] },
  { value: 'right', title: 'Aligner à droite', lines: [[1, 14], [6, 9], [3, 12], [7, 8]] },
  { value: 'justify', title: 'Justifier', lines: [[1, 14], [1, 14], [1, 14], [1, 8]] },
]

const buttonClass = (active) => [
  'min-w-[2rem] h-8 px-2 rounded text-sm transition disabled:opacity-30 disabled:cursor-not-allowed',
  active ? 'bg-gray-900 text-white' : 'text-gray-700 hover:bg-gray-100',
]

// Une formule devient son propre paragraphe, a l'endroit du curseur.
const insertFormula = (event) => {
  const text = event.target.value
  event.target.value = ''
  if (!text) return
  const editorValue = editor.value
  const { $from } = editorValue.state.selection
  const paragraphIsEmpty = $from.parent.textContent.length === 0
  const content = [{ type: 'paragraph', content: [{ type: 'text', text }] }]
  if (paragraphIsEmpty) {
    chain().insertContent(content).run()
  } else {
    chain().splitBlock().insertContent(content).run()
  }
}

const insertDictation = (text) => {
  if (!text) return
  chain().insertContent(text).run()
}
</script>

<style scoped>
.letter-editor :deep(.ProseMirror) {
  font-family: 'DejaVu Sans', Verdana, Geneva, sans-serif;
  line-height: 1.5;
}
.letter-editor :deep(.ProseMirror p) {
  margin: 0 0 0.6em;
}
.letter-editor :deep(.ProseMirror ul) {
  list-style: disc;
  padding-left: 1.5em;
  margin: 0 0 0.6em;
}
.letter-editor :deep(.ProseMirror ol) {
  list-style: decimal;
  padding-left: 1.5em;
  margin: 0 0 0.6em;
}
.letter-editor :deep(.ProseMirror li p) {
  margin: 0;
}
</style>
