// Listes et mise en forme de la page Garanties (reprend les formats de la page Assurances).
import { formatEuros, formatDate, parseDate, daysUntil } from './useInsurances'

export { formatEuros, formatDate, parseDate, daysUntil }

// Memes cles que Warranty::CATEGORIES
export const warrantyCategories = [
  { value: 'electromenager', label: 'Électroménager', icon: '🧺' },
  { value: 'informatique', label: 'Informatique', icon: '💻' },
  { value: 'telephonie', label: 'Téléphonie', icon: '📱' },
  { value: 'audio_video', label: 'Audio / vidéo', icon: '📺' },
  { value: 'photo', label: 'Photo', icon: '📷' },
  { value: 'jeux_video', label: 'Jeux vidéo', icon: '🎮' },
  { value: 'mobilier', label: 'Mobilier', icon: '🛋️' },
  { value: 'bricolage_jardin', label: 'Bricolage / jardin', icon: '🔧' },
  { value: 'vehicule', label: 'Véhicule / mobilité', icon: '🛴' },
  { value: 'sport', label: 'Sport', icon: '🚴' },
  { value: 'mode', label: 'Mode / accessoires', icon: '⌚' },
  { value: 'autre', label: 'Autre', icon: '📦' },
]

const byValue = Object.fromEntries(warrantyCategories.map(c => [c.value, c]))
export const categoryLabel = (value) => byValue[value]?.label || value
export const categoryIcon = (value) => byValue[value]?.icon || '📦'

// Durees proposees en un clic (en mois). 24 = garantie legale de conformite d'un bien neuf.
export const durationPresets = [
  { months: 6, label: '6 mois' },
  { months: 12, label: '1 an' },
  { months: 24, label: '2 ans' },
  { months: 36, label: '3 ans' },
  { months: 60, label: '5 ans' },
]

export const durationLabel = (months) => {
  if (!months) return ''
  if (months % 12 === 0) return `${months / 12} an${months > 12 ? 's' : ''}`
  return `${months} mois`
}

// Meme regle que Warranty#compute_ends_on : date d'achat + duree, au meme quantieme
// (fin de mois si le jour n'existe pas, comme `>>` en Ruby).
export const addMonths = (iso, months) => {
  const start = parseDate(iso)
  const target = new Date(start.getFullYear(), start.getMonth() + Number(months), 1)
  const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate()
  target.setDate(Math.min(start.getDate(), lastDay))
  const pad = (n) => String(n).padStart(2, '0')
  return `${target.getFullYear()}-${pad(target.getMonth() + 1)}-${pad(target.getDate())}`
}

export const statusLabel = (status) => ({ active: 'Sous garantie', expiring: 'Expire bientôt', expired: 'Expirée' }[status] || status)

export const statusBadge = (status) => ({
  active: 'bg-emerald-100 text-emerald-700',
  expiring: 'bg-orange-100 text-orange-700',
  expired: 'bg-gray-100 text-gray-500',
}[status] || 'bg-gray-100 text-gray-500')

export const remainingLabel = (days) => {
  if (days === null || days === undefined) return ''
  if (days < 0) return `expirée depuis ${-days} jour${-days > 1 ? 's' : ''}`
  if (days === 0) return "expire aujourd'hui"
  if (days < 60) return `encore ${days} jour${days > 1 ? 's' : ''}`
  const months = Math.floor(days / 30.44)
  if (months < 24) return `encore ${months} mois`
  return `encore ${Math.floor(days / 365.25)} ans`
}

// Part de la garantie deja ecoulee, de 0 a 100.
export const elapsedPercent = (warranty) => {
  const start = parseDate(warranty.purchased_on)
  const end = parseDate(warranty.ends_on)
  const total = end - start
  if (total <= 0) return 100
  return Math.min(100, Math.max(0, Math.round(((Date.now() - start) / total) * 100)))
}
