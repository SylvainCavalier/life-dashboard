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

export const categoryLabel = (value) => CATEGORY_LABELS[value] || value

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
