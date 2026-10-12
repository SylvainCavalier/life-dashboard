// Regles de presentation communes a l'apercu et aux fichiers generes cote serveur
// (Letter#place_and_date, Letters::Layout) : a modifier ensemble.

const MONTHS = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre']

// Gabarit A4 en millimetres (Letters::Layout)
export const LAYOUT = {
  pageWidth: 210,
  pageHeight: 297,
  marginTop: 15,
  marginSide: 20,
  marginBottom: 25,
  senderWidth: 85,
  recipientLeft: 110,
  recipientWidth: 80,
  windowRecipientTop: 50, // enveloppe a fenetre seulement
  windowDateTop: 95,
  blockGap: 6,
  signatureLeft: 110,
  signatureMaxWidth: 50,
  signatureMaxHeight: 22,
  fontSize: 10,
  smallFontSize: 7.5,
  lineHeight: 1.35,
  paragraphSpacing: 6,
  listItemSpacing: 2,
  listIndent: 6,
}

export const emptyDoc = () => ({ type: 'doc', content: [] })

// « Créteil, le 12 octobre 2026 » (« le 1er » en debut de mois)
export function placeAndDate(place, isoDate) {
  let date = null
  if (isoDate) {
    const [year, month, day] = isoDate.split('-').map(Number)
    if (year && month && day) date = `le ${day === 1 ? '1er' : day} ${MONTHS[month - 1]} ${year}`
  }
  return [place?.trim() || null, date].filter(Boolean).join(', ')
}

export function todayIso() {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

// Formules d'usage, inserees au curseur par l'editeur
export const SALUTATIONS = [
  'Madame, Monsieur,',
  'Madame,',
  'Monsieur,',
  'Maître,',
  'Madame la Directrice, Monsieur le Directeur,',
]

export const CLOSINGS = [
  "Je vous prie d'agréer, Madame, Monsieur, l'expression de mes salutations distinguées.",
  "Dans l'attente de votre réponse, je vous prie d'agréer, Madame, Monsieur, l'expression de mes salutations distinguées.",
  "Je vous prie de croire, Maître, en l'assurance de ma considération distinguée.",
  'Je vous remercie par avance et vous adresse mes salutations distinguées.',
  'Bien cordialement,',
]
