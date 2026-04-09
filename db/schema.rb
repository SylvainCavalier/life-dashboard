# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_09_212326) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "budget_entries", force: :cascade do |t|
    t.string "name", null: false
    t.string "entry_type", null: false
    t.string "recurrence", default: "fixed", null: false
    t.string "category"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "month"
    t.integer "year"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_type", "recurrence"], name: "index_budget_entries_on_entry_type_and_recurrence"
    t.index ["year", "month"], name: "index_budget_entries_on_year_and_month"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name", null: false
    t.string "legal_form"
    t.string "siren"
    t.string "siret"
    t.string "vat_number"
    t.string "activity"
    t.string "status", default: "active"
    t.date "creation_date"
    t.decimal "capital", precision: 12, scale: 2
    t.decimal "revenue", precision: 12, scale: 2
    t.integer "employees_count"
    t.string "address_line1"
    t.string "address_line2"
    t.string "postal_code"
    t.string "city"
    t.string "country", default: "France"
    t.string "website"
    t.string "email"
    t.string "phone"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "rcs"
  end

  create_table "contacts", force: :cascade do |t|
    t.string "last_name", null: false
    t.string "first_name", null: false
    t.date "birth_date"
    t.string "gender"
    t.string "occupation"
    t.string "city"
    t.string "phone"
    t.string "email"
    t.date "last_contacted_on"
    t.string "relationship_type", default: "connaissance", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "followed", default: false, null: false
    t.text "notes"
    t.text "likes"
    t.text "dislikes"
    t.text "loans"
    t.string "address"
    t.string "met_through"
    t.integer "met_year"
    t.string "social_instagram"
    t.string "social_linkedin"
    t.string "social_twitter"
    t.string "social_facebook"
    t.string "social_tiktok"
    t.string "social_snapchat"
    t.string "social_youtube"
    t.index ["last_name", "first_name"], name: "index_contacts_on_last_name_and_first_name"
    t.index ["relationship_type"], name: "index_contacts_on_relationship_type"
  end

  create_table "documents", force: :cascade do |t|
    t.string "domain", null: false
    t.string "name", null: false
    t.string "category"
    t.date "document_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["domain", "category"], name: "index_documents_on_domain_and_category"
    t.index ["domain"], name: "index_documents_on_domain"
  end

  create_table "events", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.string "event_type", default: "autre", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.string "location"
    t.string "color", default: "#6366f1"
    t.boolean "all_day", default: false
    t.integer "reminder_minutes", default: 60
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_events_on_event_type"
    t.index ["start_time"], name: "index_events_on_start_time"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at", where: "((retried_good_job_id IS NULL) AND (finished_at IS NOT NULL))"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "health_profiles", force: :cascade do |t|
    t.string "blood_type"
    t.text "allergies"
    t.text "current_medications"
    t.text "medical_history"
    t.string "attending_physician"
    t.string "attending_physician_phone"
    t.text "specialists"
    t.string "social_security_number"
    t.string "health_insurance_name"
    t.string "health_insurance_number"
    t.string "health_insurance_website"
    t.string "ameli_url", default: "https://www.ameli.fr"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "1.0", null: false
    t.string "unit", default: "unite"
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "total_ht", precision: 10, scale: 2, null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discount_type", default: "none"
    t.decimal "discount_value", precision: 10, scale: 2, default: "0.0"
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "quote_id"
    t.string "number", null: false
    t.string "client_name", null: false
    t.string "client_email"
    t.string "client_phone"
    t.string "client_siret"
    t.string "client_vat_number"
    t.string "client_address_line1"
    t.string "client_address_line2"
    t.string "client_postal_code"
    t.string "client_city"
    t.string "client_country", default: "France"
    t.string "subject"
    t.decimal "total_ht", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_tva", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_ttc", precision: 10, scale: 2, default: "0.0"
    t.decimal "tva_rate", precision: 5, scale: 2, default: "20.0"
    t.string "status", default: "pending", null: false
    t.date "issue_date", null: false
    t.date "due_date"
    t.text "notes"
    t.text "conditions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_method"
    t.date "paid_at"
    t.index ["company_id", "status"], name: "index_invoices_on_company_id_and_status"
    t.index ["company_id"], name: "index_invoices_on_company_id"
    t.index ["number"], name: "index_invoices_on_number", unique: true
    t.index ["quote_id"], name: "index_invoices_on_quote_id"
  end

  create_table "language_sessions", force: :cascade do |t|
    t.bigint "language_id", null: false
    t.date "practiced_on", null: false
    t.string "source", default: "manual"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["language_id"], name: "index_language_sessions_on_language_id"
  end

  create_table "languages", force: :cascade do |t|
    t.string "name", null: false
    t.string "level", default: "A1", null: false
    t.string "color", default: "#6366f1"
    t.string "flag_emoji"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_languages_on_name", unique: true
  end

  create_table "mail_accounts", force: :cascade do |t|
    t.string "email", null: false
    t.string "provider", null: false
    t.string "provider_url", null: false
    t.string "password"
    t.string "imap_server"
    t.integer "imap_port"
    t.string "smtp_server"
    t.integer "smtp_port"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_mail_accounts_on_email", unique: true
  end

  create_table "notes", force: :cascade do |t|
    t.string "title", null: false
    t.text "content"
    t.date "note_date", default: -> { "CURRENT_DATE" }, null: false
    t.boolean "important", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["important"], name: "index_notes_on_important"
    t.index ["note_date"], name: "index_notes_on_note_date"
  end

  create_table "password_entries", force: :cascade do |t|
    t.string "name", null: false
    t.string "login", null: false
    t.string "password", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "personal_profiles", force: :cascade do |t|
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "maiden_name"
    t.date "birth_date"
    t.string "birth_city"
    t.string "birth_country"
    t.string "nationality"
    t.string "gender"
    t.string "email"
    t.string "phone"
    t.string "mobile_phone"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "postal_code"
    t.string "state"
    t.string "country"
    t.string "social_security_number"
    t.string "passport_number"
    t.date "passport_expiry"
    t.string "national_id_number"
    t.date "national_id_expiry"
    t.string "driver_license_number"
    t.date "driver_license_expiry"
    t.string "tax_id"
    t.string "occupation"
    t.string "employer"
    t.string "employer_address"
    t.string "professional_email"
    t.string "professional_phone"
    t.string "siret_number"
    t.string "marital_status"
    t.string "spouse_name"
    t.integer "number_of_children"
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.string "emergency_contact_relationship"
    t.string "bank_name"
    t.string "iban"
    t.string "bic"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "status", default: "en_cours"
    t.integer "priority", default: 0
    t.integer "progress", default: 0
    t.string "github_url"
    t.string "site_url"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "properties", force: :cascade do |t|
    t.string "name", null: false
    t.string "property_type", null: false
    t.string "address_line1"
    t.string "address_line2"
    t.string "postal_code"
    t.string "city"
    t.string "country", default: "France"
    t.decimal "surface", precision: 10, scale: 2
    t.integer "rooms"
    t.integer "bedrooms"
    t.integer "bathrooms"
    t.integer "floors"
    t.integer "construction_year"
    t.date "purchase_date"
    t.decimal "purchase_price", precision: 12, scale: 2
    t.decimal "current_value", precision: 12, scale: 2
    t.decimal "loan_remaining", precision: 12, scale: 2
    t.decimal "monthly_payment", precision: 10, scale: 2
    t.integer "months_remaining"
    t.decimal "monthly_charges", precision: 10, scale: 2
    t.decimal "property_tax", precision: 10, scale: 2
    t.decimal "rental_income", precision: 10, scale: 2
    t.boolean "rented", default: false
    t.string "tenant_name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "quote_items", force: :cascade do |t|
    t.bigint "quote_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "1.0", null: false
    t.string "unit", default: "unite"
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "total_ht", precision: 10, scale: 2, null: false
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "discount_type", default: "none"
    t.decimal "discount_value", precision: 10, scale: 2, default: "0.0"
    t.index ["quote_id"], name: "index_quote_items_on_quote_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "number", null: false
    t.string "client_name", null: false
    t.string "client_email"
    t.string "client_phone"
    t.string "client_siret"
    t.string "client_vat_number"
    t.string "client_address_line1"
    t.string "client_address_line2"
    t.string "client_postal_code"
    t.string "client_city"
    t.string "client_country", default: "France"
    t.string "subject"
    t.decimal "total_ht", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_tva", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_ttc", precision: 10, scale: 2, default: "0.0"
    t.decimal "tva_rate", precision: 5, scale: 2, default: "20.0"
    t.string "status", default: "pending", null: false
    t.date "issue_date", null: false
    t.date "validity_date"
    t.text "notes"
    t.text "conditions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "status"], name: "index_quotes_on_company_id_and_status"
    t.index ["company_id"], name: "index_quotes_on_company_id"
    t.index ["number"], name: "index_quotes_on_number", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "cost", precision: 8, scale: 2, null: false
    t.string "billing_cycle", default: "monthly", null: false
    t.string "category"
    t.date "start_date"
    t.date "end_date"
    t.string "url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "tasks", force: :cascade do |t|
    t.string "description", null: false
    t.integer "priority", default: 3, null: false
    t.date "deadline"
    t.boolean "completed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_tasks_on_completed"
    t.index ["priority"], name: "index_tasks_on_priority"
  end

  create_table "useful_sites", force: :cascade do |t|
    t.string "name", null: false
    t.string "url", null: false
    t.string "description"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_useful_sites_on_category"
  end

  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoices", "companies"
  add_foreign_key "invoices", "quotes"
  add_foreign_key "language_sessions", "languages"
  add_foreign_key "quote_items", "quotes"
  add_foreign_key "quotes", "companies"
end
