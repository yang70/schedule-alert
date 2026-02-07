// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"
import { createApp } from 'vue'
import Dashboard from './components/Dashboard.js'

// Initialize Vue components on page load
document.addEventListener('DOMContentLoaded', () => {
  // Dashboard component
  const dashboardElement = document.getElementById('dashboard-app')
  if (dashboardElement) {
    const app = createApp(Dashboard)
    app.mount('#dashboard-app')
  }
})
