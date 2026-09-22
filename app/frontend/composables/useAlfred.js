// Alfred : etat du chat. Le job ecrit la reponse au fil de l'eau dans la table
// alfred_messages, l'interface relit la conversation tant qu'elle est « busy ».
// 1 s : assez fluide pour voir le texte arriver, et sous le plafond Rack::Attack
// (100 requetes API par minute). apiClient est utilise directement : passer par
// le store `api` ferait clignoter l'etat de chargement global a chaque sondage.
import { ref, computed } from 'vue'
import apiClient from '../plugins/axios'

const POLL_INTERVAL = 1000
const STORAGE_KEY = 'alfred.conversationId'

// Etat partage (module) : le widget est monte une seule fois, dans App.vue.
const overview = ref(null)
const conversation = ref(null)
const conversations = ref([])
const sending = ref(false)
const error = ref(null)
let timer = null

const rememberedId = () => {
  try {
    return window.localStorage.getItem(STORAGE_KEY)
  } catch {
    return null
  }
}

const remember = (id) => {
  try {
    if (id) window.localStorage.setItem(STORAGE_KEY, id)
    else window.localStorage.removeItem(STORAGE_KEY)
  } catch {
    // Stockage indisponible (navigation privee) : la conversation ne sera simplement pas reprise.
  }
}

const messageOf = (err) => err.response?.data?.error || 'Une erreur est survenue.'

export function useAlfred() {
  const messages = computed(() => conversation.value?.messages || [])
  const busy = computed(() => sending.value || Boolean(conversation.value?.busy))

  const stopPolling = () => {
    if (timer) clearTimeout(timer)
    timer = null
  }

  const poll = () => {
    stopPolling()
    if (!conversation.value?.busy) return
    timer = setTimeout(async () => {
      try {
        conversation.value = (await apiClient.get(`/alfred_conversations/${conversation.value.id}`)).data
      } catch (err) {
        error.value = messageOf(err)
      }
      poll()
    }, POLL_INTERVAL)
  }

  const loadOverview = async () => {
    overview.value = (await apiClient.get('/alfred')).data
  }

  const open = async (id) => {
    error.value = null
    conversation.value = (await apiClient.get(`/alfred_conversations/${id}`)).data
    remember(conversation.value.id)
    poll()
  }

  // Reprend la derniere conversation ouverte sur ce navigateur, si elle existe encore.
  const resume = async () => {
    const id = rememberedId()
    if (!id || conversation.value) return
    try {
      await open(id)
    } catch {
      remember(null)
    }
  }

  const startNew = () => {
    stopPolling()
    conversation.value = null
    error.value = null
    remember(null)
  }

  const loadConversations = async () => {
    conversations.value = (await apiClient.get('/alfred_conversations')).data
  }

  const remove = async (id) => {
    await apiClient.delete(`/alfred_conversations/${id}`)
    conversations.value = conversations.value.filter((c) => c.id !== id)
    if (conversation.value?.id === id) startNew()
  }

  const send = async (content) => {
    const text = content.trim()
    if (!text || busy.value) return false
    sending.value = true
    error.value = null
    try {
      if (!conversation.value) {
        conversation.value = (await apiClient.post('/alfred_conversations')).data
        remember(conversation.value.id)
      }
      conversation.value = (await apiClient.post(`/alfred_conversations/${conversation.value.id}/message`, { content: text })).data
      poll()
      return true
    } catch (err) {
      error.value = messageOf(err)
      return false
    } finally {
      sending.value = false
    }
  }

  const resolveAction = async (action, decision) => {
    error.value = null
    try {
      await apiClient.post(`/alfred_actions/${action.id}/${decision}`)
    } catch (err) {
      error.value = messageOf(err)
    }
    await open(conversation.value.id)
  }

  const saveInstructions = async (customInstructions) => {
    overview.value = (await apiClient.patch('/alfred', { custom_instructions: customInstructions })).data
  }

  const reindex = async () => {
    await apiClient.post('/alfred/reindex')
  }

  return {
    overview, conversation, conversations, messages, busy, error,
    loadOverview, resume, open, startNew, loadConversations, remove, send, resolveAction, saveInstructions, reindex,
  }
}
