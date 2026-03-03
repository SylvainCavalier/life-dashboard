// app/frontend/router/index.js
import { createRouter, createWebHistory } from 'vue-router'
import routes from './routes'

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Navigation guard for authenticated routes
// Routes with meta.requiresAuth will redirect to sign_in if not authenticated
router.beforeEach((to, _from, next) => {
  if (to.meta.requiresAuth) {
    const authToken = localStorage.getItem('authToken')
    if (!authToken) {
      return next({ path: '/users/sign_in', query: { redirect: to.fullPath } })
    }
  }
  next()
})

export default router
