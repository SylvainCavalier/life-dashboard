// Outil Videos : affichage partage entre la liste et le detail d'une transcription.
export { formatDateTime, formatDuration, timecode } from '../../../utils/meetingFormat'

export const STEP_LABELS = {
  transcribe: 'Transcription',
  summarize: 'Résumé',
}

export const statusLabel = (transcript) => {
  if (transcript.in_progress) return transcript.step ? `${STEP_LABELS[transcript.step]}...` : 'En attente...'
  if (transcript.status === 'failed') return 'Échec'
  if (transcript.status === 'done') return 'Terminée'
  return 'En attente'
}

export const statusClass = (transcript) => {
  if (transcript.in_progress) return 'bg-blue-50 text-blue-700'
  if (transcript.status === 'failed') return 'bg-red-50 text-red-700'
  if (transcript.status === 'done') return 'bg-emerald-50 text-emerald-700'
  return 'bg-gray-100 text-gray-600'
}

// DirectUpload (@rails/activestorage) rejette avec une simple chaine
// (« Error storing "x.mp4". Status: 0 ») : la garder, c'est le seul indice de la cause.
export const errorOf = (e, fallback = 'Opération impossible.') =>
  (typeof e === 'string' && e) || e?.response?.data?.errors?.join(', ') || e?.message || fallback
