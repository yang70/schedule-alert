import test from 'node:test'
import assert from 'node:assert/strict'
import { daysUntilTournament, pacificToday, safeScheduleLink } from '../../app/javascript/date_utils.mjs'

test('civil day differences stay correct across both DST transitions', () => {
  assert.equal(daysUntilTournament('2026-11-02', '2026-10-31'), 2)
  assert.equal(daysUntilTournament('2026-03-09', '2026-03-07'), 2)
})
test('Pacific eligibility uses the previous date in early UTC evening', () => {
  assert.equal(pacificToday(new Date('2026-10-14T01:00:00Z')), '2026-10-13')
})
test('missing dates remain unscheduled', () => {
  assert.equal(daysUntilTournament(null), null)
})
test('rendered schedule links reject executable and credential-bearing URLs', () => {
  assert.equal(safeScheduleLink("javascript:alert('https://example.com')"), '#')
  assert.equal(safeScheduleLink('https://user:password@example.com'), '#')
  assert.equal(safeScheduleLink('https://example.com/schedule'), 'https://example.com/schedule')
})
