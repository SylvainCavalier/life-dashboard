// Constantes et helpers du CRM, partages par la page CRM et le mini-CRM des projets.
// Les cles doivent rester alignees sur CrmProfile::PRIORITIES et CONTACT_METHODS.
export const crmPriorities = [
  { value: 'haute', label: 'Haute', badge: 'bg-rose-100 text-rose-700' },
  { value: 'moyenne', label: 'Moyenne', badge: 'bg-amber-100 text-amber-700' },
  { value: 'basse', label: 'Basse', badge: 'bg-gray-100 text-gray-600' },
]

export const crmContactMethods = [
  { value: 'telephone', label: 'Téléphone' },
  { value: 'email', label: 'Email' },
  { value: 'sms', label: 'SMS' },
  { value: 'visio', label: 'Visio' },
  { value: 'rencontre', label: 'Rencontre' },
  { value: 'autre', label: 'Autre' },
]

export const formatCrmDate = (date) => {
  if (!date) return '—'
  return new Date(date).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' })
}

export const isCrmDue = (date) => {
  if (!date) return false
  return new Date(date) <= new Date()
}

export const crmPriorityLabel = (value) => crmPriorities.find((p) => p.value === value)?.label || value
export const crmPriorityBadge = (value) => crmPriorities.find((p) => p.value === value)?.badge || 'bg-gray-100 text-gray-500'
export const crmMethodLabel = (value) => crmContactMethods.find((m) => m.value === value)?.label || value

export const contactFullName = (contact) => [contact.first_name, contact.last_name].filter(Boolean).join(' ')

// Contacts a relancer (prochain rendez-vous atteint ou depasse), du plus ancien au plus recent.
// `rows` : [{ key, contact, profile }].
export const crmDueAlerts = (rows) =>
  rows
    .filter((row) => row.profile && isCrmDue(row.profile.next_appointment_on))
    .map((row) => ({ key: row.key, name: contactFullName(row.contact), next_appointment_on: row.profile.next_appointment_on }))
    .sort((a, b) => new Date(a.next_appointment_on) - new Date(b.next_appointment_on))
