require "test_helper"

# annotaterb considere comme son bloc tout commentaire colle sous l'annotation : a chaque
# passage, il efface le commentaire de classe qui la suit sans ligne vide. Ce test garde la
# ligne vide de separation. Un commentaire place au-dessus de l'annotation ne risque rien.
class SchemaAnnotationsTest < ActiveSupport::TestCase
  HEADER = "# == Schema Information".freeze
  ANNOTATION_LINE = /\A#(\s*\z|  |\sTable name:|\s(Indexes|Foreign Keys|Check Constraints)\s*\z)/

  test "aucun commentaire n'est colle a un bloc d'annotation" do
    glued = Dir[Rails.root.join("{app/models,test/models,test/factories}/**/*.rb")].filter_map do |file|
      lines = File.readlines(file, chomp: true)
      start = lines.index(HEADER) or next
      finish = start + 1
      finish += 1 while finish < lines.size && lines[finish].match?(ANNOTATION_LINE)
      Pathname(file).relative_path_from(Rails.root).to_s if finish < lines.size && lines[finish].start_with?("#")
    end

    assert_empty glued, "Separer l'annotation du commentaire par une ligne vide : #{glued.join(', ')}"
  end
end
