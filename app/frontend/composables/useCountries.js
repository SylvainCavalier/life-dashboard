// Country list and helpers for the Voyages module, derived from the SVG world
// map so that every selectable country can be coloured on the map. French
// names come from Intl.DisplayNames (no extra dependency); a few map ids are
// not ISO codes (e.g. "xk" Kosovo) and fall back to the map's English name.
import World from '@svg-maps/world'

const displayNames = (() => {
  try {
    return new Intl.DisplayNames(['fr'], { type: 'region' })
  } catch {
    return null
  }
})()

export const countryName = (code) => {
  if (!code) return ''
  const upper = code.toUpperCase()
  try {
    const name = displayNames?.of(upper)
    if (name && name !== upper) return name
  } catch {
    // RangeError on non-ISO ids: fall through to the map name
  }
  const location = World.locations.find(l => l.id === code.toLowerCase())
  return location ? location.name : upper
}

// Regional indicator symbols: "fr" -> 🇫🇷
export const flagEmoji = (code) => {
  if (!code || code.length !== 2) return ''
  return String.fromCodePoint(...code.toUpperCase().split('').map(c => 0x1F1E6 + c.charCodeAt(0) - 65))
}

export const COUNTRIES = World.locations
  .map(l => ({ code: l.id, name: countryName(l.id) }))
  .sort((a, b) => a.name.localeCompare(b.name, 'fr'))

export function useCountries() {
  return { COUNTRIES, countryName, flagEmoji, world: World }
}
