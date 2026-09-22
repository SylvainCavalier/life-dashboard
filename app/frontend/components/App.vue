<template>
  <router-view />
  <!-- Alfred, l'intendant : accessible depuis toutes les pages -->
  <AlfredWidget />
</template>

<script setup>
import AlfredWidget from './alfred/AlfredWidget.vue'
</script>
