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