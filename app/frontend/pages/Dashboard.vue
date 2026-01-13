<template>
  <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-6">
    <div class="max-w-4xl mx-auto">
      <!-- Header -->
      <div class="text-center mb-12">
        <h1 class="text-5xl font-bold text-gray-900 mb-4">
          🚀 Rails + Vue 3 + Tailwind
        </h1>
        <p class="text-xl text-gray-600 mb-2">Production-Ready Boilerplate</p>
        <div class="inline-flex items-center px-4 py-2 bg-green-100 text-green-800 rounded-full text-sm font-medium">
          ✅ Boilerplate Running - Ready to Test
        </div>
      </div>

      <!-- Quick Demo Section -->
      <div class="bg-white rounded-xl shadow-lg p-8 mb-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center">
          <span class="text-green-500 mr-3">🎯</span>
          Boilerplate Demo (You're seeing this now!)
        </h2>
        
        <div class="bg-gray-900 rounded-lg p-4 mb-4">
          <code class="text-green-400 text-sm">
            <span class="text-gray-400"># You can run either:</span><br/>
            rails server<br/>
            <span class="text-gray-400"># or for quick demo without DB:</span><br/>
            SKIP_DB_CHECKS=true rails server
          </code>
        </div>

        <p class="text-gray-600 mb-4">
          This boilerplate includes Vue 3, Pinia, Axios, and all the security gems pre-configured. 
          Perfect for starting new Rails projects quickly!
        </p>

        <!-- Demo Components -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
          <div class="bg-blue-50 p-4 rounded-lg">
            <h3 class="font-semibold text-blue-900 mb-2">🎛️ Pinia Store</h3>
            <button 
              @click="counter.increment()"
              class="bg-blue-500 hover:bg-blue-600 text-white px-4 py-2 rounded font-medium w-full"
            >
              Counter: {{ counter.count }}
            </button>
          </div>

          <div class="bg-green-50 p-4 rounded-lg">
            <h3 class="font-semibold text-green-900 mb-2">🔗 Axios API</h3>
            <button 
              @click="testApiCall"
              :disabled="api.loading.value"
              class="bg-green-500 hover:bg-green-600 text-white px-4 py-2 rounded font-medium w-full disabled:opacity-50"
            >
              {{ api.loading.value ? 'Loading...' : 'Test API' }}
            </button>
          </div>
        </div>
      </div>

      <!-- Installation Instructions -->
      <div class="bg-white rounded-xl shadow-lg p-8 mb-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center">
          <span class="text-blue-500 mr-3">📦</span>
          Full Setup Instructions
        </h2>

        <div class="space-y-6">
          <!-- Step 1 -->
          <div class="border-l-4 border-blue-500 pl-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">1. Install PostgreSQL</h3>
            <div class="bg-gray-900 rounded-lg p-3 mb-2">
              <code class="text-green-400 text-sm">
                <span class="text-gray-400"># macOS:</span><br/>
                brew install postgresql<br/><br/>
                <span class="text-gray-400"># Ubuntu:</span><br/>
                sudo apt-get install postgresql
              </code>
            </div>
          </div>

          <!-- Step 2 -->
          <div class="border-l-4 border-green-500 pl-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">2. Remove Demo Mode</h3>
            <div class="bg-gray-900 rounded-lg p-3 mb-2">
              <code class="text-green-400 text-sm">
                rm config/initializers/disable_db_checks.rb
              </code>
            </div>
          </div>

          <!-- Step 3 -->
          <div class="border-l-4 border-yellow-500 pl-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">3. Setup Database</h3>
            <div class="bg-gray-900 rounded-lg p-3 mb-2">
              <code class="text-green-400 text-sm">
                rails db:create
              </code>
            </div>
          </div>

          <!-- Step 4 -->
          <div class="border-l-4 border-purple-500 pl-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">4. Configure Gems (Optional)</h3>
            <div class="bg-gray-900 rounded-lg p-3 mb-2">
              <code class="text-green-400 text-sm">
                <span class="text-gray-400"># Authentication</span><br/>
                rails generate devise:install<br/>
                rails generate devise User<br/><br/>
                <span class="text-gray-400"># Background Jobs</span><br/>
                rails generate good_job:install<br/>
                rails db:migrate
              </code>
            </div>
          </div>

          <!-- Step 5 -->
          <div class="border-l-4 border-red-500 pl-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">5. Start Development</h3>
            <div class="bg-gray-900 rounded-lg p-3 mb-2">
              <code class="text-green-400 text-sm">
                rails server
              </code>
            </div>
          </div>
        </div>
      </div>

      <!-- Tech Stack -->
      <div class="bg-white rounded-xl shadow-lg p-8 mb-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center">
          <span class="text-purple-500 mr-3">🛠️</span>
          Included Tech Stack
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div class="text-center">
            <div class="text-3xl mb-2">⚡</div>
            <h3 class="font-semibold text-gray-900 mb-1">Rails 8.0</h3>
            <p class="text-sm text-gray-600">Modern Ruby framework</p>
          </div>
          <div class="text-center">
            <div class="text-3xl mb-2">🎨</div>
            <h3 class="font-semibold text-gray-900 mb-1">Vue {{ versions.vue }} + Vite {{ versions.vite }}</h3>
            <p class="text-sm text-gray-600">Tailwind {{ versions.tailwind }}</p>
          </div>
          <div class="text-center">
            <div class="text-3xl mb-2">💾</div>
            <h3 class="font-semibold text-gray-900 mb-1">PostgreSQL</h3>
            <p class="text-sm text-gray-600">Robust database</p>
          </div>
          <div class="text-center">
            <div class="text-3xl mb-2">🔐</div>
            <h3 class="font-semibold text-gray-900 mb-1">Devise + Pundit</h3>
            <p class="text-sm text-gray-600">Auth + Authorization</p>
          </div>
          <div class="text-center">
            <div class="text-3xl mb-2">🛡️</div>
            <h3 class="font-semibold text-gray-900 mb-1">Security Gems</h3>
            <p class="text-sm text-gray-600">CSP, Rate limiting, etc.</p>
          </div>
          <div class="text-center">
            <div class="text-3xl mb-2">🚀</div>
            <h3 class="font-semibold text-gray-900 mb-1">Production Ready</h3>
            <p class="text-sm text-gray-600">All gems configured</p>
          </div>
        </div>
      </div>

      <!-- Documentation Links -->
      <div class="bg-white rounded-xl shadow-lg p-8">
        <h2 class="text-2xl font-bold text-gray-900 mb-6 flex items-center">
          <span class="text-indigo-500 mr-3">📚</span>
          Documentation
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <a href="https://github.com/your-repo/README_GEMS_SETUP.md" 
             class="block bg-blue-50 hover:bg-blue-100 p-4 rounded-lg transition-colors">
            <h3 class="font-semibold text-blue-900 mb-1">Gems Setup</h3>
            <p class="text-sm text-blue-700">Detailed gem configuration</p>
          </a>
          <a href="https://github.com/your-repo/README_DEVISE_INTEGRATION.md" 
             class="block bg-green-50 hover:bg-green-100 p-4 rounded-lg transition-colors">
            <h3 class="font-semibold text-green-900 mb-1">Authentication</h3>
            <p class="text-sm text-green-700">Devise integration guide</p>
          </a>
          <a href="https://github.com/your-repo/README_AXIOS_PINIA_SETUP.md" 
             class="block bg-purple-50 hover:bg-purple-100 p-4 rounded-lg transition-colors">
            <h3 class="font-semibold text-purple-900 mb-1">Frontend Setup</h3>
            <p class="text-sm text-purple-700">Axios + Pinia architecture</p>
          </a>
        </div>
      </div>

      <!-- API Response Display -->
      <div v-if="apiResponse" class="bg-white rounded-xl shadow-lg p-8 mt-8">
        <h3 class="text-lg font-semibold mb-4 text-gray-900">API Test Result:</h3>
        <pre class="bg-gray-100 p-4 rounded-lg text-sm overflow-auto">{{ JSON.stringify(apiResponse, null, 2) }}</pre>
      </div>

      <!-- Error Display -->
      <div v-if="api.hasError.value || auth.hasError.value" class="bg-red-50 border border-red-200 rounded-xl p-6 mt-8">
        <h3 class="text-red-800 font-semibold mb-2">Error:</h3>
        <p class="text-red-700 mb-4">{{ api.error.value || auth.error.value }}</p>
        <button 
          @click="clearErrors"
          class="bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-lg"
        >
          Clear Error
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useCounterStore } from '../stores/counter'
import { useApi } from '../composables/useApi'
import { useAuth } from '../composables/useAuth'
import pkg from '../../../package.json'

const counter = useCounterStore()
const api = useApi()
const auth = useAuth()

const apiResponse = ref(null)

// Versions affichées dynamiquement depuis package.json
const versions = {
  vue: pkg.dependencies?.vue || '3',
  vite: pkg.devDependencies?.vite || '5',
  tailwind: pkg.devDependencies?.tailwindcss || '3'
}

const testApiCall = async () => {
  try {
    // Test a simple JSON endpoint provided by Rails at /api/test
    const response = await api.get('/test')
    apiResponse.value = response
  } catch (error) {
    console.log('API error:', error.message)
    apiResponse.value = { error: error.message }
  }
}

const clearErrors = () => {
  api.clearError()
  auth.clearError()
}
</script>