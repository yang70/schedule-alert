// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"
import { createApp } from 'vue'
import Dashboard from './components/Dashboard.js'

// Initialize Vue components
function initializeVue() {
  // Dashboard component
  const dashboardElement = document.getElementById('dashboard-app')
  if (dashboardElement) {
    // Check if already mounted
    if (!dashboardElement.hasAttribute('data-vue-mounted')) {
      const app = createApp(Dashboard)
      app.mount('#dashboard-app')
      dashboardElement.setAttribute('data-vue-mounted', 'true')
    }
  }
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', initializeVue)

// Initialize on Turbo navigation (for Hotwire/Turbo)
document.addEventListener('turbo:load', initializeVue)
