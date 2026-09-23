// Rendu des pages PDF en images (pdf.js), pour les vignettes et le placement de
// la signature. Le worker est servi par Vite depuis la meme origine (CSP worker_src 'self').
import * as pdfjs from 'pdfjs-dist'
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url'

pdfjs.GlobalWorkerOptions.workerSrc = workerUrl

export function openPdfPreview(bytes) {
  // pdf.js transfere le buffer a son worker : on lui donne une copie pour
  // garder les octets utilisables par pdf-lib.
  return pdfjs.getDocument({ data: bytes.slice(), isEvalSupported: false }).promise
}

// Rend une page a la largeur voulue (pixels CSS) et renvoie une data URL
// (la CSP autorise data: en img_src, pas blob:). `ratio` = largeur / hauteur
// de la page affichee, en points, rotation comprise.
export async function renderPage(pdf, pageNumber, width, type = 'image/jpeg') {
  const page = await pdf.getPage(pageNumber)
  const base = page.getViewport({ scale: 1 })
  const pixelRatio = Math.min(window.devicePixelRatio || 1, 2)
  const viewport = page.getViewport({ scale: (width / base.width) * pixelRatio })

  const canvas = document.createElement('canvas')
  canvas.width = Math.ceil(viewport.width)
  canvas.height = Math.ceil(viewport.height)
  const context = canvas.getContext('2d')
  context.fillStyle = '#ffffff'
  context.fillRect(0, 0, canvas.width, canvas.height)

  await page.render({ canvas, canvasContext: context, viewport }).promise
  page.cleanup()

  return {
    src: canvas.toDataURL(type, 0.85),
    ratio: base.width / base.height,
  }
}
