require "test_helper"
require_relative "support"

class AlfredSearchTest < ActiveSupport::TestCase
  include AlfredTestSupport

  setup do
    @note = Note.create!(title: "Note", content: "x")
  end

  def chunk!(content, vector, position:, date: nil, source: @note)
    AlfredChunk.create!(source: source, kind: "record", position: position, label: content.truncate(30),
                        content: content, source_date: date, embedding: vector)
  end

  def search(query, mapping, **opts)
    Alfred::Corpus::Search.call(query: query, embedding_provider: FakeEmbeddings.new(mapping), **opts)
  end

  test "sous le plancher de similarite, rien ne remonte" do
    chunk!("recette de la tarte aux pommes", AlfredTestSupport.axis(0, 1), position: 0)

    assert_empty search("bail appartement", { "bail" => AlfredTestSupport.axis(1, 0) })
  end

  test "le bras lexical reclasse mais n'elargit jamais l'ensemble eligible" do
    # Contient le mot exact de la requete, mais semantiquement hors sujet (cosine 0).
    chunk!("assurance MAIF habitation", AlfredTestSupport.axis(0, 1), position: 0)
    relevant = chunk!("contrat du logement", AlfredTestSupport.axis(1, 0), position: 1)

    hits = search("MAIF", { "MAIF" => AlfredTestSupport.axis(1, 0) }, hybrid: true)

    assert_equal [relevant.id], hits.map { |hit| hit.chunk.id }
  end

  test "la recherche lexicale ignore les accents" do
    chunk!("Déclaration de revenus, impôts 2025", AlfredTestSupport.axis(1, 0.2), position: 0)
    other = chunk!("Taxe fonciere", AlfredTestSupport.axis(1, 0.1), position: 1)

    hits = search("impots", { "impots" => AlfredTestSupport.axis(1, 0) }, hybrid: true)

    # `other` a le meilleur cosine, mais le mot exact (sans accent) fait passer la declaration devant.
    assert_equal "Déclaration de revenus, impôts 2025", hits.first.chunk.content
    assert_includes hits.map { |hit| hit.chunk.id }, other.id
  end

  test "le meilleur cosine brut survit a la coupe malgre son anciennete" do
    old_best = chunk!("bail de 2012", AlfredTestSupport.axis(1, 0), position: 0, date: Date.new(2012, 1, 1))
    3.times do |i|
      other = Note.create!(title: "Autre #{i}", content: "x")
      chunk!("document recent #{i}", AlfredTestSupport.axis(1, 0.05), position: 0, date: Date.current, source: other)
    end

    hits = search("bail", { "bail" => AlfredTestSupport.axis(1, 0) }, top_k: 2, hybrid: false)

    assert_equal 2, hits.size
    assert_includes hits.map { |hit| hit.chunk.id }, old_best.id
  end

  test "le filtre par type de source ignore les modeles hors registre" do
    chunk!("bail", AlfredTestSupport.axis(1, 0), position: 0)

    assert_empty search("bail", { "bail" => AlfredTestSupport.axis(1, 0) }, source_types: ["Contact"])
    assert_equal 1, search("bail", { "bail" => AlfredTestSupport.axis(1, 0) }, source_types: ["PasswordEntry"]).size
  end
end
