// Rendu Markdown minimal pour les reponses d'Alfred. Le texte est ECHAPPE avant
// toute mise en forme : le HTML produit ne contient que les balises posees ici,
// il peut donc etre injecte par v-html. Liens : uniquement http(s) ou chemins
// internes (« /contacts ») ; tout le reste (javascript:, data:...) reste du texte.
const escapeHtml = (text) =>
  text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')

const SAFE_URL = /^(https?:\/\/|\/(?!\/))[^\s]*$/

// Marqueurs de citation ([[Document#12]]) : le serveur les retire de la reponse
// finale et en fait les sources ; on les masque pendant qu'elle s'ecrit.
const CITATION = / ?\[\[[A-Z][A-Za-z]+#\d+\]\]/g

const inline = (text) =>
  text
    .replace(/`([^`]+)`/g, '<code class="px-1 py-0.5 rounded bg-gray-100 text-[0.85em]">$1</code>')
    .replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (match, label, url) => {
      const href = url.replace(/&amp;/g, '&')
      if (!SAFE_URL.test(href)) return match
      // Pages du dashboard : navigation par le routeur (voir AlfredWidget). Fichiers et sites : nouvel onglet.
      const internal = href.startsWith('/') && !href.startsWith('/api/') && !href.startsWith('/rails/')
      const attrs = internal ? 'data-internal="true"' : 'target="_blank" rel="noopener noreferrer"'
      return `<a href="${url}" ${attrs} class="text-indigo-600 underline hover:text-indigo-800">${label}</a>`
    })
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[\s(])\*([^*\s][^*]*)\*/g, '$1<em>$2</em>')

export function renderMarkdown(source) {
  const lines = escapeHtml((source || '').replace(CITATION, '')).split('\n')
  const html = []
  let list = null // 'ul' | 'ol'
  let code = null

  const closeList = () => {
    if (list) html.push(`</${list}>`)
    list = null
  }

  for (const line of lines) {
    if (line.trim().startsWith('```')) {
      if (code === null) {
        closeList()
        code = []
      } else {
        html.push(`<pre class="my-2 p-2 rounded bg-gray-100 text-xs overflow-x-auto"><code>${code.join('\n')}</code></pre>`)
        code = null
      }
      continue
    }
    if (code !== null) {
      code.push(line)
      continue
    }

    const heading = line.match(/^(#{1,4})\s+(.*)$/)
    const bullet = line.match(/^\s*[-*]\s+(.*)$/)
    const ordered = line.match(/^\s*\d+[.)]\s+(.*)$/)

    if (heading) {
      closeList()
      html.push(`<p class="font-semibold mt-3 mb-1">${inline(heading[2])}</p>`)
    } else if (bullet || ordered) {
      const tag = bullet ? 'ul' : 'ol'
      if (list !== tag) {
        closeList()
        html.push(tag === 'ul' ? '<ul class="list-disc pl-5 my-1 space-y-0.5">' : '<ol class="list-decimal pl-5 my-1 space-y-0.5">')
        list = tag
      }
      html.push(`<li>${inline((bullet || ordered)[1])}</li>`)
    } else if (line.trim() === '') {
      closeList()
    } else {
      closeList()
      html.push(`<p class="my-1">${inline(line)}</p>`)
    }
  }
  closeList()
  if (code !== null) html.push(`<pre class="my-2 p-2 rounded bg-gray-100 text-xs overflow-x-auto"><code>${code.join('\n')}</code></pre>`)
  return html.join('')
}
