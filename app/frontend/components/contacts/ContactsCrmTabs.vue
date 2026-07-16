<template>
  <div class="flex border-b overflow-x-auto mb-6">
    <router-link
      to="/contacts"
      class="px-5 py-3 text-sm font-medium whitespace-nowrap transition-colors"
      :class="route.path === '/contacts' ? 'text-indigo-600 border-b-2 border-indigo-600' : 'text-gray-500 hover:text-gray-700'"
    >
      Contacts
    </router-link>
    <router-link
      to="/crm"
      class="px-5 py-3 text-sm font-medium whitespace-nowrap transition-colors"
      :class="route.path === '/crm' ? 'text-indigo-600 border-b-2 border-indigo-600' : 'text-gray-500 hover:text-gray-700'"
    >
      CRM
    </router-link>
  </div>
</template>

<script setup>
import { useRoute } from 'vue-router'

const route = useRoute()
</script>
