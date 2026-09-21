class AddProjectToTasksAndDocuments < ActiveRecord::Migration[8.0]
  def change
    # Une tache sans projet appartient a la to-do list generale du dashboard.
    add_reference :tasks, :project, null: true, foreign_key: true
    add_reference :documents, :project, null: true, foreign_key: true
  end
end
