import StarterKit from '@tiptap/starter-kit'
import TextAlign from '@tiptap/extension-text-align'

// Extensions Tiptap de l'editeur ET de l'apercu (generateHTML). Seuls les noeuds que
// les rendus PDF / DOCX savent traiter (Letters::Body) sont actives : paragraphes
// alignes, listes, gras, italique, souligne.
export const letterExtensions = () => [
  StarterKit.configure({
    heading: false,
    blockquote: false,
    codeBlock: false,
    code: false,
    horizontalRule: false,
    strike: false,
    link: false,
  }),
  TextAlign.configure({ types: ['paragraph'], alignments: ['left', 'center', 'right', 'justify'] }),
]
