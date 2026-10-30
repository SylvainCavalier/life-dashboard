require "test_helper"

class ScriptTest < ActiveSupport::TestCase
  test "compte les mots et estime la duree a voix haute" do
    script = build(:script, body: "Aujourd'hui, on démonte une rumeur très tenace. " * 30)

    assert_equal 210, script.word_count
    assert_equal 84, script.estimated_duration
  end

  test "decoupe un thread sur les lignes ---" do
    script = build(:script, kind: "thread", body: "Premier message\n\n---\n\nDeuxième\n  ----  \n\n---\nTroisième")

    assert_equal ["Premier message", "Deuxième", "Troisième"], script.thread_posts
    assert_equal 3, script.api_attributes[:posts_count]
  end

  test "date la publication quand le statut passe a publie" do
    script = create(:script)
    script.update!(status: "published")
    assert_equal Date.current, script.published_on

    script.update!(published_on: Date.new(2026, 1, 5), status: "ready")
    script.update!(status: "published")
    assert_equal Date.new(2026, 1, 5), script.published_on
  end

  test "refuse un format ou un statut inconnu" do
    assert_not build(:script, kind: "podcast").valid?
    assert_not build(:script, status: "en_cours").valid?
  end

  test "supprimer un dossier garde ses scripts, sans dossier" do
    folder = create(:script_folder)
    script = create(:script, script_folder: folder)

    folder.destroy

    assert_nil script.reload.script_folder_id
  end

  test "un nom de dossier est unique sans tenir compte de la casse" do
    create(:script_folder, name: "Debunker des Étoiles")
    assert_not build(:script_folder, name: "DEBUNKER des Étoiles").valid?
  end
end
