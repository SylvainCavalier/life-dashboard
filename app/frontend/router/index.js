// app/frontend/router/index.js
import { createRouter, createWebHistory } from 'vue-router'
import routes from './routes'
import { isFriend, FRIEND_ROUTES } from '../utils/currentUser'

const router = createRouter({
  history: createWebHistory(),
  routes
})

// L'authentification est entierement geree par Rails (session Devise) : un visiteur
// non connecte est redirige vers /users/sign_in avant meme que ce bundle ne soit
// servi, et les appels API repondent 401 (traite par l'intercepteur axios).
// Seule garde cote client : un compte d'ami reste sur les pages qui lui sont
// ouvertes. C'est du confort ; la protection, c'est l'API qui la fait (403).
router.beforeEach((to) => {
  if (isFriend && !FRIEND_ROUTES.includes(to.name)) return { name: 'Tools' }
})

export default router
