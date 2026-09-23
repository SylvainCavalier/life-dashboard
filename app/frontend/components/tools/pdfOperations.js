// Operations sur les PDF, entierement dans le navigateur (pdf-lib) : le fichier
// ne quitte jamais le poste. Chaque operation prend les octets du PDF courant et
// renvoie ceux d'un nouveau PDF, ce qui permet d'enchainer et d'annuler.
import { PDFDocument, StandardFonts, EncryptedPDFError, rgb, degrees } from 'pdf-lib'

export async function loadPdf(bytes) {
  try {
    return await PDFDocument.load(bytes)
  } catch (error) {
    if (error instanceof EncryptedPDFError) {
      throw new Error('Ce PDF est protégé par un mot de passe : impossible de le modifier.')
    }
    throw new Error('Fichier illisible : est-ce bien un PDF ?')
  }
}

// Repere « visuel » : origine en haut a gauche de la page telle qu'elle s'affiche
// (rotation /Rotate appliquee), en points. pdf-lib dessine dans l'espace utilisateur
// non tourne : toUser fait la conversion, et le contenu ajoute doit etre tourne de
// `rotation` degres pour apparaitre droit a l'ecran.
function pageFrame(page) {
  const box = page.getCropBox()
  const rotation = ((page.getRotation().angle % 360) + 360) % 360
  const quarter = rotation === 90 || rotation === 270
  const toUser = (u, v) => {
    switch (rotation) {
      case 90: return { x: box.x + v, y: box.y + u }
      case 180: return { x: box.x + box.width - u, y: box.y + v }
      case 270: return { x: box.x + box.width - v, y: box.y + box.height - u }
      default: return { x: box.x + u, y: box.y + box.height - v }
    }
  }
  return {
    width: quarter ? box.height : box.width,
    height: quarter ? box.width : box.height,
    rotation,
    toUser,
  }
}

// Point d'ancrage (espace utilisateur) tel que le vecteur local (dx, dy), tourne
// de `angle` degres, retombe sur `center`.
function anchorFor(center, dx, dy, angle) {
  const rad = (angle * Math.PI) / 180
  return {
    x: center.x - (dx * Math.cos(rad) - dy * Math.sin(rad)),
    y: center.y - (dx * Math.sin(rad) + dy * Math.cos(rad)),
  }
}

async function embedFont(doc) {
  return doc.embedFont(StandardFonts.HelveticaBold)
}

// Les polices standard ne connaissent que l'encodage WinAnsi (latin de base,
// accents francais compris) : un emoji ou un caractere exotique ferait echouer
// l'enregistrement. On le signale en francais plutot qu'avec l'erreur de pdf-lib.
function assertEncodable(font, text) {
  try {
    font.encodeText(text)
  } catch {
    throw new Error(`Caractère non pris en charge dans « ${text} » (emojis et alphabets non latins exclus).`)
  }
}

function hexToRgb(hex) {
  const value = parseInt(hex.replace('#', ''), 16)
  return rgb(((value >> 16) & 255) / 255, ((value >> 8) & 255) / 255, (value & 255) / 255)
}

export const NUMBER_POSITIONS = [
  { value: 'bottom-left', label: 'En bas à gauche' },
  { value: 'bottom-center', label: 'En bas au centre' },
  { value: 'bottom-right', label: 'En bas à droite' },
  { value: 'top-left', label: 'En haut à gauche' },
  { value: 'top-center', label: 'En haut au centre' },
  { value: 'top-right', label: 'En haut à droite' },
]

export const NUMBER_FORMATS = [
  { value: '{n}', label: '3' },
  { value: '{n} / {total}', label: '3 / 12' },
  { value: 'Page {n}', label: 'Page 3' },
  { value: 'Page {n} sur {total}', label: 'Page 3 sur 12' },
  { value: '- {n} -', label: '- 3 -' },
]

