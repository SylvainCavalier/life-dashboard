// app/frontend/router/index.js
import { createRouter, createWebHistory } from 'vue-router'
import routes from './routes'

const router = createRouter({
  history: createWebHistory(),
  routes
})

// Pas de garde de navigation cote client : l'authentification est entierement
// geree par Rails (session Devise). Un visiteur non connecte est redirige vers
// /users/sign_in avant meme que ce bundle ne soit servi, et les appels API
// repondent 401 (traite par l'intercepteur axios).

export default router
