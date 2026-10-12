<template>
  <div class="min-h-screen bg-gray-50 p-4 sm:p-6">
    <div class="max-w-7xl mx-auto">
      <router-link to="/" class="text-sm text-gray-400 hover:text-gray-600 mb-4 inline-block">&larr; Retour au dashboard</router-link>

      <!-- Header -->
      <div class="flex flex-wrap items-center justify-between gap-3 mb-4">
        <div>
          <h1 class="text-2xl font-bold text-gray-900">Courrier</h1>
          <p class="text-sm text-gray-500">Mise en page d'une lettre classique, à télécharger ou à ranger dans les documents.</p>
        </div>
        <div class="flex gap-2">
          <button
            type="button"
            class="text-sm border border-gray-200 bg-white rounded-lg px-3 py-2 text-gray-700 hover:border-gray-300"
            @click="showDrafts = !showDrafts"
          >
            Brouillons ({{ letters.length }})
          </button>
          <button type="button" class="bg-black text-white text-sm px-4 py-2 rounded-lg hover:bg-gray-800 transition" @click="newLetter">
            + Nouveau courrier
          </button>
        </div>
      </div>

      <!-- Brouillons -->
      <div v-if="showDrafts" class="bg-white rounded-xl shadow-sm p-4 mb-4">
        <p v-if="!letters.length" class="text-sm text-gray-400">Aucun brouillon enregistré.</p>
        <ul v-else class="divide-y">
          <li v-for="item in letters" :key="item.id" class="flex items-center gap-3 py-2">
            <button type="button" class="flex-1 min-w-0 text-left group" @click="openLetter(item.id)">
              <p class="text-sm font-medium text-gray-900 truncate group-hover:underline" :class="{ 'text-blue-700': item.id === currentId }">
                {{ item.label }}
              </p>
              <p class="text-xs text-gray-400 truncate">
                {{ firstLine(item.recipient) || 'Sans destinataire' }} · modifié le {{ formatDateTime(item.updated_at) }}
                <span v-if="item.document" class="ml-1 text-emerald-600">· rangé dans les documents</span>
              </p>
            </button>
            <button type="button" class="text-xs text-gray-400 hover:text-red-600 px-2 py-1" @click="deleteLetter(item)">Supprimer</button>
          </li>
        </ul>
      </div>

      <div class="grid grid-cols-1 xl:grid-cols-2 gap-6 items-start">
        <!-- Formulaire -->
        <div class="bg-white rounded-xl shadow-sm">
          <!-- Barre d'actions -->
          <div class="flex flex-wrap items-center gap-2 border-b px-4 py-3 sticky top-0 bg-white rounded-t-xl z-10">
            <p class="text-xs mr-auto" :class="statusClass">{{ statusText }}</p>
            <button type="button" :class="actionClass" :disabled="busy" @click="saveDraft">Mettre en brouillon</button>
            <button type="button" :class="actionClass" :disabled="busy" @click="download('pdf')">PDF</button>
            <button type="button" :class="actionClass" :disabled="busy" @click="download('docx')">DOCX</button>
            <button
              type="button"
              class="text-sm bg-black text-white rounded-lg px-3 py-1.5 hover:bg-gray-800 transition disabled:opacity-40"
              :disabled="busy"
              :title="current.document ? 'Remplace le PDF déjà rangé dans les documents' : 'Range le PDF dans la bibliothèque de documents'"
              @click="uploadToDocuments"
            >
              {{ current.document ? 'Mettre à jour le document' : 'Ranger dans les documents' }}
            </button>
          </div>

          <div class="p-4 space-y-4">
            <!-- Adresses -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <div class="flex items-center justify-between mb-1">
                  <label class="text-sm font-medium text-gray-700">Expéditeur</label>
                  <button type="button" class="text-xs text-blue-600 hover:underline" @click="fillSenderFromProfile">Mes coordonnées</button>
                </div>
                <textarea v-model="current.sender" rows="6" :class="inputClass" placeholder="Nom&#10;Adresse&#10;Code postal Ville"></textarea>
              </div>
              <div>
                <div class="flex items-center justify-between mb-1 gap-2">
                  <label class="text-sm font-medium text-gray-700">Destinataire</label>
                  <select class="text-xs border rounded px-1.5 py-0.5 text-gray-600 max-w-[11rem]" @focus="loadContacts" @change="fillRecipientFromContact($event)">
                    <option value="">Depuis un contact…</option>
                    <option v-for="c in contacts" :key="c.id" :value="c.id">{{ contactName(c) }}</option>
                  </select>
                </div>
                <textarea v-model="current.recipient" rows="6" :class="inputClass" placeholder="Nom ou organisme&#10;Service&#10;Adresse&#10;Code postal Ville"></textarea>
                <label class="flex items-center gap-2 mt-1.5 cursor-pointer select-none" title="Descend le destinataire dans la fenêtre d'une enveloppe DL (50 mm du haut) ; prend environ 4 cm de plus en haut de page">
                  <input v-model="current.window_envelope" type="checkbox" class="rounded" />
                  <span class="text-xs text-gray-600">Enveloppe à fenêtre</span>
                </label>
              </div>
            </div>

            <!-- Lieu, date, mention -->
            <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Lieu</label>
                <input v-model="current.place" type="text" :class="inputClass" placeholder="Créteil" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Date</label>
                <input v-model="current.letter_date" type="date" :class="inputClass" />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Référence</label>
                <input v-model="current.reference" type="text" :class="inputClass" placeholder="N° de dossier, contrat…" />
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Mode d'envoi</label>
              <input v-model="current.mention" type="text" list="letter-mentions" :class="inputClass" placeholder="Lettre recommandée avec accusé de réception" />
              <datalist id="letter-mentions">
                <option v-for="m in defaults.mentions" :key="m" :value="m" />
              </datalist>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Objet</label>
              <input v-model="current.subject" type="text" :class="inputClass" placeholder="Résiliation de mon contrat n° …" />
            </div>

            <!-- Contenu -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Contenu</label>
              <LetterEditor v-model="current.body" />
            </div>

            <!-- Signature -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 items-start">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Signataire</label>
                <input v-model="current.signatory" type="text" :class="inputClass" placeholder="Prénom Nom" />
              </div>
              <div class="pt-0 md:pt-7">
                <label class="flex items-center gap-2 select-none" :class="defaults.signature_data_url ? 'cursor-pointer' : 'opacity-60'">
                  <input v-model="current.include_signature" type="checkbox" class="rounded" :disabled="!defaults.signature_data_url" />
                  <span class="text-sm text-gray-700">Apposer ma signature manuscrite</span>
                </label>
                <p v-if="!defaults.signature_data_url" class="text-xs text-gray-400 mt-1">
                  Aucune signature enregistrée : à ajouter dans <router-link to="/profile" class="underline">Mon profil</router-link>.
                </p>
              </div>
            </div>

            <!-- Pied de page -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Pied de page</label>
              <textarea v-model="current.footer" rows="2" :class="inputClass" placeholder="Mentions légales, SIRET, coordonnées…"></textarea>
            </div>
          </div>
        </div>

        <!-- Apercu -->
        <div class="xl:sticky xl:top-4">
          <div class="flex items-center justify-between mb-2">
            <h2 class="text-sm font-medium text-gray-700">Aperçu</h2>
            <span class="text-xs text-gray-400">A4 · le PDF fait foi pour les sauts de page</span>
          </div>
          <div class="bg-gray-200 rounded-xl p-3 sm:p-4 xl:max-h-[calc(100vh-4rem)] xl:overflow-y-auto">
            <LetterPreview :letter="current" :signature-data-url="defaults.signature_data_url" />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, onBeforeUnmount, watch } from 'vue'
