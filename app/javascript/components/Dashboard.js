export default {
  name: 'Dashboard',
  data() {
    return {
      monitoredUrls: [],
      recentSnapshots: [],
      people: [],
      loading: true,
      formCollapsed: true,
      pastCollapsed: true,
      collapsedCards: {},
      showSuccessBanner: false,
      showPersonModal: false,
      deleteConfirmation: {
        show: false,
        urlId: null,
        urlName: ''
      },
      editMode: {
        active: false,
        urlId: null
      },
      newUrl: {
        name: '',
        url: '',
        notification_email: '',
        tournament_start_date: '',
        person_id: '',
        sport: ''
      },
      editUrl: {
        name: '',
        url: '',
        notification_email: '',
        tournament_start_date: '',
        person_id: '',
        sport: ''
      },
      newPerson: {
        name: '',
        color: '#3B82F6'
      }
    }
  },
  computed: {
    upcomingUrls() {
      return this.monitoredUrls.filter(url => {
        const days = this.daysUntilTournament(url.tournament_start_date)
        return days === null || days >= 0
      }).sort((a, b) => {
        // Sort by tournament date, closest first
        if (!a.tournament_start_date && !b.tournament_start_date) return 0
        if (!a.tournament_start_date) return 1
        if (!b.tournament_start_date) return -1
        return new Date(a.tournament_start_date) - new Date(b.tournament_start_date)
      })
    },
    pastUrls() {
      return this.monitoredUrls.filter(url => {
        const days = this.daysUntilTournament(url.tournament_start_date)
        return days !== null && days < 0
      })
    }
  },
  mounted() {
    this.loadData()
  },
  methods: {
    toggleCardCollapse(urlId) {
      this.collapsedCards[urlId] = !this.collapsedCards[urlId]
    },
    isCardCollapsed(urlId) {
      return this.collapsedCards[urlId] !== false
    },
    async loadData() {
      try {
        const [urlsResponse, peopleResponse] = await Promise.all([
          fetch('/monitored_urls.json'),
          fetch('/people.json')
        ])
        
        const urlsData = await urlsResponse.json()
        this.monitoredUrls = urlsData.monitored_urls || []
        this.recentSnapshots = urlsData.recent_snapshots || []

        const peopleData = await peopleResponse.json()
        this.people = peopleData || []

        // Initialize all cards as collapsed
        this.monitoredUrls.forEach(url => {
          if (this.collapsedCards[url.id] === undefined) {
            this.collapsedCards[url.id] = true
          }
        })

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
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          },
          body: JSON.stringify({ monitored_url: this.newUrl })
        })

        if (response.ok) {
          this.newUrl = { name: '', url: '', notification_email: '', tournament_start_date: '', person_id: '', sport: '' }
          this.loadData()
          this.formCollapsed = true
          this.showSuccessBanner = true
          setTimeout(() => {
            this.showSuccessBanner = false
          }, 5000)
        } else {
          alert('Failed to add URL')
        }
      } catch (error) {
        console.error('Error adding URL:', error)
        alert('Error adding URL')
      }
    },
    removeUrl(id) {
      const url = this.monitoredUrls.find(u => u.id === id)
      this.deleteConfirmation = {
        show: true,
        urlId: id,
        urlName: url ? url.name : ''
      }
    },
    async confirmDelete() {
      const id = this.deleteConfirmation.urlId
      this.deleteConfirmation.show = false

      try {
        const response = await fetch(`/monitored_urls/${id}`, {
          method: 'DELETE',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
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
    cancelDelete() {
      this.deleteConfirmation = {
        show: false,
        urlId: null,
        urlName: ''
      }
    },
    startEdit(url) {
      this.editMode = {
        active: true,
        urlId: url.id
      }
      this.editUrl = {
        name: url.name,
        url: url.url,
        notification_email: url.notification_email || '',
        tournament_start_date: url.tournament_start_date,
        person_id: url.person ? url.person.id : '',
        sport: url.sport || ''
      }
    },
    cancelEdit() {
      this.editMode = {
        active: false,
        urlId: null
      }
      this.editUrl = {
        name: '',
        url: '',
        notification_email: '',
        tournament_start_date: '',
        person_id: '',
        sport: ''
      }
    },
    async saveEdit() {
      const id = this.editMode.urlId
      try {
        const response = await fetch(`/monitored_urls/${id}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          },
          body: JSON.stringify({ monitored_url: this.editUrl })
        })

        if (response.ok) {
          this.loadData()
          this.cancelEdit()
        } else {
          alert('Failed to update URL')
        }
      } catch (error) {
        console.error('Error updating URL:', error)
        alert('Error updating URL')
      }
    },
    openPersonModal() {
      this.showPersonModal = true
    },
    closePersonModal() {
      this.showPersonModal = false
      this.newPerson = { name: '', color: '#3B82F6' }
    },
    async createPerson() {
      if (!this.newPerson.name) {
        alert('Please enter a person name')
        return
      }

      try {
        const response = await fetch('/people', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          },
          body: JSON.stringify({ person: this.newPerson })
        })

        if (response.ok) {
          const person = await response.json()
          this.people.push(person)
          this.closePersonModal()
        } else {
          const errorData = await response.json()
          alert(errorData.errors ? errorData.errors.join(', ') : 'Failed to create person')
        }
      } catch (error) {
        console.error('Error creating person:', error)
        alert('Error creating person')
      }
    },
    getSportIcon(sport) {
      // Note: Bootstrap Icons doesn't have specific sport icons, so we'll show emoji/text instead
      return null
    },
    getSportEmoji(sport) {
      if (sport === 'baseball') return '⚾'
      if (sport === 'softball') return '🥎'
      if (sport === 'volleyball') return '🏐'
      return ''
    },
    async checkNow(id) {
      try {
        const response = await fetch(`/monitored_urls/${id}/check_now`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        })

        if (response.ok) {
          // Success - silently refresh
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
      <!-- Delete Confirmation Modal -->
      <div v-if="deleteConfirmation.show" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 1000;" @click.self="cancelDelete">
        <div style="background: white; border-radius: var(--radius-lg); padding: 2rem; max-width: 500px; box-shadow: var(--shadow-lg);">
          <h3 style="margin: 0 0 1rem 0; color: var(--text-primary);">
            <i class="bi bi-exclamation-triangle" style="color: var(--accent-color);"></i> Confirm Deletion
          </h3>
          <p style="color: var(--text-secondary); margin-bottom: 1.5rem;">
            Are you sure you want to remove <strong>{{ deleteConfirmation.urlName }}</strong>? This action cannot be undone.
          </p>
          <div style="display: flex; gap: 1rem; justify-content: flex-end;">
            <button @click="cancelDelete" class="btn-outline-primary" style="padding: 0.5rem 1.5rem;">
              Cancel
            </button>
            <button @click="confirmDelete" class="btn-danger" style="padding: 0.5rem 1.5rem;">
              <i class="bi bi-trash"></i> Delete
            </button>
          </div>
        </div>
      </div>

      <!-- Create Person Modal -->
      <div v-if="showPersonModal" style="position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 1000;" @click.self="closePersonModal">
        <div style="background: white; border-radius: var(--radius-lg); padding: 2rem; max-width: 500px; width: 90%; box-shadow: var(--shadow-lg);">
          <h3 style="margin: 0 0 1.5rem 0; color: var(--text-primary);">
            <i class="bi bi-person-plus"></i> Create New Person
          </h3>
          <div style="margin-bottom: 1.5rem;">
            <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Person Name <span style="color: var(--accent-color);">*</span></label>
            <input v-model="newPerson.name" type="text" placeholder="e.g., John, Sarah's Team" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
          </div>
          <div style="margin-bottom: 1.5rem;">
            <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Color</label>
            <div style="display: flex; gap: 0.75rem; align-items: center;">
              <input v-model="newPerson.color" type="color" style="width: 80px; height: 40px; border: 1px solid var(--border-color); border-radius: var(--radius-sm); cursor: pointer;">
              <span style="color: var(--text-secondary); font-size: 0.875rem;">{{ newPerson.color }}</span>
              <div :style="`flex: 1; padding: 0.5rem 1rem; background-color: ${newPerson.color}; color: white; border-radius: var(--radius-sm); text-align: center; font-size: 0.875rem; font-weight: 500;`">
                Preview
              </div>
            </div>
          </div>
          <div style="display: flex; gap: 1rem; justify-content: flex-end;">
            <button @click="closePersonModal" class="btn-outline-primary" style="padding: 0.5rem 1.5rem;">
              Cancel
            </button>
            <button @click="createPerson" class="btn-primary" style="padding: 0.5rem 1.5rem;">
              <i class="bi bi-plus-circle"></i> Create Person
            </button>
          </div>
        </div>
      </div>

      <!-- Success Banner -->
      <transition name="fade">
        <div v-if="showSuccessBanner" style="position: fixed; top: 20px; right: 20px; background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 1rem 1.5rem; border-radius: var(--radius-md); box-shadow: 0 10px 25px rgba(16, 185, 129, 0.3); z-index: 1001; display: flex; align-items: center; gap: 0.75rem; animation: slideIn 0.3s ease-out;">
          <i class="bi bi-check-circle-fill" style="font-size: 1.5rem;"></i>
          <div>
            <div style="font-weight: 600; margin-bottom: 0.125rem;">Schedule Added!</div>
            <div style="font-size: 0.875rem; opacity: 0.95;">Monitoring will begin shortly</div>
          </div>
        </div>
      </transition>

      <!-- Add New URL Form -->
      <div class="add-url-form">
        <div style="display: flex; justify-content: space-between; align-items: center; cursor: pointer;" @click="formCollapsed = !formCollapsed">
          <h2 style="margin: 0;">➕ Add New Schedule to Monitor</h2>
          <i :class="formCollapsed ? 'bi bi-chevron-down' : 'bi bi-chevron-up'" style="font-size: 1.5rem; color: var(--primary-color);"></i>
        </div>
        <form v-show="!formCollapsed" @submit.prevent="addUrl" style="margin-top: 1.5rem; padding: 1.5rem; background: var(--bg-color); border-radius: var(--radius-md);">
          <div style="display: grid; gap: 1rem;">
            <div class="form-group" style="margin-bottom: 0;">
              <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Name/Description <span style="color: var(--accent-color);">*</span></label>
              <input v-model="newUrl.name" type="text" placeholder="e.g., Spring Tournament 2026" required style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
            </div>
            <div class="form-group" style="margin-bottom: 0;">
              <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Tournament URL <span style="color: var(--accent-color);">*</span></label>
              <input v-model="newUrl.url" type="url" placeholder="https://..." required style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
            </div>
            <div class="form-group" style="margin-bottom: 0;">
              <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Tournament Start Date <span style="color: var(--accent-color);">*</span></label>
              <input v-model="newUrl.tournament_start_date" type="date" required style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
              <small style="font-size: 0.75rem; color: var(--text-secondary); display: block; margin-top: 0.5rem;">
                <i class="bi bi-info-circle"></i> Check frequency adjusts automatically based on proximity
              </small>
            </div>
            <div class="form-group" style="margin-bottom: 0;">
              <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Player/Person Tag <span style="font-size: 0.875rem; color: var(--text-light); font-weight: 400;">(optional)</span></label>
              <div style="display: flex; gap: 0.5rem;">
                <select v-model="newUrl.person_id" style="flex: 1; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; background: white; cursor: pointer; transition: border-color 0.2s;">
                  <option value="">Select a person</option>
                  <option v-for="person in people" :key="person.id" :value="person.id">{{ person.name }}</option>
                </select>
                <button @click="openPersonModal" type="button" style="padding: 0.75rem 1rem; background: var(--primary-color); color: white; border: none; border-radius: var(--radius-sm); font-size: 0.875rem; font-weight: 500; cursor: pointer; white-space: nowrap; transition: opacity 0.2s;" @mouseover="$event.target.style.opacity='0.9'" @mouseout="$event.target.style.opacity='1'">
                  <i class="bi bi-plus-circle"></i> New Person
                </button>
              </div>
            </div>
            <div class="form-group" style="margin-bottom: 0;">
              <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Sport <span style="font-size: 0.875rem; color: var(--text-light); font-weight: 400;">(optional)</span></label>
              <select v-model="newUrl.sport" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; background: white; cursor: pointer; transition: border-color 0.2s;">
                <option value="">Select a sport</option>
                <option value="baseball">⚾ Baseball</option>
                <option value="softball">🥎 Softball</option>
                <option value="volleyball">🏐 Volleyball</option>
              </select>
            </div>
            <div class="form-group" style="margin-bottom: 0;">
              <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Notification Email <span style="font-size: 0.875rem; color: var(--text-light); font-weight: 400;">(optional)</span></label>
              <input v-model="newUrl.notification_email" type="email" placeholder="Leave empty to use account email" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
            </div>
          </div>
          <button type="submit" class="btn-primary" style="margin-top: 1.5rem; padding: 0.75rem 1.5rem; width: 100%; font-weight: 600;">
            <i class="bi bi-plus-circle"></i> Add Schedule
          </button>
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

        <!-- Upcoming Tournaments -->
        <div v-if="upcomingUrls.length > 0" style="margin-top: 2rem;">
          <h2 style="font-size: 1.5rem; font-weight: 600; margin-bottom: 1.5rem; color: var(--primary-color);">
            <i class="bi bi-calendar-check"></i> Upcoming Tournaments ({{ upcomingUrls.length }})
          </h2>
          <div v-for="url in upcomingUrls" :key="url.id" class="url-card">
            <!-- Edit Mode -->
            <div v-if="editMode.active && editMode.urlId === url.id" style="padding: 1.5rem; background: var(--bg-color); border-radius: var(--radius-md);">
              <h3 style="margin: 0 0 1.5rem 0; color: var(--primary-color); font-size: 1.25rem; font-weight: 600;">
                <i class="bi bi-pencil"></i> Edit Schedule
              </h3>
              <div style="display: grid; gap: 1rem;">
                <div class="form-group" style="margin-bottom: 0;">
                  <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Name/Description <span style="color: var(--accent-color);">*</span></label>
                  <input v-model="editUrl.name" type="text" required style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                  <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Tournament URL <span style="color: var(--accent-color);">*</span></label>
                  <input v-model="editUrl.url" type="url" required style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                  <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Tournament Start Date <span style="color: var(--accent-color);">*</span></label>
                  <input v-model="editUrl.tournament_start_date" type="date" required style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                  <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Player/Person Tag <span style="font-size: 0.875rem; color: var(--text-light); font-weight: 400;">(optional)</span></label>
                  <div style="display: flex; gap: 0.5rem;">
                    <select v-model="editUrl.person_id" style="flex: 1; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; background: white; cursor: pointer; transition: border-color 0.2s;">
                      <option value="">Select a person</option>
                      <option v-for="person in people" :key="person.id" :value="person.id">{{ person.name }}</option>
                    </select>
                    <button @click="openPersonModal" type="button" style="padding: 0.75rem 1rem; background: var(--primary-color); color: white; border: none; border-radius: var(--radius-sm); font-size: 0.875rem; font-weight: 500; cursor: pointer; white-space: nowrap; transition: opacity 0.2s;" @mouseover="$event.target.style.opacity='0.9'" @mouseout="$event.target.style.opacity='1'">
                      <i class="bi bi-plus-circle"></i> New Person
                    </button>
                  </div>
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                  <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Sport <span style="font-size: 0.875rem; color: var(--text-light); font-weight: 400;">(optional)</span></label>
                  <select v-model="editUrl.sport" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; background: white; cursor: pointer; transition: border-color 0.2s;">
                    <option value="">Select a sport</option>
                    <option value="baseball">⚾ Baseball</option>
                    <option value="softball">🥎 Softball</option>
                    <option value="volleyball">🏐 Volleyball</option>
                  </select>
                </div>
                <div class="form-group" style="margin-bottom: 0;">
                  <label style="display: block; margin-bottom: 0.5rem; font-weight: 500; color: var(--text-primary);">Notification Email <span style="font-size: 0.875rem; color: var(--text-light); font-weight: 400;">(optional)</span></label>
                  <input v-model="editUrl.notification_email" type="email" placeholder="Leave empty to use account email" style="width: 100%; padding: 0.75rem; border: 1px solid var(--border-color); border-radius: var(--radius-sm); font-size: 1rem; transition: border-color 0.2s;">
                </div>
              </div>
              <div style="display: flex; gap: 0.75rem; margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid var(--border-color);">
                <button @click="saveEdit" class="btn-primary" style="flex: 1; padding: 0.75rem 1.5rem; font-weight: 600;">
                  <i class="bi bi-check-lg"></i> Save Changes
                </button>
                <button @click="cancelEdit" class="btn-outline-primary" style="padding: 0.75rem 1.5rem;">
                  <i class="bi bi-x-lg"></i> Cancel
                </button>
              </div>
            </div>

            <!-- Display Mode -->
            <div v-else>
              <!-- Collapsed Header (always visible) -->
              <div style="display: flex; justify-content: space-between; align-items: center; gap: 1rem; cursor: pointer;" @click="toggleCardCollapse(url.id)">
                <div style="flex: 1; min-width: 0;">
                  <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                    <span v-if="url.sport" style="font-size: 1.5rem;">{{ getSportEmoji(url.sport) }}</span>
                    <div class="url-title" style="flex: 1; min-width: 0;">{{ url.name }}</div>
                    <i :class="isCardCollapsed(url.id) ? 'bi-chevron-down' : 'bi-chevron-up'" class="bi" style="color: var(--text-secondary); font-size: 1.25rem; transition: transform 0.2s;"></i>
                  </div>
                  <div style="display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap;">
                    <span v-if="url.person" :style="`display: inline-flex; align-items: center; gap: 0.25rem; padding: 0.25rem 0.75rem; background-color: ${url.person.color}; color: white; border-radius: 9999px; font-size: 0.75rem; font-weight: 500;`">
                      <i class="bi bi-person-fill"></i> {{ url.person.name }}
                    </span>
                    <span style="color: var(--text-secondary); font-size: 0.875rem;">
                      <i class="bi bi-calendar-event" style="margin-right: 0.25rem;"></i>{{ formatSimpleDate(url.tournament_start_date) }}
                    </span>
                    <span v-if="daysUntilTournament(url.tournament_start_date) !== null && daysUntilTournament(url.tournament_start_date) >= 0" class="badge badge-primary" style="font-size: 0.75rem; font-weight: 500;">
                      {{ daysUntilTournament(url.tournament_start_date) }} days away
                    </span>
                  </div>
                </div>
              </div>

              <!-- Expanded Content -->
              <div v-if="!isCardCollapsed(url.id)" style="margin-top: 1.25rem; padding-top: 1.25rem; border-top: 1px solid rgba(0, 0, 0, 0.08);">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 1.5rem;">
                  <div style="flex: 1;">
                    <a :href="url.url" target="_blank" rel="noopener" style="display: inline-block; margin-bottom: 1.25rem; padding: 0.5rem 1rem; background: var(--primary-color); color: white; text-decoration: none; border-radius: var(--radius-sm); font-size: 0.875rem; font-weight: 500; transition: all 0.2s;" @mouseover="$event.target.style.opacity='0.9'" @mouseout="$event.target.style.opacity='1'" @click.stop>
                      <i class="bi bi-link-45deg"></i> Link to schedule
                    </a>

                    <div style="border-top: 1px solid rgba(0, 0, 0, 0.08); padding-top: 1rem;">
                      <div style="display: grid; gap: 0.625rem; font-size: 0.875rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Check Frequency</span>
                          <span style="color: var(--primary-color); font-weight: 500;">{{ getCheckFrequency(url.tournament_start_date) }}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Next Check</span>
                          <span style="color: var(--text-color); font-weight: 400;">{{ formatDate(url.next_check_at) }}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Last Checked</span>
                          <span style="color: var(--text-color); font-weight: 400;">{{ formatDate(url.last_checked_at) }}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Status</span>
                          <span v-if="url.schedule_available" class="badge badge-success" style="font-weight: 500;">Schedule Available</span>
                          <span v-else class="badge badge-warning" style="font-weight: 500;">Waiting for Schedule</span>
                        </div>
                        <div v-if="url.notification_email" style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Notifications</span>
                          <span style="color: var(--text-color); font-weight: 400; font-size: 0.8125rem;">{{ url.notification_email }}</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                    <button @click.stop="checkNow(url.id)" class="btn-outline-primary" style="white-space: nowrap; padding: 0.5rem 1rem;">
                      <i class="bi bi-arrow-repeat"></i> Check Now
                    </button>
                    <button @click.stop="startEdit(url)" class="btn-outline-primary" style="white-space: nowrap; padding: 0.5rem 1rem;">
                      <i class="bi bi-pencil"></i> Edit
                    </button>
                    <button @click.stop="removeUrl(url.id)" class="btn-danger" style="white-space: nowrap; padding: 0.5rem 1rem;">
                      <i class="bi bi-trash"></i> Remove
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Past Tournaments -->
        <div v-if="pastUrls.length > 0" style="margin-top: 2rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; cursor: pointer; margin-bottom: 1.5rem;" @click="pastCollapsed = !pastCollapsed">
            <h2 style="margin: 0; font-size: 1.5rem; font-weight: 600; color: var(--text-secondary);">
              <i class="bi bi-calendar-x"></i> Past Tournaments ({{ pastUrls.length }})
            </h2>
            <i :class="pastCollapsed ? 'bi bi-chevron-down' : 'bi bi-chevron-up'" style="font-size: 1.5rem; color: var(--text-secondary);"></i>
          </div>
          <div v-show="!pastCollapsed">
            <div v-for="url in pastUrls" :key="url.id" class="url-card" style="opacity: 0.8;">
              <!-- Collapsed Header (always visible) -->
              <div style="display: flex; justify-content: space-between; align-items: center; gap: 1rem; cursor: pointer;" @click="toggleCardCollapse(url.id)">
                <div style="flex: 1; min-width: 0;">
                  <div style="display: flex; align-items: center; gap: 0.5rem; margin-bottom: 0.5rem;">
                    <span v-if="url.sport" style="font-size: 1.5rem;">{{ getSportEmoji(url.sport) }}</span>
                    <div class="url-title" style="flex: 1; min-width: 0;">{{ url.name }}</div>
                    <i :class="isCardCollapsed(url.id) ? 'bi-chevron-down' : 'bi-chevron-up'" class="bi" style="color: var(--text-secondary); font-size: 1.25rem; transition: transform 0.2s;"></i>
                  </div>
                  <div style="display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap;">
                    <span v-if="url.person" :style="`display: inline-flex; align-items: center; gap: 0.25rem; padding: 0.25rem 0.75rem; background-color: ${url.person.color}; color: white; border-radius: 9999px; font-size: 0.75rem; font-weight: 500;`">
                      <i class="bi bi-person-fill"></i> {{ url.person.name }}
                    </span>
                    <span style="color: var(--text-secondary); font-size: 0.875rem;">
                      <i class="bi bi-calendar-event" style="margin-right: 0.25rem;"></i>{{ formatSimpleDate(url.tournament_start_date) }}
                    </span>
                    <span class="badge badge-secondary" style="font-size: 0.75rem; font-weight: 500;">
                      Past
                    </span>
                  </div>
                </div>
              </div>

              <!-- Expanded Content -->
              <div v-if="!isCardCollapsed(url.id)" style="margin-top: 1.25rem; padding-top: 1.25rem; border-top: 1px solid rgba(0, 0, 0, 0.08);">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 1.5rem;">
                  <div style="flex: 1;">
                    <a :href="url.url" target="_blank" rel="noopener" style="display: inline-block; margin-bottom: 1.25rem; padding: 0.5rem 1rem; background: var(--primary-color); color: white; text-decoration: none; border-radius: var(--radius-sm); font-size: 0.875rem; font-weight: 500; transition: all 0.2s;" @mouseover="$event.target.style.opacity='0.9'" @mouseout="$event.target.style.opacity='1'" @click.stop>
                      <i class="bi bi-link-45deg"></i> Link to schedule
                    </a>

                    <div style="border-top: 1px solid rgba(0, 0, 0, 0.08); padding-top: 1rem;">
                      <div style="display: grid; gap: 0.625rem; font-size: 0.875rem;">
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Last Checked</span>
                          <span style="color: var(--text-color); font-weight: 400;">{{ formatDate(url.last_checked_at) }}</span>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Status</span>
                          <span v-if="url.schedule_available" class="badge badge-success" style="font-weight: 500;">Schedule Available</span>
                          <span v-else class="badge badge-warning" style="font-weight: 500;">Waiting for Schedule</span>
                        </div>
                        <div v-if="url.notification_email" style="display: flex; justify-content: space-between; align-items: center;">
                          <span style="color: var(--text-secondary); font-weight: 400;">Notifications</span>
                          <span style="color: var(--text-color); font-weight: 400; font-size: 0.8125rem;">{{ url.notification_email }}</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                    <button @click.stop="removeUrl(url.id)" class="btn-danger" style="white-space: nowrap; padding: 0.5rem 1rem;">
                      <i class="bi bi-trash"></i> Remove
                    </button>
                  </div>
                </div>
              </div>
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
