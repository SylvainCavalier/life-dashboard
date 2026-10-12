<template>
  <div ref="frame" class="w-full overflow-hidden" :style="{ height: `${sheetHeight * scale}px` }">
    <div
      ref="sheet"
      class="letter-sheet bg-white shadow-md origin-top-left relative"
      :style="sheetStyle"
    >
      <!-- Expediteur a gauche, destinataire a droite : au meme niveau, ou dans la fenetre de l'enveloppe -->
      <div class="flex" :style="{ minHeight: mm(dateTop - L.marginTop) }">
        <div :style="{ width: mm(L.senderWidth), paddingBottom: letter.sender?.trim() ? mm(L.blockGap) : 0 }" class="whitespace-pre-line">{{ letter.sender?.trim() }}</div>
        <div
          class="whitespace-pre-line"
          :style="{
            marginLeft: mm(L.recipientLeft - L.marginSide - L.senderWidth),
            width: mm(L.recipientWidth),
            paddingTop: mm(recipientTop - L.marginTop),
            paddingBottom: letter.recipient?.trim() ? mm(L.blockGap) : 0,
          }"
        >{{ letter.recipient?.trim() }}</div>
      </div>

      <p v-if="dateLine" class="text-right" :style="{ marginBottom: mm(L.blockGap) }">{{ dateLine }}</p>

      <div v-if="hasHeading" :style="{ marginBottom: mm(L.blockGap) }">
        <p v-if="letter.mention?.trim()" class="font-bold">{{ letter.mention.trim() }}</p>
        <p v-if="letter.reference?.trim()">Réf. : {{ letter.reference.trim() }}</p>
        <p v-if="letter.subject?.trim()" class="font-bold">Objet : {{ letter.subject.trim() }}</p>
      </div>

      <!-- Contenu : HTML genere par Tiptap a partir du JSON (texte echappe par Tiptap) -->
      <div class="letter-body" v-html="bodyHtml"></div>

      <div v-if="signatureImage || letter.signatory?.trim()" class="letter-signature" :style="{ marginLeft: mm(L.signatureLeft - L.marginSide), marginTop: mm(L.blockGap) }">
        <img
          v-if="signatureImage"
          :src="signatureImage"
          alt="Signature"
          class="block"
          :style="{ maxWidth: mm(L.signatureMaxWidth), maxHeight: mm(L.signatureMaxHeight), marginBottom: mm(2) }"
        />
        <p v-if="letter.signatory?.trim()">{{ letter.signatory.trim() }}</p>
      </div>

      <!-- Sauts de page approximatifs : 257 mm de texte par page, le PDF fait foi -->
      <div
        v-for="(top, i) in pageBreaks"
        :key="i"
        class="absolute left-0 right-0 border-t border-dashed border-gray-300 pointer-events-none"
        :style="{ top: mm(top) }"
      >
        <span class="absolute right-1 -top-4 text-[9px] text-gray-400 bg-white px-1">page {{ i + 2 }}</span>
      </div>

      <div
        v-if="letter.footer?.trim()"
        class="absolute text-center whitespace-pre-line border-t"
        :style="{
          left: mm(L.marginSide),
          right: mm(L.marginSide),
          bottom: mm(L.marginBottom - 18),
          minHeight: mm(14),
          paddingTop: mm(2),
          fontSize: `${L.smallFontSize}pt`,
          lineHeight: 1.15,
          color: '#6B7280',
          borderColor: '#D1D5DB',
        }"
      >{{ letter.footer.trim() }}</div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, nextTick, watch } from 'vue'
import { generateHTML } from '@tiptap/core'
import { letterExtensions } from './letterExtensions'
import { LAYOUT as L, placeAndDate } from './letterFormat'

// Apercu a l'echelle de la lettre, reprenant les cotes de Letters::Layout. La feuille
// est dessinee en millimetres puis reduite a la largeur disponible.
const props = defineProps({
  letter: { type: Object, required: true },
  signatureDataUrl: { type: String, default: null },
})

const MM_TO_PX = 96 / 25.4
const PAGE_WIDTH_PX = L.pageWidth * MM_TO_PX
const PAGE_HEIGHT_PX = L.pageHeight * MM_TO_PX
const extensions = letterExtensions()

const frame = ref(null)
const sheet = ref(null)
const scale = ref(1)
const sheetHeight = ref(PAGE_HEIGHT_PX)

const mm = (value) => `${value}mm`

const sheetStyle = computed(() => ({
  width: mm(L.pageWidth),
  minHeight: mm(L.pageHeight),
  padding: `${mm(L.marginTop)} ${mm(L.marginSide)} ${mm(L.marginBottom)}`,
  transform: `scale(${scale.value})`,
  fontFamily: "'DejaVu Sans', Verdana, Geneva, sans-serif",
  fontSize: `${L.fontSize}pt`,
  lineHeight: L.lineHeight,
  color: '#111827',
}))

// Letters::Layout.recipient_top / date_top
const recipientTop = computed(() => (props.letter.window_envelope ? L.windowRecipientTop : L.marginTop))
const dateTop = computed(() => (props.letter.window_envelope ? L.windowDateTop : L.marginTop))
const dateLine = computed(() => placeAndDate(props.letter.place, props.letter.letter_date))
const hasHeading = computed(() => [props.letter.mention, props.letter.reference, props.letter.subject].some(v => v?.trim()))
const signatureImage = computed(() => (props.letter.include_signature ? props.signatureDataUrl : null))

const bodyHtml = computed(() => {
  const doc = props.letter.body
  if (!doc?.content?.length) return ''
  try {
    return generateHTML(doc, extensions)
  } catch {
    return ''
  }
})

// Page 1 : le texte s'arrete a 297 - 25 mm ; pages suivantes : 257 mm de texte chacune.
const pageBreaks = computed(() => {
  const heightMm = sheetHeight.value / MM_TO_PX
  const breaks = []
  const firstBreak = L.pageHeight - L.marginBottom
  const perPage = L.pageHeight - L.marginTop - L.marginBottom
  for (let top = firstBreak; top < heightMm - L.marginBottom; top += perPage) breaks.push(top)
  return breaks
})

const measure = () => {
  if (!frame.value || !sheet.value) return
  scale.value = Math.min(1, frame.value.clientWidth / PAGE_WIDTH_PX)
  sheetHeight.value = sheet.value.offsetHeight
}

let observer
onMounted(() => {
  observer = new ResizeObserver(measure)
  observer.observe(frame.value)
  observer.observe(sheet.value)
  measure()
})
onBeforeUnmount(() => observer?.disconnect())

watch(() => props.letter, () => nextTick(measure), { deep: true })
</script>

<style scoped>
.letter-sheet p {
  margin: 0;
}
.letter-body :deep(p) {
  margin: 0 0 6pt;
}
.letter-body :deep(p:empty::before) {
  content: '\00a0';
}
.letter-body :deep(ul),
.letter-body :deep(ol) {
  padding-left: 6mm;
  margin: 0;
}
.letter-body :deep(ul) {
  list-style: disc;
}
.letter-body :deep(ol) {
  list-style: decimal;
}
.letter-body :deep(li p) {
  margin: 0 0 2pt;
}
</style>