import { useRoute, useRouter, onBeforeRouteLeave } from 'vue-router'
import { useApi } from '../../composables/useApi'
import LetterEditor from '../../components/letters/LetterEditor.vue'
import LetterPreview from '../../components/letters/LetterPreview.vue'
import { emptyDoc, todayIso } from '../../components/letters/letterFormat'

const route = useRoute()
const router = useRouter()
const { get, post, patch, delete: del } = useApi()

const FIELDS = ['sender', 'recipient', 'window_envelope', 'place', 'letter_date', 'mention', 'reference', 'subject', 'body', 'signatory', 'include_signature', 'footer']

const letters = ref([])
const contacts = ref([])
const defaults = ref({ sender: '', place: '', signatory: '', signature_data_url: null, mentions: [] })
const showDrafts = ref(false)
const busy = ref(false)
const message = ref(null) // { type: 'success' | 'error', text }
const savedSnapshot = ref('')

const current = reactive(blankLetter())
const currentId = computed(() => current.id || null)

function blankLetter() {
  return {
    id: null,
    document: null,
    sender: '',
    recipient: '',
    window_envelope: false,
    place: '',
    letter_date: todayIso(),
    mention: '',
    reference: '',
    subject: '',
    body: emptyDoc(),
    signatory: '',
    include_signature: true,
    footer: '',
  }
}

