// Shared formatting helpers, option lists and badge/label maps for the
// Companies module (index page, show page and quote/invoice/client modals).

export const legalForms = [
  { value: 'ei', label: 'Entreprise individuelle' },
  { value: 'sas', label: 'SAS' },
  { value: 'sarl', label: 'SARL' },
  { value: 'eurl', label: 'EURL' },
  { value: 'sasu', label: 'SASU' },
  { value: 'sa', label: 'SA' },
  { value: 'sci', label: 'SCI' },
  { value: 'auto_entrepreneur', label: 'Auto-entrepreneur' },
  { value: 'association', label: 'Association' },
  { value: 'autre', label: 'Autre' },
]

export const statuses = [
  { value: 'active', label: 'Active' },
  { value: 'inactive', label: 'Inactive' },
  { value: 'en_creation', label: 'En cours de creation' },
  { value: 'radiee', label: 'Radiee' },
]

export const paymentMethods = [
  { value: 'virement', label: 'Virement' },
  { value: 'cheque', label: 'Cheque' },
  { value: 'cb', label: 'Carte bancaire' },
  { value: 'especes', label: 'Especes' },
  { value: 'prelevement', label: 'Prelevement' },
  { value: 'autre', label: 'Autre' },
]

export const unitTypes = [
  { value: 'unite', label: 'Unite' },
  { value: 'heure', label: 'Heure' },
  { value: 'jour', label: 'Jour' },
  { value: 'mois', label: 'Mois' },
  { value: 'forfait', label: 'Forfait' },
  { value: 'kg', label: 'kg' },
  { value: 'm2', label: 'm²' },
]

export const docCategories = [
  { value: 'invoice', label: 'Facture' },
  { value: 'quote', label: 'Devis' },
  { value: 'contract', label: 'Contrat' },
  { value: 'kbis', label: 'Kbis' },
  { value: 'statutes', label: 'Statuts' },
  { value: 'other', label: 'Autre' },
]

export function useFormat() {
  const formatDate = (val) => {
    if (!val) return null
    return new Date(val).toLocaleDateString('fr-FR')
  }

  const formatCurrency = (val) => {
    if (val === null || val === undefined) return null
    return new Intl.NumberFormat('fr-FR', {
      style: 'currency', currency: 'EUR', minimumFractionDigits: 2, maximumFractionDigits: 2,
    }).format(val)
  }

  const legalFormLabel = (val) => legalForms.find(f => f.value === val)?.label || val

  const legalFormBadge = (val) => {
    const colors = {
      ei: 'bg-rose-100 text-rose-700',
      sas: 'bg-blue-100 text-blue-700',
      sarl: 'bg-purple-100 text-purple-700',
      eurl: 'bg-cyan-100 text-cyan-700',
      sasu: 'bg-indigo-100 text-indigo-700',
      sa: 'bg-violet-100 text-violet-700',
      sci: 'bg-amber-100 text-amber-700',
      auto_entrepreneur: 'bg-yellow-100 text-yellow-700',
      association: 'bg-teal-100 text-teal-700',
      autre: 'bg-gray-100 text-gray-500',
    }
    return colors[val] || 'bg-gray-100 text-gray-500'
  }

  const statusLabel = (val) => statuses.find(s => s.value === val)?.label || val

  const statusBadge = (val) => {
    const colors = {
      active: 'bg-green-100 text-green-700',
      inactive: 'bg-gray-100 text-gray-600',
      en_creation: 'bg-orange-100 text-orange-700',
      radiee: 'bg-red-100 text-red-700',
    }
    return colors[val] || 'bg-gray-100 text-gray-500'
  }

  const quoteStatusLabel = (status) => {
    const labels = { pending: 'En attente', accepted: 'Accepte', refused: 'Refuse' }
    return labels[status] || status
  }

  const quoteStatusBadge = (status) => {
    const colors = {
      pending: 'bg-yellow-100 text-yellow-700',
      accepted: 'bg-green-100 text-green-700',
      refused: 'bg-red-100 text-red-700',
    }
    return colors[status] || 'bg-gray-100 text-gray-500'
  }

  const invoiceStatusLabel = (status) => {
    const labels = { pending: 'En attente', paid: 'Payee' }
    return labels[status] || status
  }

  const invoiceStatusBadge = (status) => {
    const colors = {
      pending: 'bg-orange-100 text-orange-700',
      paid: 'bg-green-100 text-green-700',
    }
    return colors[status] || 'bg-gray-100 text-gray-500'
  }

  const paymentMethodLabel = (val) => paymentMethods.find(p => p.value === val)?.label || val

  const docCategoryLabel = (val) => docCategories.find(c => c.value === val)?.label || val

  // Per-line total for a quote/invoice item, applying the optional discount.
  const computeLineTotal = (item) => {
    let subtotal = (item.quantity || 0) * (item.unit_price || 0)
    if (item.discount_type === 'percent' && item.discount_value) {
      subtotal *= (1 - item.discount_value / 100)
    } else if (item.discount_type === 'amount' && item.discount_value) {
      subtotal = Math.max(0, subtotal - item.discount_value)
    }
    return Math.round(subtotal * 100) / 100
  }

  return {
    formatDate, formatCurrency,
    legalFormLabel, legalFormBadge, statusLabel, statusBadge,
    quoteStatusLabel, quoteStatusBadge, invoiceStatusLabel, invoiceStatusBadge,
    paymentMethodLabel, docCategoryLabel, computeLineTotal,
  }
}
