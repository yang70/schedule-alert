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
    <div class="container mt-4">
      <div class="row">
        <div class="col-12">
          <h2>My Monitored URLs</h2>

          <!-- Add New URL Form -->
          <div class="card mb-4">
            <div class="card-header">
              <h5>Add New URL to Monitor</h5>
            </div>
            <div class="card-body">
              <form @submit.prevent="addUrl">
                <div class="mb-3">
                  <label class="form-label">Name/Description</label>
                  <input v-model="newUrl.name" type="text" class="form-control" placeholder="e.g., Spring Tournament 2026" required>
                </div>
                <div class="mb-3">
                  <label class="form-label">URL</label>
                  <input v-model="newUrl.url" type="url" class="form-control" placeholder="https://..." required>
                </div>
                <div class="mb-3">
                  <label class="form-label">Tournament Start Date <span class="text-danger">*</span></label>
                  <input v-model="newUrl.tournament_start_date" type="date" class="form-control" required>
                  <small class="form-text text-muted">
                    Check frequency adjusts automatically based on how soon the tournament is
                  </small>
                </div>
                <div class="mb-3">
                  <label class="form-label">Notification Email (optional)</label>
                  <input v-model="newUrl.notification_email" type="email" class="form-control" placeholder="Leave empty to use account email">
                </div>
                <button type="submit" class="btn btn-primary">Add URL</button>
              </form>
            </div>
          </div>

          <!-- Loading State -->
          <div v-if="loading" class="text-center">
            <div class="spinner-border" role="status">
              <span class="visually-hidden">Loading...</span>
            </div>
          </div>

          <!-- URLs List -->
          <div v-else>
            <div v-if="monitoredUrls.length === 0" class="alert alert-info">
              No URLs are being monitored yet. Add one above to get started!
            </div>

            <div v-for="url in monitoredUrls" :key="url.id" class="card mb-3">
              <div class="card-body">
                <div class="d-flex justify-content-between align-items-start">
                  <div>
                    <h5 class="card-title">{{ url.name }}</h5>
                    <p class="card-text">
                      <a :href="url.url" target="_blank" rel="noopener">{{ url.url }}</a>
                    </p>
                    <p class="text-muted small mb-0">
                      <strong>Tournament Date:</strong> {{ formatSimpleDate(url.tournament_start_date) }}
                      <span v-if="daysUntilTournament(url.tournament_start_date) !== null && daysUntilTournament(url.tournament_start_date) >= 0" class="badge bg-info ms-2">
                        {{ daysUntilTournament(url.tournament_start_date) }} days away
                      </span>
                      <span v-else-if="daysUntilTournament(url.tournament_start_date) < 0" class="badge bg-secondary ms-2">
                        Past
                      </span>
                    </p>
                    <p class="text-muted small mb-0">
                      <strong>Check Frequency:</strong> {{ getCheckFrequency(url.tournament_start_date) }}
                    </p>
                    <p class="text-muted small mb-0">
                      <strong>Next Check:</strong> {{ formatDate(url.next_check_at) }}
                    </p>
                    <p class="text-muted small mb-0">
                      <strong>Status:</strong>
                      <span v-if="url.schedule_available" class="badge bg-success">Schedule Available</span>
                      <span v-else class="badge bg-warning">Waiting for Schedule</span>
                    </p>
                    <p class="text-muted small mb-0">
                      <strong>Last Checked:</strong> {{ formatDate(url.last_checked_at) }}
                    </p>
                    <p class="text-muted small mb-0" v-if="url.notification_email">
                      <strong>Notifications to:</strong> {{ url.notification_email }}
                    </p>
                  </div>
                  <div class="btn-group">
                    <button @click="checkNow(url.id)" class="btn btn-sm btn-outline-primary">
                      Check Now
                    </button>
                    <button @click="removeUrl(url.id)" class="btn btn-sm btn-outline-danger">
                      Remove
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Recent Changes -->
          <div v-if="recentSnapshots.length > 0" class="mt-5">
            <h3>Recent Schedule Changes</h3>
            <div v-for="snapshot in recentSnapshots" :key="snapshot.id" class="card mb-3">
              <div class="card-body">
                <h6 class="card-subtitle mb-2 text-muted">
                  {{ formatDate(snapshot.checked_at) }}
                </h6>
                <p class="card-text">{{ snapshot.ai_summary }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  `
}
