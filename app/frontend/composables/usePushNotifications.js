// Abonnement de cet appareil aux notifications push (module Rappels).
//
// iPhone / iPad : le push n'existe que dans la webapp ajoutee a l'ecran d'accueil
// (iOS 16.4+), jamais dans un onglet Safari ; la demande d'autorisation doit partir
// d'un geste de l'utilisateur, d'ou `requestPermission` en tout premier dans `subscribe`.
import { ref, computed } from 'vue'
import { useApi } from './useApi'

const urlBase64ToUint8Array = (base64) => {
  const padded = (base64 + '='.repeat((4 - (base64.length % 4)) % 4)).replace(/-/g, '+').replace(/_/g, '/')
  const raw = window.atob(padded)
  return Uint8Array.from([...raw].map((c) => c.charCodeAt(0)))
}

// Pastille sur l'icone de l'application (webapp installee, Chrome, Edge).
export const updateAppBadge = (count) => {
  if (!('setAppBadge' in navigator)) return
  const action = count > 0 ? navigator.setAppBadge(count) : navigator.clearAppBadge()
  action.catch(() => {})
}

export function usePushNotifications() {
  const { get, post, delete: del } = useApi()

  const supported = 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
  const isIos = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
  const standalone = window.matchMedia?.('(display-mode: standalone)').matches || navigator.standalone === true
  // Sur iOS hors ecran d'accueil, PushManager est absent : il faut d'abord installer la webapp.
  const needsInstall = isIos && !standalone

  const permission = ref(supported ? window.Notification.permission : 'unsupported')
  const server = ref({ configured: false, public_key: null, email_fallback: false, subscriptions: [] })
  const endpoint = ref(null)
  const busy = ref(false)
  const error = ref('')

  const subscribed = computed(() => !!endpoint.value && server.value.subscriptions.some((s) => s.endpoint === endpoint.value))

  const registration = () => navigator.serviceWorker.register('/sw.js').then(() => navigator.serviceWorker.ready)

  const save = (subscription) => post('/push_subscriptions', { subscription: subscription.toJSON() })

  const refresh = async () => {
    error.value = ''
    server.value = await get('/push_subscriptions')
    if (!supported) return

    permission.value = window.Notification.permission
    const subscription = await (await registration()).pushManager.getSubscription()
    endpoint.value = subscription?.endpoint || null
    // Abonne cote navigateur mais inconnu du serveur (appareil supprime de la liste) : on le renvoie.
    if (subscription && permission.value === 'granted' && !server.value.subscriptions.some((s) => s.endpoint === subscription.endpoint)) {
      await save(subscription)
      server.value = await get('/push_subscriptions')
    }
  }

  const subscribe = async () => {
    if (!supported || busy.value) return
    busy.value = true
    error.value = ''
    try {
      permission.value = await window.Notification.requestPermission()
      if (permission.value !== 'granted') {
        error.value = 'Notifications refusées. Sur iPhone : Réglages > Notifications > Dashboard. Sur Mac : réglages du site dans le navigateur.'
        return
      }
      if (!server.value.public_key) throw new Error("Le serveur n'a pas de clé VAPID (rake reminders:vapid_keys).")

      const reg = await registration()
      const options = { userVisibleOnly: true, applicationServerKey: urlBase64ToUint8Array(server.value.public_key) }
      let subscription
      try {
        subscription = await reg.pushManager.subscribe(options)
      } catch (e) {
        // Ancien abonnement lie a d'autres cles VAPID : on le remplace.
        const previous = await reg.pushManager.getSubscription()
        if (!previous) throw e
        await previous.unsubscribe()
        subscription = await reg.pushManager.subscribe(options)
      }
      await save(subscription)
      await refresh()
    } catch (e) {
      error.value = e.response?.data?.errors?.join(', ') || e.message || 'Abonnement impossible'
    } finally {
      busy.value = false
    }
  }

  // Desabonne un appareil ; si c'est celui-ci, cote navigateur aussi.
  const removeDevice = async (device) => {
    busy.value = true
    try {
      if (supported && device.endpoint === endpoint.value) {
        const subscription = await (await registration()).pushManager.getSubscription()
        await subscription?.unsubscribe()
        endpoint.value = null
      }
      await del(`/push_subscriptions/${device.id}`)
      await refresh()
    } finally {
      busy.value = false
    }
  }

  const sendTest = async () => {
    busy.value = true
    error.value = ''
    try {
      return await post('/push_subscriptions/test_notification')
    } catch (e) {
      error.value = e.response?.data?.errors?.join(', ') || 'Envoi impossible'
      return null
    } finally {
      busy.value = false
    }
  }

  return {
    supported, isIos, standalone, needsInstall,
    permission, server, endpoint, subscribed, busy, error,
    refresh, subscribe, removeDevice, sendTest,
  }
}
