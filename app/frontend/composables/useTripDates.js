// Date helpers for the Voyages module. Dates travel as "YYYY-MM-DD" strings
// (Rails date columns); everything here works on those strings to avoid
// timezone shifts.

export const formatDateKey = (date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`

export const parseDateKey = (str) => new Date(`${str}T00:00:00`)

export const addDays = (str, n) => {
  const d = parseDateKey(str)
  d.setDate(d.getDate() + n)
  return formatDateKey(d)
}

// Every day of the trip, inclusive, as date keys.
export const tripDays = (start, end) => {
  if (!start || !end) return []
  const days = []
  const cursor = parseDateKey(start)
  const last = parseDateKey(end)
  while (cursor <= last) {
    days.push(formatDateKey(cursor))
    cursor.setDate(cursor.getDate() + 1)
  }
  return days
}

export const formatDate = (str) =>
  str ? parseDateKey(str).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }) : ''

export const formatDayShort = (str) =>
  str ? parseDateKey(str).toLocaleDateString('fr-FR', { weekday: 'short', day: 'numeric', month: 'short' }) : ''

export const formatDayLong = (str) =>
  str ? parseDateKey(str).toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' }) : ''

export const formatDateTime = (iso) =>
  iso ? new Date(iso).toLocaleString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : ''

export const formatCurrency = (value) => {
  if (value === null || value === undefined || value === '') return ''
  return new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(Number(value))
}

export const todayKey = () => formatDateKey(new Date())

export function useTripDates() {
  return { formatDateKey, parseDateKey, addDays, tripDays, formatDate, formatDayShort, formatDayLong, formatDateTime, formatCurrency, todayKey }
}
