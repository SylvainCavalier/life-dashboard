require "test_helper"

class LoanTest < ActiveSupport::TestCase
  test "le nom de la personne est repris du contact et survit a sa suppression" do
    contact = Contact.create!(first_name: "Paul", last_name: "Reboh")
    loan = create(:loan, person_name: nil, contact: contact)
    assert_equal "Paul Reboh", loan.person_name

    contact.destroy
    assert_nil loan.reload.contact_id
    assert_equal "Paul Reboh", loan.person_name
  end

  test "sans contact ni nom, le pret est invalide" do
    loan = build(:loan, person_name: nil)

    assert_not loan.valid?
    assert_includes loan.errors[:person_name], "requise (un contact ou un nom)"
  end

  test "un objet exige l'objet, de l'argent exige un montant" do
    assert_not build(:loan, item: nil).valid?
    assert_not build(:loan, kind: "money", item: nil).valid?
    assert build(:loan, kind: "money", item: nil, amount: 50).valid?
    assert_not build(:loan, direction: "donne").valid?
  end

  test "dates et remboursement coherents" do
    assert_not build(:loan, due_on: Date.new(2026, 8, 1)).valid?
    assert_not build(:loan, returned_on: Date.new(2026, 8, 1)).valid?
    assert_not build(:loan, kind: "money", amount: 50, repaid_amount: 60).valid?
  end

  test "un pret d'argent rembourse en entier se clot seul" do
    loan = create(:loan, kind: "money", amount: 200, repaid_amount: 50, item: "Loyer")
    assert_not loan.returned?
    assert_equal 150, loan.remaining_amount
    assert_equal "200,00 € (Loyer)", loan.label

    loan.update!(repaid_amount: 200)
    assert_equal Date.current, loan.returned_on
    assert_equal 0, loan.remaining_amount
  end

  test "statut selon le retour prevu" do
    loan = build(:loan, due_on: Date.new(2026, 11, 1))

    assert_equal "ongoing", loan.status(Date.new(2026, 10, 1))
    assert_equal "due_soon", loan.status(Date.new(2026, 10, 27))
    assert_equal 5, loan.days_until_due(Date.new(2026, 10, 27))
    assert_equal "overdue", loan.status(Date.new(2026, 11, 2))
    assert_equal "ongoing", build(:loan).status
    loan.returned_on = Date.new(2026, 11, 5)
    assert_equal "returned", loan.status(Date.new(2026, 11, 6))
    assert_nil loan.days_until_due
  end
end
