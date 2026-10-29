require "test_helper"

class ShoppingItemTest < ActiveSupport::TestCase
  test "un article n'est qu'une fois dans la liste, casse ignoree" do
    ShoppingItem.create!(name: "Lait")
    duplicate = ShoppingItem.new(name: "  lait ")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages, "L'article est deja dans la liste"
  end

  test "add_names ajoute un lot et ecarte les doublons sans echouer" do
    ShoppingItem.create!(name: "Lait")

    added, skipped = ShoppingItem.add_names(["oeufs", "LAIT", "Oeufs", " ", "pain de mie"])

    assert_equal ["Oeufs", "Pain de mie"], added.map(&:name)
    assert_equal ["LAIT"], skipped
    assert_equal 3, ShoppingItem.count
  end

  test "ordered met les articles coches a la fin, clear! vide tout" do
    first = create(:shopping_item, name: "Beurre", checked_at: Time.current)
    second = create(:shopping_item, name: "Sel")

    assert_equal [second, first], ShoppingItem.ordered.to_a
    assert_equal 2, ShoppingItem.clear!
    assert_equal 0, ShoppingItem.count
  end
end