// Numerotation : le numero affiche est celui de la page dans le document
// (decale par `start`) ; `skipFirst` masque seulement celui de la couverture.
export async function addPageNumbers(bytes, { position, format, start = 1, fontSize = 10, margin = 28, skipFirst = false, color = '#333333' }) {
  const doc = await loadPdf(bytes)
  const font = await embedFont(doc)
  const pages = doc.getPages()
  const total = pages.length + start - 1

  pages.forEach((page, index) => {
    if (skipFirst && index === 0) return

    const text = format.replace('{n}', index + start).replace('{total}', total)
    assertEncodable(font, text)
    const frame = pageFrame(page)
    const textWidth = font.widthOfTextAtSize(text, fontSize)
    const [vertical, horizontal] = position.split('-')

    const u = horizontal === 'left' ? margin
      : horizontal === 'right' ? frame.width - margin - textWidth
        : (frame.width - textWidth) / 2
    // Ligne de base : en bas, la marge porte sous le texte ; en haut, au-dessus.
    const v = vertical === 'top' ? margin + fontSize * 0.75 : frame.height - margin

    page.drawText(text, {
      ...frame.toUser(u, v),
      size: fontSize,
      font,
      color: hexToRgb(color),
      rotate: degrees(frame.rotation),
    })
  })

  return doc.save()
}

export async function addWatermark(bytes, { text, fontSize = 60, opacity = 0.2, angle = 45, color = '#9ca3af' }) {
  const doc = await loadPdf(bytes)
  const font = await embedFont(doc)
  assertEncodable(font, text)
  const textWidth = font.widthOfTextAtSize(text, fontSize)
  const capHeight = font.heightAtSize(fontSize, { descender: false })

  doc.getPages().forEach((page) => {
    const frame = pageFrame(page)
    const center = frame.toUser(frame.width / 2, frame.height / 2)
    const totalAngle = frame.rotation + angle
    const anchor = anchorFor(center, textWidth / 2, capHeight / 2, totalAngle)

    page.drawText(text, {
      ...anchor,
      size: fontSize,
      font,
      color: hexToRgb(color),
      opacity,
      rotate: degrees(totalAngle),
    })
  })

  return doc.save()
}

// Appose une image (signature) : `box` est en fractions de la page affichee
// (x, y = coin haut gauche, width = largeur), la hauteur suit les proportions.
export async function addImage(bytes, { dataUrl, pageIndexes, box }) {
  const doc = await loadPdf(bytes)
  const image = dataUrl.startsWith('data:image/png')
    ? await doc.embedPng(dataUrl)
    : await doc.embedJpg(dataUrl)
  const pages = doc.getPages()

  pageIndexes.forEach((index) => {
    const page = pages[index]
    const frame = pageFrame(page)
    const width = box.width * frame.width
    const height = width * (image.height / image.width)
    const u = box.x * frame.width
    const v = box.y * frame.height + height

    page.drawImage(image, {
      ...frame.toUser(u, v),
      width,
      height,
      rotate: degrees(frame.rotation),
    })
  })

  return doc.save()
}

// "1-3, 5, 8-" -> [[0, 2], [4, 4], [7, pageCount - 1]] (index 0, bornes incluses)
export function parseRanges(input, pageCount) {
  const parts = input.split(/[,;]/).map(part => part.trim()).filter(Boolean)
  if (!parts.length) throw new Error('Indiquez au moins une plage, par exemple « 1-3, 4-10 ».')

  return parts.map((part) => {
    const match = part.match(/^(\d*)\s*-\s*(\d*)$/) || part.match(/^(\d+)$/)
    if (!match) throw new Error(`Plage incomprise : « ${part} ».`)

    const from = match[1] ? parseInt(match[1], 10) : 1
    const to = match.length === 2 ? from : (match[2] ? parseInt(match[2], 10) : pageCount)
    if (from < 1 || to > pageCount || from > to) {
      throw new Error(`Plage invalide : « ${part} » (le document a ${pageCount} pages).`)
    }
    return [from - 1, to - 1]
  })
}

export function rangesEvery(size, pageCount) {
  const ranges = []
  for (let from = 0; from < pageCount; from += size) {
    ranges.push([from, Math.min(from + size, pageCount) - 1])
  }
  return ranges
}

export async function splitPdf(bytes, ranges) {
  const source = await loadPdf(bytes)

  return Promise.all(ranges.map(async ([from, to]) => {
    const part = await PDFDocument.create()
    const indexes = Array.from({ length: to - from + 1 }, (_, i) => from + i)
    const pages = await part.copyPages(source, indexes)
    pages.forEach(page => part.addPage(page))
    return {
      label: from === to ? `Page ${from + 1}` : `Pages ${from + 1} à ${to + 1}`,
      suffix: from === to ? `p${from + 1}` : `p${from + 1}-${to + 1}`,
      bytes: await part.save(),
    }
  }))
}
