module Alfred
  # Recherche lexicale insensible aux accents : to_tsvector('french') ne les retire
  # pas (« ecologie » ne trouve pas « écologie »). On plie donc en Ruby le texte
  # indexe ET la requete. Pas de config unaccent cote Postgres : le dumper de
  # schema.rb ne la capture pas et db:schema:load casserait.
  module AccentFolding
    module_function

    # NFD (et non NFKD) : le pliage reste 1:1 en longueur avec l'original.
    def fold(text)
      text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
    end
  end
end
