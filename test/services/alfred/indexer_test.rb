require "test_helper"
require_relative "support"

class AlfredIndexerTest < ActiveSupport::TestCase
  include AlfredTestSupport

  test "le coffre-fort et les comptes mail sont hors du corpus et hors de la lecture" do
    assert_not_includes Alfred::Corpus::REGISTRY.keys, "PasswordEntry"
    assert_not_includes Alfred::Corpus::REGISTRY.keys, "MailAccount"
    assert_not_includes Alfred::DataAccess::READABLE.keys, "PasswordEntry"
    assert_not_includes Alfred::DataAccess::WRITABLE.keys, "PasswordEntry"
    assert_not_includes Alfred::DataAccess::WRITABLE.keys, "MailAccount"
    assert_not_includes Alfred::DataAccess.readable_fields("MailAccount"), "password"
  end

  test "les attributs chiffres ne sont jamais recopies en clair dans le corpus" do
    profile = PersonalProfile.new(iban: "FR7612345678901234567890123", social_security_number: "1850775123456")
    profile.save!(validate: false)

    text = Alfred::Corpus::RecordRenderer.new(profile).text

    assert_no_match(/FR76/, text)
    assert_no_match(/1850775123456/, text)
  end

  test "un enregistrement inchange n'est pas revectorise" do
    note = Note.create!(title: "Garagiste", content: "Revision de la voiture chez Martin en mars")
    provider = FakeEmbeddings.new

    first = Alfred::Corpus::Indexer.call(note, embedding_provider: provider)
    second = Alfred::Corpus::Indexer.call(note, embedding_provider: provider)

    assert_equal "indexed", first.status
    assert_not first.skipped
    assert second.skipped
    assert_equal 1, provider.calls
    assert_equal 1, AlfredChunk.for_source(note).count
    assert_match "Garagiste", AlfredChunk.for_source(note).first.content
  end

  test "une modification remplace les passages" do
    note = Note.create!(title: "Garagiste", content: "Martin")
    provider = FakeEmbeddings.new
    Alfred::Corpus::Indexer.call(note, embedding_provider: provider)

    note.update!(content: "Dupuis, rue de la Gare")
    Alfred::Corpus::Indexer.call(note, embedding_provider: provider)

    contents = AlfredChunk.for_source(note).pluck(:content)
    assert_equal 1, contents.size
    assert_match "Dupuis", contents.first
  end

  test "un modele enfant renvoie vers son parent" do
    project = create(:project)
    skill = project.project_skills.create!(name: "Rust")

    assert_equal project, Alfred::Corpus.root_for(skill)
    assert_match "Rust", Alfred::Corpus::RecordRenderer.new(project.reload).text
  end
end
