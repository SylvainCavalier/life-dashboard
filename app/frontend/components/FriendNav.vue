<template>
  <!-- Barre des comptes d'amis : les trois pages qui leur sont ouvertes, a la place du dashboard -->
  <nav class="bg-white border-b border-gray-200">
    <div class="max-w-6xl mx-auto px-4 py-3 flex flex-wrap items-center gap-2">
      <router-link
        v-for="link in LINKS"
        :key="link.to"
        :to="link.to"
        class="text-sm px-3 py-2 rounded-lg transition-colors"
        :class="isActive(link) ? 'bg-gray-900 text-white' : 'text-gray-600 hover:bg-gray-100'"
      >
        {{ link.label }}
      </router-link>
      <div class="ml-auto flex items-center gap-2">
        <a href="/account/password" class="text-sm text-gray-500 hover:text-gray-800 px-3 py-2">Mot de passe</a>
        <!-- Deconnexion : formulaire Rails classique (session Devise, DELETE + CSRF) -->
        <form action="/users/sign_out" method="post">
          <input type="hidden" name="_method" value="delete" />
          <input type="hidden" name="authenticity_token" :value="csrfToken" />
          <button type="submit" class="text-sm text-gray-500 hover:text-gray-800 border border-gray-200 rounded-lg px-3 py-2 bg-white">
            Se deconnecter
          </button>
        </form>
      </div>
    </div>
  </nav>
</template>

<script setup>
import { useRoute } from 'vue-router'

const LINKS = [
  { to: '/tools', label: 'Outils', names: ['Tools'] },
  { to: '/downloader', label: 'Downloader', names: ['Downloader', 'DownloaderFolder'] },
  { to: '/transfer', label: 'Transfert', names: ['Transfer'] },
]

const route = useRoute()
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''

const isActive = (link) => link.names.includes(route.name)
</script>
