// Libelles et couleurs du module Vehicules (valeurs = Vehicle::TYPES, VehicleIntervention::KINDS...).
export { formatEuros, formatDate, daysUntil } from './useInsurances'

export const vehicleTypes = [
  { value: 'voiture', label: 'Voiture', icon: '🚗', badge: 'bg-blue-100 text-blue-800' },
  { value: 'moto', label: 'Moto', icon: '🏍️', badge: 'bg-sky-100 text-sky-800' },
  { value: 'scooter', label: 'Scooter', icon: '🛵', badge: 'bg-cyan-100 text-cyan-800' },
  { value: 'utilitaire', label: 'Utilitaire', icon: '🚐', badge: 'bg-slate-100 text-slate-800' },
  { value: 'camping_car', label: 'Camping-car', icon: '🚌', badge: 'bg-amber-100 text-amber-800' },
  { value: 'quad', label: 'Quad', icon: '🏁', badge: 'bg-lime-100 text-lime-800' },
  { value: 'velo_electrique', label: 'Vélo électrique', icon: '🚲', badge: 'bg-emerald-100 text-emerald-800' },
  { value: 'autre', label: 'Autre', icon: '🚘', badge: 'bg-gray-100 text-gray-700' },
]

export const vehicleStatuses = [
  { value: 'active', label: 'En service', badge: 'bg-green-100 text-green-800' },
  { value: 'hors_service', label: 'Hors service', badge: 'bg-yellow-100 text-yellow-800' },
  { value: 'vendu', label: 'Vendu', badge: 'bg-gray-200 text-gray-600' },
]

export const fuels = [
  { value: 'essence', label: 'Essence' },
  { value: 'diesel', label: 'Diesel' },
  { value: 'hybride', label: 'Hybride' },
  { value: 'hybride_rechargeable', label: 'Hybride rechargeable' },
  { value: 'electrique', label: 'Électrique' },
  { value: 'gpl', label: 'GPL' },
  { value: 'e85', label: 'Superéthanol E85' },
  { value: 'autre', label: 'Autre' },
]

export const interventionKinds = [
  { value: 'entretien', label: 'Entretien / révision', icon: '🔧', badge: 'bg-blue-100 text-blue-800' },
  { value: 'controle_technique', label: 'Contrôle technique', icon: '📋', badge: 'bg-purple-100 text-purple-800' },
  { value: 'reparation', label: 'Réparation', icon: '🛠️', badge: 'bg-orange-100 text-orange-800' },
  { value: 'pneus', label: 'Pneus', icon: '🛞', badge: 'bg-slate-100 text-slate-800' },
  { value: 'carrosserie', label: 'Carrosserie', icon: '🎨', badge: 'bg-pink-100 text-pink-800' },
  { value: 'sinistre', label: 'Sinistre / accident', icon: '⚠️', badge: 'bg-red-100 text-red-800' },
  { value: 'autre', label: 'Autre', icon: '📌', badge: 'bg-gray-100 text-gray-700' },
]

export const inspectionOutcomes = [
  { value: 'favorable', label: 'Favorable', badge: 'bg-green-100 text-green-800' },
  { value: 'contre_visite', label: 'Défavorable (contre-visite)', badge: 'bg-orange-100 text-orange-800' },
  { value: 'critique', label: 'Défavorable (défaillance critique)', badge: 'bg-red-100 text-red-800' },
]

export const vehicleDocCategories = [
  { value: 'registration', label: 'Carte grise' },
  { value: 'inspection', label: 'Contrôle technique' },
  { value: 'maintenance', label: 'Entretien' },
  { value: 'repair', label: 'Réparation' },
  { value: 'purchase', label: 'Achat / vente' },
  { value: 'insurance', label: 'Assurance' },
  { value: 'fine', label: 'Amende' },
  { value: 'manual', label: 'Notice / carnet' },
  { value: 'other', label: 'Autre' },
]

const find = (list, value) => list.find((entry) => entry.value === value)

export const typeLabel = (value) => find(vehicleTypes, value)?.label || value
export const typeIcon = (value) => find(vehicleTypes, value)?.icon || '🚘'
export const typeBadge = (value) => find(vehicleTypes, value)?.badge || 'bg-gray-100 text-gray-700'
export const statusLabel = (value) => find(vehicleStatuses, value)?.label || value
export const statusBadge = (value) => find(vehicleStatuses, value)?.badge || 'bg-gray-100 text-gray-700'
export const fuelLabel = (value) => find(fuels, value)?.label || value
export const kindLabel = (value) => find(interventionKinds, value)?.label || value
export const kindIcon = (value) => find(interventionKinds, value)?.icon || '📌'
export const kindBadge = (value) => find(interventionKinds, value)?.badge || 'bg-gray-100 text-gray-700'
export const outcomeLabel = (value) => find(inspectionOutcomes, value)?.label || value
export const outcomeBadge = (value) => find(inspectionOutcomes, value)?.badge || 'bg-gray-100 text-gray-700'
export const docCategoryLabel = (value) => find(vehicleDocCategories, value)?.label || value

export const formatKm = (km) => (km === null || km === undefined || km === '' ? '' : `${Number(km).toLocaleString('fr-FR')} km`)

// Echeances calculees par le serveur (Vehicle#inspection_status, #service_status).
export const dueClass = (status) => ({
  overdue: 'text-red-600 font-medium',
  due_soon: 'text-orange-600 font-medium',
}[status] || 'text-gray-900')
