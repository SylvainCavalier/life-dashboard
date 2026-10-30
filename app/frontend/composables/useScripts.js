// Listes et calculs de la page Scripts (memes cles et memes regles que Script et ScriptFolder).
import { formatDate } from './useInsurances'

export { formatDate }

export const platforms = [
  { value: 'youtube', label: 'YouTube', icon: '▶️', badge: 'bg-red-100 text-red-700' },
  { value: 'x', label: 'X / Twitter', icon: '𝕏', badge: 'bg-gray-900 text-white' },
  { value: 'instagram', label: 'Instagram', icon: '📸', badge: 'bg-pink-100 text-pink-700' },
  { value: 'tiktok', label: 'TikTok', icon: '🎵', badge: 'bg-gray-100 text-gray-800' },
  { value: 'linkedin', label: 'LinkedIn', icon: '💼', badge: 'bg-sky-100 text-sky-700' },
  { value: 'facebook', label: 'Facebook', icon: '📘', badge: 'bg-blue-100 text-blue-700' },
  { value: 'bluesky', label: 'Bluesky', icon: '🦋', badge: 'bg-sky-100 text-sky-600' },
  { value: 'threads', label: 'Threads', icon: '🧵', badge: 'bg-gray-100 text-gray-800' },
  { value: 'podcast', label: 'Podcast', icon: '🎙️', badge: 'bg-purple-100 text-purple-700' },
  { value: 'other', label: 'Autre', icon: '📁', badge: 'bg-gray-100 text-gray-600' },
]

export const kinds = [
  { value: 'video', label: 'Vidéo', icon: '🎬' },
  { value: 'short', label: 'Short / Reel', icon: '📱' },
  { value: 'thread', label: 'Thread', icon: '🧵' },
  { value: 'post', label: 'Post', icon: '💬' },
  { value: 'other', label: 'Autre', icon: '📄' },
]

export const statuses = [
  { value: 'idea', label: 'Idée', badge: 'bg-amber-100 text-amber-700' },
  { value: 'draft', label: 'Brouillon', badge: 'bg-gray-100 text-gray-700' },
  { value: 'review', label: 'À relire', badge: 'bg-indigo-100 text-indigo-700' },
  { value: 'ready', label: 'Prêt', badge: 'bg-emerald-100 text-emerald-700' },
  { value: 'published', label: 'Publié', badge: 'bg-emerald-600 text-white' },
  { value: 'abandoned', label: 'Abandonné', badge: 'bg-gray-100 text-gray-400 line-through' },
]

const index = (list) => Object.fromEntries(list.map(item => [item.value, item]))
const platformsByValue = index(platforms)
const kindsByValue = index(kinds)
const statusesByValue = index(statuses)

export const platformOf = (value) => platformsByValue[value] || platformsByValue.other
export const kindOf = (value) => kindsByValue[value] || kindsByValue.other
export const statusOf = (value) => statusesByValue[value] || statusesByValue.draft

// Script::WORDS_PER_MINUTE et Script::POST_MAX_CHARS
export const WORDS_PER_MINUTE = 150
export const POST_MAX_CHARS = 280

// Meme decoupage que Script#word_count (les mots composes et elisions comptent pour un).
export const wordCount = (text) => (text.match(/[\p{L}\p{N}]+(?:['’-][\p{L}\p{N}]+)*/gu) || []).length

// Caracteres tels qu'un humain les compte (un emoji = 1), approximation du compteur de X.
export const charCount = (text) => [...text].length

export const estimatedSeconds = (words) => Math.round((words * 60) / WORDS_PER_MINUTE)

export const formatDuration = (seconds) => {
  if (!seconds) return '0 s'
  const minutes = Math.floor(seconds / 60)
  const rest = seconds % 60
  if (!minutes) return `${rest} s`
  return rest ? `${minutes} min ${String(rest).padStart(2, '0')}` : `${minutes} min`
}

// Script#thread_posts : une ligne « --- » separe deux messages.
export const THREAD_SEPARATOR = '\n\n---\n\n'
export const splitThread = (text) => text.split(/^[ \t]*-{3,}[ \t]*$/m).map(post => post.trim()).filter(Boolean)
