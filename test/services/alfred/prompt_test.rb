require "test_helper"

class AlfredPromptTest < ActiveSupport::TestCase
  test "le prompt assemble toutes les sections avec leurs textes par defaut" do
    text = Alfred::Prompt.stable_text

    assert text.start_with?("Tu es Alfred")
    Alfred::Prompt::SECTIONS.reject { |s| s[:key] == "role" }.each do |section|
      assert_includes text, "## #{section[:title]}"
    end
    assert_includes text, "Modeles lisibles : #{Alfred::DataAccess::READABLE.keys.first}"
    assert_includes text, "- SBC : admin@sbclabs.fr"
  end

  test "une section surchargee remplace le texte par defaut, une section vidée y revient" do
    setting = AlfredSetting.instance
    setting.merge_overrides!("tone" => "Parle comme un pirate.")

    text = Alfred::Prompt.stable_text
    assert_includes text, "## Ton\nParle comme un pirate."
    assert_not_includes text, "Majordome britannique"
    assert_includes text, "## Ecritures"

    setting.merge_overrides!("tone" => "")
    assert_nil setting.reload.override_for("tone")
    assert_includes Alfred::Prompt.stable_text, "Majordome britannique"
  end

  test "une section inconnue est refusee" do
    assert_raises(ActiveRecord::RecordInvalid) { AlfredSetting.instance.merge_overrides!("hack" => "x") }
  end

  test "les consignes particulieres restent hors du bloc stable" do
    AlfredSetting.instance.update!(custom_instructions: "La fac, c'est l'ICP.")

    assert_not_includes Alfred::Prompt.stable_text, "La fac, c'est l'ICP."
    assert_includes Alfred::Prompt.volatile_block, "## Consignes particulieres de Sylvain\nLa fac, c'est l'ICP."
  end

  test "le catalogue des outils distingue lecture, proposition et Gmail" do
    catalog = Alfred::Tools.catalog

    assert_equal Alfred::Tools::ALL.size, catalog.size
    assert_equal "proposal", catalog.find { |t| t[:name] == "propose_write" }[:kind]
    assert_equal "read", catalog.find { |t| t[:name] == "search_corpus" }[:kind]
    assert_equal "gmail", catalog.find { |t| t[:name] == "search_mails" }[:integration]
    # GMAIL_USER est vide en test : les outils mail sont signales indisponibles.
    assert_equal false, catalog.find { |t| t[:name] == "search_mails" }[:available]
  end
end
