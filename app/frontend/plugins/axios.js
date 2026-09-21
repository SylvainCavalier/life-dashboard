// Axios configuration for Rails integration
import axios from 'axios'

// Create axios instance with base configuration
const apiClient = axios.create({
  baseURL: '/api',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  }
})

// Get CSRF token from Rails meta tag
function getCSRFToken() {
  const token = document.querySelector('meta[name="csrf-token"]')
  return token ? token.getAttribute('content') : null
}

// Request interceptor - add CSRF token to all requests
apiClient.interceptors.request.use(
  (config) => {
    // Add CSRF token for Rails
    const csrfToken = getCSRFToken()
    if (csrfToken) {
      config.headers['X-CSRF-Token'] = csrfToken
    }

    // Uniquement en dev : en production ces logs deverseraient le contenu des
    // reponses (IBAN, profil sante, mots de passe reveles) dans la console.
    if (import.meta.env.DEV) {
      console.log(`🚀 ${config.method?.toUpperCase()} ${config.url}`, config.data || config.params)
    }
    return config
  },
  (error) => {
    console.error('❌ Request error:', error)
    return Promise.reject(error)
  }
)

// Response interceptor - handle common responses
apiClient.interceptors.response.use(
  (response) => {
    if (import.meta.env.DEV) {
      console.log(`✅ ${response.config.method?.toUpperCase()} ${response.config.url}`, response.data)
    }
    return response
  },
  (error) => {
    console.error('❌ Response error:', import.meta.env.DEV ? (error.response?.data || error.message) : error.message)
    
    // Handle common HTTP errors
    if (error.response) {
      switch (error.response.status) {
        case 401:
          // Session Devise expiree ou absente : retour a la page de connexion.
          if (window.location.pathname !== '/users/sign_in') {
            window.location.href = '/users/sign_in'
          }
          break
        case 403:
          // Forbidden
          console.warn('Access forbidden:', error.response.data)
          break
        case 422:
          // Validation errors (Rails standard)
          console.warn('Validation errors:', error.response.data)
          break
        case 500:
          // Server error
          console.error('Server error:', error.response.data)
          break
      }
    } else if (error.request) {
      // Network error
      console.error('Network error - check your connection')
    }
    
    return Promise.reject(error)
  }
)

// Create a simple client for non-API requests (Rails forms, etc.)
const railsClient = axios.create({
  timeout: 10000,
  headers: {
    'Content-Type': 'application/x-www-form-urlencoded',
    'Accept': 'text/html,application/xhtml+xml'
  }
})

// Add CSRF token to Rails client too
railsClient.interceptors.request.use((config) => {
  const csrfToken = getCSRFToken()
  if (csrfToken) {
    config.headers['X-CSRF-Token'] = csrfToken
  }
  return config
})

export { apiClient, railsClient }
export default apiClient
