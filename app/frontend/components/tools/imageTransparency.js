// Suppression d'un fond uni (facon « baguette magique ») : pas de modele d'IA,
// c'est exact et instantane tant que le fond est d'une seule couleur.
//
// - La couleur du fond est deduite des bords de l'image (detectBackground).
// - Distance a cette couleur : sous `tolerance`, le pixel devient transparent ;
//   dans la bande `softness` au-dessus, il devient semi-transparent (bords lisses).
// - Mode `connected` : seul le fond relie aux bords est retire (le blanc d'un oeil
//   ou l'interieur d'une lettre restent) ; mode `global` : toute la couleur disparait.
// - Decontamination : un pixel de contour est un melange sujet + fond ; on retire
//   la part du fond pour eviter le liseré clair une fois pose sur un fond sombre.

const MAX_DISTANCE = Math.sqrt(3 * 255 * 255)

function distance(data, offset, color) {
  const dr = data[offset] - color.r
  const dg = data[offset + 1] - color.g
  const db = data[offset + 2] - color.b
  return Math.sqrt(dr * dr + dg * dg + db * db)
}

// Couleur dominante du pourtour : on regroupe les pixels du bord par classes
// de couleur, puis on moyenne la classe la plus peuplee.
export function detectBackground({ data, width, height }) {
  const buckets = new Map()
  const add = (x, y) => {
    const offset = (y * width + x) * 4
    if (data[offset + 3] < 128) return
    const key = (data[offset] >> 4) << 8 | (data[offset + 1] >> 4) << 4 | (data[offset + 2] >> 4)
    const bucket = buckets.get(key) || { count: 0, r: 0, g: 0, b: 0 }
    bucket.count++
    bucket.r += data[offset]
    bucket.g += data[offset + 1]
    bucket.b += data[offset + 2]
    buckets.set(key, bucket)
  }
  for (let x = 0; x < width; x++) { add(x, 0); add(x, height - 1) }
  for (let y = 0; y < height; y++) { add(0, y); add(width - 1, y) }

  let best = null
  for (const bucket of buckets.values()) {
    if (!best || bucket.count > best.count) best = bucket
  }
  if (!best) return { r: 255, g: 255, b: 255 }
  return {
    r: Math.round(best.r / best.count),
    g: Math.round(best.g / best.count),
    b: Math.round(best.b / best.count),
  }
}

// tolerance et softness en pourcentage (0-100). Renvoie une nouvelle ImageData.
export function removeBackground(source, { color, tolerance = 12, softness = 10, mode = 'connected', decontaminate = true }) {
  const { width, height, data } = source
  const threshold = (tolerance / 100) * MAX_DISTANCE
  const band = Math.max((softness / 100) * MAX_DISTANCE, 0.0001)
  const pixelCount = width * height

  // Alpha calcule pour chaque pixel (1 = garde, 0 = transparent) ; -1 = pas encore vu
  const alpha = new Float32Array(pixelCount).fill(-1)
  const distances = new Float32Array(pixelCount)
  for (let i = 0; i < pixelCount; i++) distances[i] = distance(data, i * 4, color)

  const alphaFor = (d) => (d <= threshold ? 0 : d >= threshold + band ? 1 : (d - threshold) / band)

  if (mode === 'global') {
    for (let i = 0; i < pixelCount; i++) alpha[i] = alphaFor(distances[i])
  } else {
    // Remplissage depuis les bords. On traverse librement le fond franc ; dans
    // la bande de transition on ne progresse que vers des pixels plus eloignes
    // du fond (on suit le degrade de l'anticrenelage sans s'engouffrer dans le sujet).
    const queue = new Int32Array(pixelCount)
    let head = 0
    let tail = 0
    const visit = (i, from) => {
      if (alpha[i] !== -1) return
      const d = distances[i]
      if (d >= threshold + band) return
      if (from !== -1 && distances[from] > threshold && d < distances[from]) return
      alpha[i] = alphaFor(d)
      queue[tail++] = i
    }
    for (let x = 0; x < width; x++) { visit(x, -1); visit((height - 1) * width + x, -1) }
    for (let y = 0; y < height; y++) { visit(y * width, -1); visit(y * width + width - 1, -1) }

    while (head < tail) {
      const i = queue[head++]
      const x = i % width
      if (x > 0) visit(i - 1, i)
      if (x < width - 1) visit(i + 1, i)
      if (i >= width) visit(i - width, i)
      if (i < pixelCount - width) visit(i + width, i)
    }
  }

  for (let i = 0; i < pixelCount; i++) if (alpha[i] === -1) alpha[i] = 1
  if (decontaminate) matteEdges(data, width, height, alpha, distances, color)

  const result = new ImageData(new Uint8ClampedArray(data), width, height)
  const out = result.data
  for (let i = 0; i < pixelCount; i++) {
    const a = alpha[i]
    if (a >= 1) continue
    const offset = i * 4
    if (decontaminate && a > 0.02) {
      out[offset] = (data[offset] - (1 - a) * color.r) / a
      out[offset + 1] = (data[offset + 1] - (1 - a) * color.g) / a
      out[offset + 2] = (data[offset + 2] - (1 - a) * color.b) / a
    }
    // Un PNG deja partiellement transparent garde sa transparence d'origine.
    out[offset + 3] = Math.round(data[offset + 3] * a)
  }
  return result
}

