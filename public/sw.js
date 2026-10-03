// Service worker du Life Dashboard : uniquement les notifications push des rappels.
// Pas de cache ni d'interception des requetes (le SPA reste servi par Rails).
// Fichier statique servi tel quel depuis public/ : la portee "/" couvre toute l'app.
//
// iOS exige qu'un push affiche toujours une notification (sinon l'abonnement est
// revoque) : on en affiche une meme si le contenu est illisible.

self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()))

self.addEventListener('push', (event) => {
  let data = {}
  try {
    data = event.data ? event.data.json() : {}
  } catch {
    data = { body: event.data ? event.data.text() : '' }
  }

  const url = typeof data.url === 'string' && data.url.startsWith('/') ? data.url : '/reminders'
  const options = {
    body: data.body || '',
    tag: data.tag || 'reminder',
    renotify: Boolean(data.renotify),
    requireInteraction: true,
    icon: '/icon-192.png',
    badge: '/icon-192.png',
    data: { url },
  }
  // Boutons d'action : affiches par Chrome et Edge, ignores par Safari et iOS
  // (le clic ouvre alors la page Rappels, ou se trouvent les memes boutons).
  if (data.reminder_id) {
    options.actions = [
      { action: 'done', title: 'Fait' },
      { action: 'snooze', title: 'Dans 10 min' },
    ]
  }

  const tasks = [self.registration.showNotification(data.title || 'Rappel', options)]
  if (typeof data.badge_count === 'number' && self.navigator.setAppBadge) {
    tasks.push(
      (data.badge_count > 0 ? self.navigator.setAppBadge(data.badge_count) : self.navigator.clearAppBadge()).catch(() => {})
    )
  }
  event.waitUntil(Promise.all(tasks))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  let url = event.notification.data?.url || '/reminders'
  if (event.action === 'done' || event.action === 'snooze') {
    url += (url.includes('?') ? '&' : '?') + `do=${event.action}`
  }

  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    const client = windows.find((w) => new URL(w.url).origin === self.location.origin)
    if (client) {
      // L'application est deja ouverte : elle navigue elle-meme (router Vue).
      await client.focus()
      client.postMessage({ type: 'navigate', url })
      return
    }
    await self.clients.openWindow(url)
  })())
})
