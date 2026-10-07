# L'accroche unique (cv_settings.pitch) devient une bibliotheque d'accroches
# (cv_pitches) dont une seule est affichee sur le CV. L'accroche existante est
# reprise comme premiere entree et selectionnee.
class AddActivePitchToCvSettings < ActiveRecord::Migration[8.0]
  def up
    add_reference :cv_settings, :active_pitch, foreign_key: { to_table: :cv_pitches, on_delete: :nullify }

    execute <<~SQL
      WITH moved AS (
        INSERT INTO cv_pitches (title, content, position, created_at, updated_at)
        SELECT 'Accroche principale', pitch, 0, NOW(), NOW()
        FROM cv_settings
        WHERE pitch IS NOT NULL AND btrim(pitch) <> ''
        ORDER BY id
        LIMIT 1
        RETURNING id
      )
      UPDATE cv_settings SET active_pitch_id = (SELECT id FROM moved)
      WHERE EXISTS (SELECT 1 FROM moved)
    SQL

    remove_column :cv_settings, :pitch
  end

  def down
    add_column :cv_settings, :pitch, :text

    execute <<~SQL
      UPDATE cv_settings SET pitch = cv_pitches.content
      FROM cv_pitches WHERE cv_pitches.id = cv_settings.active_pitch_id
    SQL

    remove_reference :cv_settings, :active_pitch, foreign_key: { to_table: :cv_pitches }
  end
end
