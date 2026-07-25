const CATEGORY_LABELS = {
  diplome: 'Diplôme',
  memoire: 'Mémoire',
  seminaire: 'Séminaire',
  certification: 'Certification',
  informatique: 'Informatique',
  langue: 'Langues',
  permis: 'Permis',
  secourisme: 'Secourisme',
  autre: 'Autre',
}

const SKILL_ORDER = ['informatique', 'langue', 'permis', 'secourisme', 'autre']

export const PRO_EXPERIENCE_CATEGORIES = [null, 'emploi', 'freelance', 'associatif']

export const categoryLabel = (value) => CATEGORY_LABELS[value] || value

export const groupExperiencesByCategory = (experiences) => {
  const groups = [
    { key: 'pro', label: 'Expériences professionnelles', items: experiences.filter(e => PRO_EXPERIENCE_CATEGORIES.includes(e.category)) },
    { key: 'conf', label: 'Conférences & Interventions', items: experiences.filter(e => e.category === 'intervention') },
    { key: 'pub', label: 'Publications & Médias', items: experiences.filter(e => e.category === 'media') },
  ]
  return groups.filter(g => g.items.length)
}

export const formatYearRange = (start, end) => {
  if (!start && !end) return ''
  const s = start ? String(start) : ''
  const e = end ? String(end) : "Aujourd'hui"
  if (s && end && Number(start) === Number(end)) return s
  return s ? `${s} — ${e}` : e
}

export const groupSkillsByCategory = (skills) => {
  const groups = {}
  for (const s of skills) {
    const key = s.category || 'autre'
    if (!groups[key]) groups[key] = []
    groups[key].push(s)
  }
  return SKILL_ORDER.filter(c => groups[c]?.length).map(c => ({ category: c, items: groups[c] }))
}
