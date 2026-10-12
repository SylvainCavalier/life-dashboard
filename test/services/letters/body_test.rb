require "test_helper"

class Letters::BodyTest < ActiveSupport::TestCase
  def text(value, marks = [])
    node = { "type" => "text", "text" => value }
    node["marks"] = marks.map { |m| { "type" => m } } if marks.any?
    node
  end

  def paragraph(*inline, align: nil)
    node = { "type" => "paragraph", "content" => inline }
    node["attrs"] = { "textAlign" => align } if align
    node
  end

  test "sanitize ne garde que les noeuds, marques et alignements connus" do
    doc = { "type" => "doc", "content" => [
      paragraph(text("Gras", %w[bold link]), text(" et barré", %w[strike]), align: "justify"),
      { "type" => "heading", "attrs" => { "level" => 1 }, "content" => [text("Titre")] },
      { "type" => "codeBlock" },
      paragraph(text("Gauche"), align: "left"),
      paragraph(text("Bizarre"), align: "diagonal")
    ] }

    clean = Letters::Body.sanitize(doc)

    assert_equal [{ "type" => "bold" }], clean["content"][0]["content"][0]["marks"]
    assert_nil clean["content"][0]["content"][1]["marks"]
    assert_equal({ "textAlign" => "justify" }, clean["content"][0]["attrs"])
    assert_equal paragraph(text("Titre")), clean["content"][1], "un noeud inconnu garde son texte"
    assert_equal 4, clean["content"].size, "un noeud inconnu sans texte disparait"
    assert_nil clean["content"][2]["attrs"]
    assert_nil clean["content"][3]["attrs"]
  end

  test "sanitize accepte une chaine JSON et refuse le reste" do
    assert_equal Letters::Body.empty_doc, Letters::Body.sanitize("pas du json")
    assert_equal Letters::Body.empty_doc, Letters::Body.sanitize(nil)
    assert_equal "Salut", Letters::Body.to_text(Letters::Body.sanitize({ type: "doc", content: [paragraph(text("Salut"))] }.to_json))
  end

  test "from_text et to_text font l'aller-retour, sauts de ligne compris" do
    source = "Madame,\n\nPremière ligne\nseconde ligne\n\nSalutations."
    doc = Letters::Body.from_text(source)

    assert_equal 3, doc["content"].size
    assert_equal "hardBreak", doc["content"][1]["content"][1]["type"]
    assert_equal source, Letters::Body.to_text(doc)
  end

  test "blocks aplatit les listes imbriquees avec puces, numeros et niveaux" do
    doc = { "type" => "doc", "content" => [
      { "type" => "orderedList", "attrs" => { "start" => 3 }, "content" => [
        { "type" => "listItem", "content" => [
          paragraph(text("Trois")),
          { "type" => "bulletList", "content" => [{ "type" => "listItem", "content" => [paragraph(text("Puce"))] }] }
        ] },
        { "type" => "listItem", "content" => [paragraph(text("Quatre", %w[italic]))] }
      ] }
    ] }

    blocks = Letters::Body.blocks(doc)

    assert_equal(%w[3. • 4.], blocks.map { |b| b[:marker] })
    assert_equal [0, 1, 0], blocks.map { |b| b[:level] }
    assert blocks.last[:runs].first[:italic]
  end
end
