// Libelles et mise en forme de la page Prets (reprend les formats de la page Assurances).
import { formatEuros, formatDate, parseDate } from './useInsurances'

export { formatEuros, formatDate }

// Memes cles que Loan::DIRECTIONS et Loan::KINDS
export const directions = [
  { value: 'lent', label: "J'ai prêté", short: 'Prêté à', badge: 'bg-indigo-100 text-indigo-700' },
  { value: 'borrowed', label: "On m'a prêté", short: 'Emprunté à', badge: 'bg-amber-100 text-amber-800' },
]

export const kinds = [
  { value: 'object', label: 'Un objet', icon: '📦' },
  { value: 'money', label: 'De l’argent', icon: '💶' },
]

const directionByValue = Object.fromEntries(directions.map(d => [d.value, d]))
export const directionShort = (value) => directionByValue[value]?.short || value
export const directionBadge = (value) => directionByValue[value]?.badge || 'bg-gray-100 text-gray-600'
export const kindIcon = (value) => (value === 'money' ? '💶' : '📦')

export const statusLabel = (status) => ({
  ongoing: 'En cours', due_soon: 'Retour proche', overdue: 'En retard', returned: 'Rendu',
}[status] || status)

export const statusBadge = (status) => ({
  ongoing: 'bg-emerald-100 text-emerald-700',
  due_soon: 'bg-orange-100 text-orange-700',
  overdue: 'bg-red-100 text-red-700',
  returned: 'bg-gray-100 text-gray-500',
}[status] || 'bg-gray-100 text-gray-500')

export const todayIso = () => {
  const now = new Date()
  const pad = (n) => String(n).padStart(2, '0')
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
}

// « depuis 3 mois », « depuis 12 jours »
export const durationSince = (iso) => {
  const days = Math.round((Date.now() - parseDate(iso)) / 86400000)
  if (days <= 0) return "aujourd'hui"
  if (days < 45) return `depuis ${days} jour${days > 1 ? 's' : ''}`
  const months = Math.floor(days / 30.44)
  if (months < 24) return `depuis ${months} mois`
  return `depuis ${Math.floor(days / 365.25)} ans`
}

export const dueLabel = (days) => {
  if (days === null || days === undefined) return ''
  if (days < 0) return `en retard de ${-days} jour${-days > 1 ? 's' : ''}`
  if (days === 0) return "prévu aujourd'hui"
  return `dans ${days} jour${days > 1 ? 's' : ''}`
}

export const contactName = (contact) => [contact.first_name, contact.last_name].filter(Boolean).join(' ')