const payload = () => Object.fromEntries(FIELDS.map(f => [f, current[f]]))
const snapshot = () => JSON.stringify(payload())
const dirty = computed(() => snapshot() !== savedSnapshot.value)

const inputClass = 'w-full border rounded-lg px-3 py-2 text-sm'
const actionClass = 'text-sm border border-gray-200 rounded-lg px-3 py-1.5 text-gray-700 hover:border-gray-400 transition disabled:opacity-40'

const statusText = computed(() => {
  if (message.value) return message.value.text
  if (busy.value) return 'En cours…'
  if (!current.id) return dirty.value ? 'Nouveau courrier, non enregistré' : 'Nouveau courrier'
  return dirty.value ? 'Modifications non enregistrées' : 'Brouillon enregistré'
})
const statusClass = computed(() => {
  if (message.value?.type === 'error') return 'text-red-600'
  if (message.value?.type === 'success') return 'text-emerald-600'
  return dirty.value ? 'text-amber-600' : 'text-gray-400'
})

let messageTimer
const flash = (type, text) => {
  message.value = { type, text }
  clearTimeout(messageTimer)
  messageTimer = setTimeout(() => { message.value = null }, 5000)
}
const errorText = (error, fallback) => error?.response?.data?.errors?.join(', ') || fallback

// -- Chargement ---------------------------------------------------------------

const fetchLetters = async () => {
  letters.value = await get('/letters')
}

const fetchDefaults = async () => {
  try {
    defaults.value = await get('/letters/defaults')
  } catch {
    // Profil absent : le formulaire reste vide
  }
}

const loadContacts = async () => {
  if (contacts.value.length) return
  try {
    const list = await get('/contacts')
    contacts.value = list.slice().sort((a, b) => contactName(a).localeCompare(contactName(b), 'fr'))
  } catch {
    contacts.value = []
  }
}

const assign = (data) => {
  Object.assign(current, blankLetter(), data)
  if (!current.body?.type) current.body = emptyDoc()
  savedSnapshot.value = snapshot()
}

const startBlank = () => {
  assign({})
  current.sender = defaults.value.sender || ''
  current.place = defaults.value.place || ''
  current.signatory = defaults.value.signatory || ''
  current.include_signature = !!defaults.value.signature_data_url
  // Un courrier neuf pre-rempli n'est pas une modification a enregistrer
  savedSnapshot.value = snapshot()
}

const loadFromRoute = async () => {
  const id = route.params.id
  if (!id) {
    startBlank()
    return
  }
  if (String(current.id) === String(id)) return
  try {
    assign(await get(`/letters/${id}`))
  } catch {
    flash('error', 'Brouillon introuvable')
    router.replace({ name: 'Letters' })
  }
}

// -- Actions -------------------------------------------------------------------

const confirmDiscard = () => !dirty.value || window.confirm('Les modifications non enregistrées seront perdues. Continuer ?')

const newLetter = () => {
  if (!confirmDiscard()) return
  savedSnapshot.value = snapshot() // evite une seconde confirmation par la garde de route
  if (route.params.id) router.push({ name: 'Letters' })
  else startBlank()
}

const openLetter = (id) => {
  if (id === current.id) return
  if (!confirmDiscard()) return
  savedSnapshot.value = snapshot()
  router.push({ name: 'Letters', params: { id } })
}

