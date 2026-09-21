// Constantes et helpers du module Projets. Les cles de categorie doivent rester
// alignees sur Project::CATEGORIES cote Rails.
export const projectCategories = [
  { value: 'developpement', label: 'Développement', badge: 'bg-blue-100 text-blue-700', dot: 'bg-blue-500' },
  { value: 'musique', label: 'Musique', badge: 'bg-purple-100 text-purple-700', dot: 'bg-purple-500' },
  { value: 'video', label: 'Vidéo', badge: 'bg-red-100 text-red-700', dot: 'bg-red-500' },
  { value: 'jeu_video', label: 'Jeu vidéo', badge: 'bg-emerald-100 text-emerald-700', dot: 'bg-emerald-500' },
  { value: 'sport', label: 'Sport', badge: 'bg-orange-100 text-orange-700', dot: 'bg-orange-500' },
  { value: 'jeu_de_role', label: 'Jeu de rôle', badge: 'bg-amber-100 text-amber-800', dot: 'bg-amber-600' },
  { value: 'business', label: 'Business', badge: 'bg-slate-200 text-slate-700', dot: 'bg-slate-600' },
  { value: 'ecriture', label: 'Écriture', badge: 'bg-pink-100 text-pink-700', dot: 'bg-pink-500' },
  { value: 'apprentissage', label: 'Apprentissage', badge: 'bg-cyan-100 text-cyan-700', dot: 'bg-cyan-500' },
  { value: 'autre', label: 'Autre', badge: 'bg-gray-100 text-gray-700', dot: 'bg-gray-400' },
]

export const projectStatuses = [
  { value: 'en_cours', label: 'En cours', badge: 'bg-blue-100 text-blue-700' },
  { value: 'en_attente', label: 'En attente', badge: 'bg-yellow-100 text-yellow-700' },
  { value: 'termine', label: 'Terminé', badge: 'bg-green-100 text-green-700' },
  { value: 'abandonne', label: 'Abandonné', badge: 'bg-red-100 text-red-700' },
]

export const skillStatuses = [
  { value: 'a_apprendre', label: 'À apprendre', badge: 'bg-gray-100 text-gray-600' },
  { value: 'en_cours', label: 'En cours', badge: 'bg-blue-100 text-blue-700' },
  { value: 'acquise', label: 'Acquise', badge: 'bg-green-100 text-green-700' },
]

export const projectDocCategories = [
  { value: 'reference', label: 'Référence' },
  { value: 'brief', label: 'Cahier des charges' },
  { value: 'asset', label: 'Ressource' },
  { value: 'tutorial', label: 'Tutoriel' },
  { value: 'contract', label: 'Contrat' },
  { value: 'other', label: 'Autre' },
]

const find = (list, value) => list.find(item => item.value === value)

export function useProjects() {
  const categoryLabel = (value) => find(projectCategories, value)?.label || value
  const categoryBadge = (value) => find(projectCategories, value)?.badge || 'bg-gray-100 text-gray-700'
  const statusLabel = (value) => find(projectStatuses, value)?.label || value
  const statusBadge = (value) => find(projectStatuses, value)?.badge || 'bg-gray-100 text-gray-700'
  const skillStatusLabel = (value) => find(skillStatuses, value)?.label || value
  const skillStatusBadge = (value) => find(skillStatuses, value)?.badge || 'bg-gray-100 text-gray-600'
  const docCategoryLabel = (value) => find(projectDocCategories, value)?.label || value

  const progressColor = (progress) => {
    if (progress >= 80) return 'bg-green-500'
    if (progress >= 50) return 'bg-blue-500'
    if (progress >= 25) return 'bg-yellow-500'
    return 'bg-gray-400'
  }

  return {
    categoryLabel, categoryBadge, statusLabel, statusBadge,
    skillStatusLabel, skillStatusBadge, docCategoryLabel, progressColor,
  }
}
