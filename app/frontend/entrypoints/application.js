// app/frontend/entrypoints/application.js
import { createApp } from 'vue'
import { createPinia } from 'pinia'
import router from '../router'
import App from '../components/App.vue'
import '../styles/application.css'

// Import axios configuration
import '../plugins/axios'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)
app.use(router)

// Initialize auth check after app is mounted
app.mount('#app')

// Service worker des notifications push (module Rappels). Le clic sur une
// notification, application deja ouverte, arrive ici sous forme de message.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js').catch((error) => console.warn('Service worker non enregistre :', error))
  navigator.serviceWorker.addEventListener('message', (event) => {
    const url = event.data?.type === 'navigate' && event.data.url
    if (typeof url === 'string' && url.startsWith('/')) router.push(url)
  })
}

// Check authentication status on app startup (only if Devise is set up)
// Uncomment the block below after installing Devise and creating auth API routes
//
// import { useAuthStore } from '../stores/auth'
// const authStore = useAuthStore()
// const publicPages = ['/users/sign_in', '/users/sign_up', '/users/password']
// const isPublicPage = publicPages.some(page => window.location.pathname.startsWith(page))
// if (!isPublicPage) {
//   authStore.checkAuth().catch(() => {
//     console.log('Auth check failed, user not authenticated')
//   })
// }