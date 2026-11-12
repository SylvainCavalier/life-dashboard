# Journal de bord alimente automatiquement : rendez-vous passes (Event), reunions
# (Meeting) et sessions de code (API appelee par /historyupdate). Voir CLAUDE.md,
# « Journal et contacts des projets ».
class AddJournalAutomation < ActiveRecord::Migration[8.0]
  class MigrationProject < ActiveRecord::Base
    self.table_name = "projects"
  end

  def up
    # Identifiant stable d'un projet, cite dans le CLAUDE.md du depot correspondant.
    add_column :projects, :slug, :string
    add_index :projects, :slug, unique: true

    # Origine d'une entree : manual (saisie, Alfred), agenda, meeting, code.
    add_column :project_entries, :source, :string, null: false, default: "manual"
    # Ce qui a produit l'entree (Event#12, Meeting#4, code:<titre de session>) : unique par projet.
    add_column :project_entries, :source_ref, :string
    add_index :project_entries, [:project_id, :source_ref], unique: true, where: "source_ref IS NOT NULL"

    add_reference :events, :project, foreign_key: { on_delete: :nullify }
    # Rendez-vous deja consigne au journal : supprimer l'entree ne la fait pas revenir.
    add_column :events, :journaled_at, :datetime

    add_reference :meetings, :project, foreign_key: { on_delete: :nullify }
    add_column :meetings, :journaled_at, :datetime

    backfill_slugs
  end

  def down
    remove_column :meetings, :journaled_at
    remove_reference :meetings, :project, foreign_key: true
    remove_column :events, :journaled_at
    remove_reference :events, :project, foreign_key: true
    remove_index :project_entries, [:project_id, :source_ref]
    remove_column :project_entries, :source_ref
    remove_column :project_entries, :source
    remove_index :projects, :slug
    remove_column :projects, :slug
  end

  private

  # Un depot connu garde son nom de dossier (« conspi » pour Conspi.fr), le reste prend
  # son nom en minuscules sans accents. Meme regle que Project#default_slug, recopiee
  # ici pour que la migration ne depende pas du code de l'application.
  def backfill_slugs
    folders = begin
      Projects::DocsBundle::REPOSITORIES.to_h { |folder, config| [config[:name].downcase, folder.downcase] }
    rescue NameError
      {}
    end
    taken = []
    MigrationProject.reset_column_information
    MigrationProject.order(:id).each do |project|
      base = folders[project.name.to_s.downcase] || project.name.to_s.parameterize.presence || "projet-#{project.id}"
      slug = taken.include?(base) ? "#{base}-#{project.id}" : base
      taken << slug
      project.update_columns(slug: slug)
    end
  end
end
