# == Schema Information
#
# Table name: warranties
#
#  id              :bigint           not null, primary key
#  brand           :string
#  category        :string           default("autre"), not null
#  duration_months :integer
#  ends_on         :date             not null
#  model_reference :string
#  name            :string           not null
#  notes           :text
#  order_number    :string
#  price           :decimal(10, 2)
#  purchased_on    :date             not null
#  serial_number   :string
#  store           :string
#  support_contact :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_warranties_on_ends_on  (ends_on)
#
require "test_helper"

class WarrantyTest < ActiveSupport::TestCase
  test "la fin de garantie se calcule depuis la date d'achat et la duree" do
    assert_equal Date.new(2027, 3, 15), create(:warranty).ends_on
    # Meme quantieme, ramene a la fin du mois s'il n'existe pas.
    assert_equal Date.new(2026, 2, 28), create(:warranty, purchased_on: Date.new(2025, 8, 31), duration_months: 6).ends_on
  end

  test "une fin saisie a la main l'emporte sur la duree" do
    warranty = create(:warranty, ends_on: Date.new(2030, 3, 15))
    assert_equal Date.new(2030, 3, 15), warranty.ends_on

    warranty.update!(ends_on: Date.new(2029, 1, 1))
    assert_equal Date.new(2029, 1, 1), warranty.ends_on
  end

  test "changer la date d'achat ou la duree recalcule la fin" do
    warranty = create(:warranty)

    warranty.update!(duration_months: 36)
    assert_equal Date.new(2028, 3, 15), warranty.ends_on

    warranty.update!(purchased_on: Date.new(2025, 4, 1))
    assert_equal Date.new(2028, 4, 1), warranty.ends_on
  end

  test "sans duree ni fin, la garantie est invalide" do
    warranty = build(:warranty, duration_months: nil)

    assert_not warranty.valid?
    assert_includes warranty.errors[:ends_on], "requise (ou une duree de garantie)"
  end

  test "categorie, prix et dates sont valides" do
    assert_not build(:warranty, category: "fusee").valid?
    assert_not build(:warranty, price: -1).valid?
    assert_not build(:warranty, duration_months: nil, ends_on: Date.new(2024, 1, 1)).valid?
  end

  test "statut et jours restants" do
    warranty = build(:warranty, ends_on: Date.new(2026, 12, 1), duration_months: nil)

    assert_equal "active", warranty.status(Date.new(2026, 9, 1))
    assert_equal "expiring", warranty.status(Date.new(2026, 11, 1))
    assert_equal 30, warranty.days_left(Date.new(2026, 11, 1))
    assert_equal "expiring", warranty.status(Date.new(2026, 12, 1))
    assert_equal "expired", warranty.status(Date.new(2026, 12, 2))
  end

  test "la facture doit etre un PDF ou une image" do
    warranty = build(:warranty)
    warranty.receipt.attach(io: StringIO.new("pas une facture"), filename: "notes.txt", content_type: "text/plain")

    assert_not warranty.valid?
    assert warranty.errors.key?(:receipt)
  end
end
