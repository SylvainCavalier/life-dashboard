// Libelles et couleurs du module Assurances (valeurs = Insurance::TYPES, STATUSES...).

export const insuranceTypes = [
  { value: 'habitation', label: 'Habitation', icon: '🏠', badge: 'bg-amber-100 text-amber-800' },
  { value: 'auto', label: 'Auto', icon: '🚗', badge: 'bg-blue-100 text-blue-800' },
  { value: 'moto', label: 'Moto / deux-roues', icon: '🏍️', badge: 'bg-sky-100 text-sky-800' },
  { value: 'sante', label: 'Santé / mutuelle', icon: '🩺', badge: 'bg-red-100 text-red-800' },
  { value: 'prevoyance', label: 'Prévoyance', icon: '🛟', badge: 'bg-rose-100 text-rose-800' },
  { value: 'vie', label: 'Assurance vie', icon: '🌱', badge: 'bg-emerald-100 text-emerald-800' },
  { value: 'emprunteur', label: 'Emprunteur', icon: '🏦', badge: 'bg-yellow-100 text-yellow-800' },
  { value: 'responsabilite_civile', label: 'Responsabilité civile', icon: '🤝', badge: 'bg-indigo-100 text-indigo-800' },
  { value: 'protection_juridique', label: 'Protection juridique', icon: '⚖️', badge: 'bg-purple-100 text-purple-800' },
  { value: 'professionnelle', label: 'Professionnelle (RC pro...)', icon: '💼', badge: 'bg-slate-100 text-slate-800' },
  { value: 'voyage', label: 'Voyage', icon: '✈️', badge: 'bg-cyan-100 text-cyan-800' },
  { value: 'animaux', label: 'Animaux', icon: '🐾', badge: 'bg-lime-100 text-lime-800' },
  { value: 'scolaire', label: 'Scolaire', icon: '🎒', badge: 'bg-orange-100 text-orange-800' },
  { value: 'autre', label: 'Autre', icon: '📄', badge: 'bg-gray-100 text-gray-700' },
]

export const insuranceStatuses = [
  { value: 'active', label: 'En cours', badge: 'bg-green-100 text-green-800' },
  { value: 'suspendue', label: 'Suspendue', badge: 'bg-yellow-100 text-yellow-800' },
  { value: 'resiliee', label: 'Résiliée', badge: 'bg-gray-200 text-gray-600' },
]

export const premiumFrequencies = [
  { value: 'monthly', label: 'par mois' },
  { value: 'quarterly', label: 'par trimestre' },
  { value: 'semiannual', label: 'par semestre' },
  { value: 'yearly', label: 'par an' },
]

export const itemKinds = [
  { value: 'logement', label: 'Logement' },
  { value: 'vehicule', label: 'Véhicule' },
  { value: 'personne', label: 'Personne' },
  { value: 'animal', label: 'Animal' },
  { value: 'objet', label: 'Objet de valeur' },
  { value: 'autre', label: 'Autre' },
]

export const insuranceDocCategories = [
  { value: 'special_terms', label: 'Conditions particulières' },
  { value: 'general_terms', label: 'Conditions générales' },
  { value: 'certificate', label: 'Attestation' },
  { value: 'schedule', label: 'Avis d\'échéance' },
  { value: 'claim', label: 'Sinistre' },
  { value: 'correspondence', label: 'Correspondance' },
  { value: 'termination', label: 'Résiliation' },
  { value: 'other', label: 'Autre' },
]

// Garanties usuelles proposees a la saisie, selon le type de contrat.
export const coverageSuggestions = {
  habitation: ['Dégâts des eaux', 'Incendie', 'Vol et vandalisme', 'Bris de glace', 'Catastrophes naturelles', 'Tempête, grêle, neige', 'Responsabilité civile vie privée', 'Dommages électriques', 'Recours des voisins et des tiers', 'Assistance', 'Objets de valeur', 'Rééquipement à neuf'],
  auto: ['Responsabilité civile', 'Bris de glace', 'Vol', 'Incendie', 'Dommages tous accidents', 'Catastrophes naturelles', 'Garantie du conducteur', 'Assistance 0 km', 'Véhicule de remplacement', 'Protection juridique'],
  moto: ['Responsabilité civile', 'Vol', 'Incendie', 'Dommages tous accidents', 'Équipement du pilote', 'Garantie du conducteur', 'Assistance'],
  sante: ['Hospitalisation', 'Consultations', 'Optique', 'Dentaire', 'Pharmacie', 'Médecines douces', 'Audioprothèses'],
  prevoyance: ['Décès', 'Invalidité', 'Incapacité de travail', 'Rente éducation'],
  emprunteur: ['Décès', 'PTIA', 'Invalidité permanente', 'Incapacité temporaire de travail', 'Perte d\'emploi'],
  voyage: ['Annulation', 'Frais médicaux à l\'étranger', 'Rapatriement', 'Bagages', 'Responsabilité civile à l\'étranger'],
  professionnelle: ['Responsabilité civile professionnelle', 'Protection juridique', 'Multirisque des locaux', 'Cyber-risques'],
}

const find = (list, value) => list.find((entry) => entry.value === value)

export const typeLabel = (value) => find(insuranceTypes, value)?.label || value
export const typeIcon = (value) => find(insuranceTypes, value)?.icon || '📄'
export const typeBadge = (value) => find(insuranceTypes, value)?.badge || 'bg-gray-100 text-gray-700'
export const statusLabel = (value) => find(insuranceStatuses, value)?.label || value
export const statusBadge = (value) => find(insuranceStatuses, value)?.badge || 'bg-gray-100 text-gray-700'
export const frequencyLabel = (value) => find(premiumFrequencies, value)?.label || ''
export const itemKindLabel = (value) => find(itemKinds, value)?.label || value
export const docCategoryLabel = (value) => find(insuranceDocCategories, value)?.label || value

export const formatEuros = (amount) => {
  if (amount === null || amount === undefined || amount === '') return ''
  return `${Number(amount).toLocaleString('fr-FR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} €`
}

// Dates ISO (AAAA-MM-JJ) lues en heure locale, sans decalage de fuseau.
export const parseDate = (iso) => {
  const [year, month, day] = iso.split('-').map(Number)
  return new Date(year, month - 1, day)
}

export const formatDate = (iso) => (iso ? parseDate(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' }) : '')

export const daysUntil = (iso) => {
  if (!iso) return null
  const today = new Date()
  today.setHours(0, 0, 0, 0)
  return Math.round((parseDate(iso) - today) / 86400000)
}