const persist = async () => {
  const data = current.id
    ? await patch(`/letters/${current.id}`, { letter: payload() })
    : await post('/letters', { letter: payload() })
  const isNew = !current.id
  assign(data)
  await fetchLetters()
  if (isNew) router.replace({ name: 'Letters', params: { id: data.id } })
  return data
}

const saveDraft = async () => {
  busy.value = true
  try {
    await persist()
    flash('success', 'Brouillon enregistré')
  } catch (error) {
    flash('error', errorText(error, "Échec de l'enregistrement"))
  } finally {
    busy.value = false
  }
}

const download = async (fileFormat) => {
  busy.value = true
  try {
    const response = await fetch('/api/letters/export', {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || '',
      },
      body: JSON.stringify({ file_format: fileFormat, letter: payload() }),
    })
    if (!response.ok) {
      const data = await response.json().catch(() => null)
      throw new Error(data?.errors?.join(', ') || `Erreur ${response.status}`)
    }
    const blob = await response.blob()
    const disposition = response.headers.get('Content-Disposition') || ''
    const match = disposition.match(/filename\*=UTF-8''([^;]+)|filename="([^"]+)"/)
    const filename = match ? decodeURIComponent(match[1] || match[2]) : `courrier.${fileFormat}`
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    document.body.appendChild(link)
    link.click()
    link.remove()
    setTimeout(() => URL.revokeObjectURL(url), 1000)
  } catch (error) {
    flash('error', `Téléchargement impossible : ${error.message}`)
  } finally {
    busy.value = false
  }
}

// Le PDF range est celui du brouillon enregistre : on enregistre d'abord.
const uploadToDocuments = async () => {
  busy.value = true
  try {
    await persist()
    assign(await post(`/letters/${current.id}/save_to_documents`))
    await fetchLetters()
    flash('success', `PDF rangé dans les documents (« ${current.document.name} »)`)
  } catch (error) {
    flash('error', errorText(error, 'Échec du rangement dans les documents'))
  } finally {
    busy.value = false
  }
}

const deleteLetter = async (item) => {
  const extra = item.document ? ' Le PDF déjà rangé dans les documents est conservé.' : ''
  if (!window.confirm(`Supprimer le brouillon « ${item.label} » ?${extra}`)) return
  try {
    await del(`/letters/${item.id}`)
    await fetchLetters()
    if (item.id === current.id) {
      savedSnapshot.value = snapshot()
      router.push({ name: 'Letters' })
    }
  } catch (error) {
    flash('error', errorText(error, 'Suppression impossible'))
  }
}

// -- Pre-remplissage -----------------------------------------------------------

const fillSenderFromProfile = () => {
  if (!defaults.value.sender) {
    flash('error', 'Profil vide : renseignez « Mon profil » d\'abord')
    return
  }
  current.sender = defaults.value.sender
  if (!current.place) current.place = defaults.value.place
  if (!current.signatory) current.signatory = defaults.value.signatory
}

const contactName = (c) => [c.first_name, c.last_name].filter(Boolean).join(' ')

const fillRecipientFromContact = (event) => {
  const contact = contacts.value.find(c => String(c.id) === event.target.value)
  event.target.value = ''
  if (!contact) return
  current.recipient = [contactName(contact), contact.address, contact.city].filter(v => v?.trim()).join('\n')
}

// -- Formatage -----------------------------------------------------------------

const firstLine = (text) => (text || '').split('\n')[0].trim()
const formatDateTime = (iso) => new Date(iso).toLocaleString('fr-FR', { dateStyle: 'short', timeStyle: 'short' })

// -- Cycle de vie --------------------------------------------------------------

const beforeUnload = (event) => {
  if (!dirty.value) return
  event.preventDefault()
  event.returnValue = ''
}

onBeforeRouteLeave(() => confirmDiscard())

watch(() => route.params.id, () => {
  if (route.name === 'Letters') loadFromRoute()
})

onMounted(async () => {
  window.addEventListener('beforeunload', beforeUnload)
  await Promise.all([fetchDefaults(), fetchLetters()])
  await loadFromRoute()
})

onBeforeUnmount(() => {
  window.removeEventListener('beforeunload', beforeUnload)
  clearTimeout(messageTimer)
})
</script>
