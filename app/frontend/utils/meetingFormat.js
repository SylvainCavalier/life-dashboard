// Module Reunions : affichage partage entre la liste et la page d'une reunion.

export const STEP_LABELS = {
  transcribe: 'Transcription',
  summarize: 'Synthese',
  render: 'Compte rendu PDF',
}

export const formatDateTime = (value) => {
  if (!value) return ''
  return new Date(value).toLocaleString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}

export const formatDuration = (seconds) => {
  if (!seconds) return ''
  const h = Math.floor(seconds / 3600)
  const m = Math.round((seconds % 3600) / 60)
  return h ? `${h} h ${String(m).padStart(2, '0')}` : `${m} min`
}

export const timecode = (seconds) => {
  const total = Math.floor(seconds || 0)
  const h = Math.floor(total / 3600)
  const m = String(Math.floor((total % 3600) / 60)).padStart(2, '0')
  const s = String(total % 60).padStart(2, '0')
  return h ? `${h}:${m}:${s}` : `${m}:${s}`
}

export const statusLabel = (meeting) => {
  if (meeting.status === 'recording') return 'Enregistrement'
  if (meeting.in_progress) return meeting.step ? `${STEP_LABELS[meeting.step]}...` : 'En attente...'
  if (meeting.status === 'failed') return 'Echec'
  if (meeting.status === 'done') return 'Termine'
  return 'En attente'
}

export const statusClass = (meeting) => {
  if (meeting.status === 'recording') return 'bg-red-50 text-red-700'
  if (meeting.in_progress) return 'bg-blue-50 text-blue-700'
  if (meeting.status === 'failed') return 'bg-red-50 text-red-700'
  if (meeting.status === 'done') return 'bg-emerald-50 text-emerald-700'
  return 'bg-gray-100 text-gray-600'
}
