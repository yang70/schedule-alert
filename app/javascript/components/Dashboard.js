export default {
  name: 'Dashboard',
  data() {
    return {
      monitoredUrls: [],
      recentSnapshots: [],
      loading: true,
      newUrl: {
        name: '',
        url: '',
        notification_email: '',
        tournament_start_date: ''
      }
    }
  },
  mounted() {
    this.loadData()
  },
  methods: {
    async loadData() {
      try {
        const response = await fetch('/monitored_urls.json')
        const data = await response.json()
        this.monitoredUrls = data.monitored_urls || []
        this.recentSnapshots = data.recent_snapshots || []
        this.loading = false
      } catch (error) {
        console.error('Error loading data:', error)
        this.loading = false
      }
    },
    async addUrl() {
      if (!this.newUrl.name || !this.newUrl.url || !this.newUrl.tournament_start_date) {
        alert('Please fill in name, URL, and tournament start date')
        return
      }

      try {
        const response = await fetch('/monitored_urls', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          },
          body: JSON.stringify({ monitored_url: this.newUrl })
        })

        if (response.ok) {
          this.newUrl = { name: '', url: '', notification_email: '', tournament_start_date: '' }
          this.loadData()
          alert('URL added successfully!')
        } else {
          alert('Failed to add URL')
        }
      } catch (error) {
        console.error('Error adding URL:', error)
        alert('Error adding URL')
      }
    },
    async removeUrl(id) {
      if (!confirm('Are you sure you want to remove this URL?')) return

      try {
        const response = await fetch(`/monitored_urls/${id}`, {
          method: 'DELETE',
          headers: {
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        })

        if (response.ok) {
          this.loadData()
        } else {
          alert('Failed to remove URL')
        }
      } catch (error) {
        console.error('Error removing URL:', error)
        alert('Error removing URL')
      }
    },
    async checkNow(id) {
      try {
        const response = await fetch(`/monitored_urls/${id}/check_now`, {
          method: 'POST',
          headers: {
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        })

        if (response.ok) {
          alert('Checking URL now...')
        } else {
          alert('Failed to check URL')
        }
      } catch (error) {
        console.error('Error checking URL:', error)
        alert('Error checking URL')
      }
    },
    formatDate(dateString) {
      if (!dateString) return 'Never'
      return new Date(dateString).toLocaleString()
    },
    formatSimpleDate(dateString) {
      if (!dateString) return 'Not set'
      return new Date(dateString).toLocaleDateString()
    },
    daysUntilTournament(tournamentDate) {
      if (!tournamentDate) return null
      const today = new Date()
      today.setHours(0, 0, 0, 0)
      const tournament = new Date(tournamentDate)
      tournament.setHours(0, 0, 0, 0)
      const diffTime = tournament - today
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))
      return diffDays
    },
    getCheckFrequency(tournamentDate) {
      const days = this.daysUntilTournament(tournamentDate)
      if (days === null || days < 0) return 'Not scheduled'
      if (days <= 1) return '5x daily (9am, 12pm, 3pm, 6pm, 10pm PT)'
      if (days <= 4) return '4x daily (9am, 12pm, 5pm, 10pm PT)'
      if (days <= 7) return '3x daily (9am, 3pm, 10pm PT)'
      if (days <= 13) return '2x daily (10am, 10pm PT)'
      return 'Once daily (10am PT)'
    }
  },
  template: `
    <div>
      <!-- Add New URL Form -->
      <div class="add-url-form">
        <h2>➕ Add New Schedule to Monitor</h2>
        <form @submit.prevent="addUrl">
          <div class="form-group">
            <label>Name/Description</label>
            <input v-model="newUrl.name" type="text" placeholder="e.g., Spring Tournament 2026" required>
          </div>
          <div class="form-group">
            <label>Tournament URL</label>
            <input v-model="newUrl.url" type="url" placeholder="https://..." required>
          </div>
          <div class="form-group">
            <label>Tournament Start Date <span style="color: var(--accent-color);">*</span></label>
            <input v-model="newUrl.tournament_start_date" type="date" required>
            <small style="font-size: 0.75rem; color: var(--text-secondary); display: block; margin-top: 0.25rem;">
              Check frequency adjusts automatically based on proximity
            </small>
          </div>
          <div class="form-group">
            <label>Notification Email <span style="font-size: 0.75rem; color: var(--text-light);">(optional)</span></label>
            <input v-model="newUrl.notification_email" type="email" placeholder="Leave empty to use account email">
          </div>
          <button type="submit" class="btn-primary">Add Schedule</button>
        </form>
      </div>

      <!-- Loading State -->
      <div v-if="loading" style="text-align: center; padding: 3rem;">
        <div style="display: inline-block; width: 3rem; height: 3rem; border: 3px solid var(--border-color); border-top-color: var(--primary-color); border-radius: 50%; animation: spin 0.8s linear infinite;"></div>
      </div>

      <!-- URLs List -->
      <div v-else>
        <div v-if="monitoredUrls.length === 0" class="alert alert-info">
          <i class="bi bi-info-circle"></i> No schedules are being monitored yet. Add one above to get started!
        </div>

        <div v-for="url in monitoredUrls" :key="url.id" class="url-card">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 1rem;">
            <div style="flex: 1;">
              <div class="url-title">{{ url.name }}</div>
              <a :href="url.url" target="_blank" rel="noopener" class="url-link">
                <i class="bi bi-link-45deg"></i> {{ url.url }}
              </a>

              <div class="url-meta">
                <div class="meta-item">
                  <i class="bi bi-calendar-event"></i>
                  <span>{{ formatSimpleDate(url.tournament_start_date) }}</span>
                  <span v-if="daysUntilTournament(url.tournament_start_date) !== null && daysUntilTournament(url.tournament_start_date) >= 0" class="badge badge-primary" style="margin-left: 0.5rem;">
                    {{ daysUntilTournament(url.tournament_start_date) }} days away
                  </span>
                  <span v-else-if="daysUntilTournament(url.tournament_start_date) < 0" style="margin-left: 0.5rem; color: var(--text-light); font-size: 0.75rem;">
                    (Past)
                  </span>
                </div>
              </div>

              <div style="margin-top: 0.75rem; padding: 0.75rem; background: var(--bg-color); border-radius: var(--radius-sm); font-size: 0.875rem;">
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                  <i class="bi bi-clock"></i>
                  <strong>Check Frequency:</strong>
                  <span style="color: var(--primary-color);">{{ getCheckFrequency(url.tournament_start_date) }}</span>
                </div>
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                  <i class="bi bi-arrow-clockwise"></i>
                  <strong>Next Check:</strong>
                  <span>{{ formatDate(url.next_check_at) }}</span>
                </div>
                <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                  <i class="bi bi-check-circle"></i>
                  <strong>Last Checked:</strong>
                  <span>{{ formatDate(url.last_checked_at) }}</span>
                </div>
                <div style="display: flex; align-items: center; gap: 0.5rem;">
                  <i class="bi bi-file-text"></i>
                  <strong>Status:</strong>
                  <span v-if="url.schedule_available" class="badge badge-success">Schedule Available</span>
                  <span v-else class="badge badge-warning">Waiting for Schedule</span>
                </div>
                <div v-if="url.notification_email" style="display: flex; align-items: center; gap: 0.5rem; margin-top: 0.5rem;">
                  <i class="bi bi-envelope"></i>
                  <strong>Notifications:</strong>
                  <span>{{ url.notification_email }}</span>
                </div>
              </div>
            </div>

            <div style="display: flex; flex-direction: column; gap: 0.5rem;">
              <button @click="checkNow(url.id)" class="btn-outline-primary" style="white-space: nowrap; padding: 0.5rem 1rem;">
                <i class="bi bi-arrow-repeat"></i> Check Now
              </button>
              <button @click="removeUrl(url.id)" class="btn-danger" style="white-space: nowrap; padding: 0.5rem 1rem;">
                <i class="bi bi-trash"></i> Remove
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Recent Changes -->
      <div v-if="recentSnapshots.length > 0" style="margin-top: 3rem;">
        <div style="background: var(--card-bg); border-radius: var(--radius-lg); padding: 2rem; box-shadow: var(--shadow-sm);">
          <h2 style="font-size: 1.5rem; font-weight: 600; margin-bottom: 1.5rem;">
            <i class="bi bi-clock-history"></i> Recent Schedule Changes
          </h2>
          <div v-for="snapshot in recentSnapshots" :key="snapshot.id" style="padding: 1rem; margin-bottom: 1rem; background: var(--bg-color); border-radius: var(--radius-md); border-left: 4px solid var(--accent-color);">
            <div style="font-size: 0.875rem; color: var(--text-secondary); margin-bottom: 0.5rem;">
              <i class="bi bi-calendar3"></i> {{ formatDate(snapshot.checked_at) }}
            </div>
            <div style="color: var(--text-primary);">{{ snapshot.ai_summary }}</div>
          </div>
        </div>
      </div>
    </div>
  `
}
