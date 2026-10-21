require "test_helper"

class ProjectEntryTest < ActiveSupport::TestCase
  test "date du jour par defaut, type et titre obligatoires" do
    entry = ProjectEntry.new(project: create(:project), title: "Maquette terminee")
    assert entry.valid?
    assert_equal Date.current, entry.occurred_on
    assert_equal "travail", entry.kind

    assert_not build(:project_entry, kind: "sieste").valid?
    assert_not build(:project_entry, title: "").valid?
  end

  test "chaque type a un libelle" do
    assert_equal ProjectEntry::KINDS.sort, ProjectEntry::KIND_LABELS.keys.sort
  end

  test "supprimer le contact garde l'entree, supprimer le projet la supprime" do
    contact = Contact.create!(first_name: "Paul")
    entry = create(:project_entry, contact: contact)

    contact.destroy
    assert_nil entry.reload.contact_id

    assert_difference -> { ProjectEntry.count }, -1 do
      entry.project.destroy
    end
  end

  test "un contact ne se lie qu'une fois a un projet" do
    link = create(:project_contact)
    duplicate = ProjectContact.new(project: link.project, contact: link.contact)
    assert_not duplicate.valid?
    assert ProjectContact.new(project: create(:project, name: "Autre"), contact: link.contact).valid?
  end

  test "api_attributes du projet : derniere entree du journal et compteurs" do
    project = create(:project)
    create(:project_entry, project: project, occurred_on: Date.new(2026, 10, 1))
    create(:project_entry, project: project, occurred_on: Date.new(2026, 10, 15))
    create(:project_contact, project: project)

    json = project.reload.api_attributes
    assert_equal Date.new(2026, 10, 15), json[:last_entry_on]
    assert_equal 2, json[:entries_count]
    assert_equal 1, json[:contacts_count]
  end
end