// Contour anticrenele : un pixel garde, voisin du fond retire, est souvent un
// melange sujet/fond trop eloigne du fond pour la bande `softness` (rose entre
// rouge et blanc). On estime la couleur du sujet F sur les pixels pleins voisins,
// puis la part de sujet a = projection de (C - B) sur (F - B).
function matteEdges(data, width, height, alpha, distances, color) {
  const pixelCount = width * height
  const ring = new Uint8Array(pixelCount)
  for (let i = 0; i < pixelCount; i++) {
    if (alpha[i] < 1) continue
    const x = i % width
    if ((x > 0 && alpha[i - 1] <= 0.5) || (x < width - 1 && alpha[i + 1] <= 0.5)
      || (i >= width && alpha[i - width] <= 0.5) || (i < pixelCount - width && alpha[i + width] <= 0.5)) {
      ring[i] = 1
    }
  }

  const RADIUS = 2
  const updates = []
  for (let i = 0; i < pixelCount; i++) {
    if (!ring[i]) continue
    const x = i % width
    const y = (i - x) / width
    let count = 0
    let fr = 0
    let fg = 0
    let fb = 0
    for (let dy = -RADIUS; dy <= RADIUS; dy++) {
      const ny = y + dy
      if (ny < 0 || ny >= height) continue
      for (let dx = -RADIUS; dx <= RADIUS; dx++) {
        const nx = x + dx
        if (nx < 0 || nx >= width) continue
        const j = ny * width + nx
        if (ring[j] || alpha[j] < 1 || distances[j] < distances[i]) continue
        const o = j * 4
        fr += data[o]; fg += data[o + 1]; fb += data[o + 2]
        count++
      }
    }
    if (!count) continue

    const vr = fr / count - color.r
    const vg = fg / count - color.g
    const vb = fb / count - color.b
    const norm = vr * vr + vg * vg + vb * vb
    if (norm < 1) continue
    const o = i * 4
    const a = ((data[o] - color.r) * vr + (data[o + 1] - color.g) * vg + (data[o + 2] - color.b) * vb) / norm
    if (a < 0.98) updates.push([i, Math.min(Math.max(a, 0), 1)])
  }
  // Ecriture apres coup : l'estimation d'un pixel ne doit pas dependre de ses voisins deja traites.
  for (const [i, a] of updates) alpha[i] = a
}

export function toHex({ r, g, b }) {
  return `#${[r, g, b].map(v => v.toString(16).padStart(2, '0')).join('')}`
}

export function fromHex(hex) {
  const value = parseInt(hex.replace('#', ''), 16)
  return { r: (value >> 16) & 255, g: (value >> 8) & 255, b: value & 255 }
}
