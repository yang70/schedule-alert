export function pacificToday(now = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'America/Los_Angeles', year: 'numeric', month: '2-digit', day: '2-digit'
  }).formatToParts(now)
  const values = Object.fromEntries(parts.map(part => [part.type, part.value]))
  return `${values.year}-${values.month}-${values.day}`
}

export function daysUntilTournament(date, today = pacificToday()) {
  if (!date) return null
  const civilDay = value => {
    const [year, month, day] = value.split('-').map(Number)
    return Date.UTC(year, month - 1, day)
  }
  return Math.round((civilDay(date) - civilDay(today)) / 86400000)
}

export function safeScheduleLink(value) {
  try {
    const url = new URL(value)
    return ['http:', 'https:'].includes(url.protocol) && !url.username && !url.password ? url.href : '#'
  } catch {
    return '#'
  }
}
