module Letters
  # Gabarit d'une lettre francaise classique sur A4, en millimetres. Deux placements du
  # destinataire (Letter#window_envelope) : compact par defaut, au niveau de l'expediteur,
  # pour laisser la place au texte ; ou dans la fenetre d'une enveloppe DL (110 mm du bord
  # gauche, 50 mm du haut), la date ne remontant alors jamais au-dessus de 95 mm.
  # Les memes valeurs sont reprises par l'apercu de la page Courrier
  # (components/letters/LetterPreview.vue) et par le DOCX : a modifier ensemble.
  module Layout
    PAGE_WIDTH = 210
    PAGE_HEIGHT = 297
    MARGIN_TOP = 15
    MARGIN_SIDE = 20
    MARGIN_BOTTOM = 25 # zone du pied de page comprise

    SENDER_WIDTH = 85
    RECIPIENT_LEFT = 110
    RECIPIENT_WIDTH = 80
    WINDOW_RECIPIENT_TOP = 50 # enveloppe a fenetre seulement
    WINDOW_DATE_TOP = 95 # idem : la date passe sous la fenetre
    BLOCK_GAP = 6 # entre adresses, date, objet, contenu et signature

    SIGNATURE_LEFT = 110
    SIGNATURE_MAX_WIDTH = 50
    SIGNATURE_MAX_HEIGHT = 22

    FONT_SIZE = 10
    SMALL_FONT_SIZE = 7.5
    LINE_HEIGHT = 1.35
    PARAGRAPH_SPACING = 6 # points apres chaque paragraphe
    LIST_ITEM_SPACING = 2 # points apres chaque element de liste
    LIST_INDENT = 6 # mm par niveau de liste

    CONTENT_WIDTH = PAGE_WIDTH - (2 * MARGIN_SIDE)

    def self.recipient_top(window_envelope) = window_envelope ? WINDOW_RECIPIENT_TOP : MARGIN_TOP
    def self.date_top(window_envelope) = window_envelope ? WINDOW_DATE_TOP : MARGIN_TOP
  end
end
