<script>
import { safeScheduleLink } from '../date_utils.mjs'
export default {
  props: { events: { type: Array, default: () => [] } },
  methods: {
    safeScheduleLink,
    deliveryStatus(event) {
      if (event.delivered_at) return 'Email sent'
      if (event.delivery_attempts >= 8) return 'Email delivery failed'
      return event.last_error ? 'Retrying email delivery' : 'Email pending'
    }
  }
}
</script>
<template>
  <section v-if="events.length" class="dashboard-header" aria-labelledby="history-title">
    <h2 id="history-title">Recent notifications</h2>
    <article v-for="event in events" :key="event.id" class="notification-history-item">
      <strong>{{ event.kind === 'released' ? 'Schedule released' : 'Schedule changed' }}: {{ event.payload.name }}</strong>
      <p class="notification-summary">{{ event.payload.summary }}</p>
      <a :href="safeScheduleLink(event.payload.url)" target="_blank" rel="noopener noreferrer">View schedule</a>
      <span class="ms-3">{{ deliveryStatus(event) }}</span>
    </article>
  </section>
</template>
