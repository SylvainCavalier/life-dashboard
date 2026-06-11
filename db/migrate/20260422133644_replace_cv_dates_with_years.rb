class ReplaceCvDatesWithYears < ActiveRecord::Migration[8.0]
  def change
    remove_index  :cv_experiences, :start_date
    remove_column :cv_experiences, :start_date, :date, null: false
    remove_column :cv_experiences, :end_date,   :date
    add_column    :cv_experiences, :start_year, :integer, null: false
    add_column    :cv_experiences, :end_year,   :integer
    add_index     :cv_experiences, :start_year

    remove_index  :cv_formations, :start_date
    remove_column :cv_formations, :start_date, :date
    remove_column :cv_formations, :end_date,   :date
    add_column    :cv_formations, :start_year, :integer
    add_column    :cv_formations, :end_year,   :integer
    add_index     :cv_formations, :start_year
  end
end
