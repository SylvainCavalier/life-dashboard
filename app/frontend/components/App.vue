<template>
  <FriendNav v-if="isFriend" />
  <router-view />
  <!-- Alfred, l'intendant : accessible depuis toutes les pages (proprietaire seulement) -->
  <AlfredWidget v-if="!isFriend" />
</template>

<script setup>
import AlfredWidget from './alfred/AlfredWidget.vue'
import FriendNav from './FriendNav.vue'
import { isFriend } from '../utils/currentUser'
</script>
