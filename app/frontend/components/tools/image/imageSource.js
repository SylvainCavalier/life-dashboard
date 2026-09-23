// Chargement d'une image dans le navigateur, partage par les outils de l'onglet Images.
import { readAsDataUrl } from '../files'

export const FORMATS = [
  { type: 'image/jpeg', label: 'JPEG', extension: 'jpg' },
  { type: 'image/png', label: 'PNG', extension: 'png' },
  { type: 'image/webp', label: 'WebP', extension: 'webp' },
]

let nextId = 1

function decode(src) {
  return new Promise((resolve, reject) => {
    const image = new Image()
    image.onload = () => resolve(image)
    image.onerror = () => reject(new Error('Format d\'image non pris en charge par le navigateur.'))
    image.src = src
  })
}

// -> { id, src (data URL : la CSP refuse blob: en img_src), name, type, size, width, height }
export async function loadImageSource(file) {
  if (!file.type.startsWith('image/')) throw new Error('Ce fichier n\'est pas une image.')
  const src = await readAsDataUrl(file)
  const image = await decode(src)
  return {
    id: nextId++,
    src,
    name: file.name,
    type: file.type,
    size: file.size,
    width: image.naturalWidth,
    height: image.naturalHeight,
  }
}

// Pixels de l'image, reduite si besoin pour que son plus grand cote tienne dans maxSide.
export async function readPixels(source, maxSide = Infinity) {
  const image = await decode(source.src)
  const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight))
  const canvas = document.createElement('canvas')
  canvas.width = Math.max(Math.round(image.naturalWidth * scale), 1)
  canvas.height = Math.max(Math.round(image.naturalHeight * scale), 1)
  const context = canvas.getContext('2d', { willReadFrequently: true })
  context.drawImage(image, 0, 0, canvas.width, canvas.height)
  return context.getImageData(0, 0, canvas.width, canvas.height)
}
