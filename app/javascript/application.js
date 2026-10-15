// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"
import "./controllers"
import * as bootstrap from "bootstrap"
import { createApp } from 'vue'
import Dashboard from './components/Dashboard.vue'

let dashboardApp = null

function initializeVue() {
  const element = document.getElementById('dashboard-app')
  if (element && !dashboardApp) {
    dashboardApp = createApp(Dashboard)
    dashboardApp.mount(element)
  }
}

document.addEventListener('turbo:before-cache', () => {
  dashboardApp?.unmount()
  dashboardApp = null
})
document.addEventListener('turbo:load', initializeVue)
document.addEventListener('DOMContentLoaded', initializeVue)
