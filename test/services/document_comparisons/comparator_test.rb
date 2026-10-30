require "test_helper"

class DocumentComparisons::ComparatorTest < ActiveSupport::TestCase
  # Extraction de texte factice : [texte, extracteur], comme Alfred::Corpus::TextExtractor.
  class FakeTextExtractor
    def initialize(texts) = @texts = texts
    def call(blob) = [@texts.fetch(blob.filename.to_s), "pdf_reader"]
  end

  FIELDS = {
    "title_a" => "Contrat de travail CDI - version 1", "title_b" => "Contrat de travail CDI - version 2",
    "relationship" => "versions", "verdict" => "La version 2 allonge la période d'essai.",
    "summary" => "Deux versions du même contrat.",
    "similarities" => [{ "topic" => "Rémunération", "detail" => "3 000 € bruts mensuels" }, { "topic" => " ", "detail" => "x" }],
    "differences" => [
      { "topic" => "Mise en page", "document_a" => "Arial", "document_b" => "Times", "importance" => "low" },
      { "topic" => "Période d'essai", "document_a" => "2 mois", "document_b" => "4 mois", "importance" => "high" },
      { "topic" => "Mobilité", "document_a" => "Absent", "document_b" => "Île-de-France", "importance" => "inconnue" }
    ],
    "only_in_a" => ["Clause de télétravail", ""], "only_in_b" => [],
    "attention_points" => ["Clause de mobilité ajoutée"]
  }.freeze

  def blob(filename)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4"), filename: filename, content_type: "application/pdf")
  end

  test "normalize ecarte les entrees vides et trie les differences par importance" do
    result = DocumentComparisons::Comparator.normalize(FIELDS)

    assert_equal "versions", result[:relationship]
    assert_equal ["Rémunération"], result[:similarities].pluck(:topic)
    assert_equal ["Période d'essai", "Mobilité", "Mise en page"], result[:differences].pluck(:topic)
    assert_equal "medium", result[:differences].second[:importance]
    assert_equal ["Clause de télétravail"], result[:only_in_a]
  end

  test "une relation inconnue devient different" do
    assert_equal "different", DocumentComparisons::Comparator.normalize(FIELDS.merge("relationship" => "cousins"))[:relationship]
  end

  test "envoie les deux textes et la consigne, signale un document tronque" do
    long = "b" * (DocumentComparisons::Comparator::MAX_CHARS + 10)
    comparator = DocumentComparisons::Comparator.new(api_key: "test", text_extractor: FakeTextExtractor.new("a.pdf" => "Texte du contrat A, assez long.", "b.pdf" => long))
    sent = nil
    comparator.define_singleton_method(:compare) do |text_a, text_b, focus|
      sent = { text_a: text_a, text_b: text_b, focus: focus }
      FIELDS
    end

    outcome = comparator.call(blob("a.pdf"), blob("b.pdf"), focus: "La période d'essai")

    assert_equal "Texte du contrat A, assez long.", sent[:text_a]
    assert_equal DocumentComparisons::Comparator::MAX_CHARS, sent[:text_b].length
    assert_equal "La période d'essai", sent[:focus]
    assert outcome[:result][:truncated]
    assert_equal({ a: "pdf_reader", b: "pdf_reader" }, outcome[:extractors])
  end

  test "un document sans texte lisible fait echouer la comparaison" do
    comparator = DocumentComparisons::Comparator.new(api_key: "test", text_extractor: FakeTextExtractor.new("a.pdf" => "Texte du contrat A, assez long.", "b.pdf" => " "))
    error = assert_raises(DocumentComparisons::Error) { comparator.call(blob("a.pdf"), blob("b.pdf")) }
    assert_match "second document", error.message
  end
end
