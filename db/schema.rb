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

ActiveRecord::Schema[8.1].define(version: 2026_10_13_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "monitored_urls", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "last_checked_at"
    t.string "name"
    t.datetime "next_check_at"
    t.string "notification_email"
    t.bigint "person_id"
    t.boolean "schedule_available"
    t.string "sport"
    t.date "tournament_start_date"
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.integer "source_revision", default: 1, null: false
    t.string "check_token"
    t.datetime "check_enqueued_at"
    t.datetime "check_started_at"
    t.string "check_status", default: "idle", null: false
    t.datetime "last_attempt_at"
    t.string "last_error"
    t.integer "failure_count", default: 0, null: false
    t.jsonb "schedule_data"
    t.integer "release_notified_revision", default: 0, null: false
    t.index ["next_check_at", "tournament_start_date"], name: "index_monitored_urls_due", where: "(active = true)"
    t.index ["person_id"], name: "index_monitored_urls_on_person_id"
    t.index ["user_id"], name: "index_monitored_urls_on_user_id"
  end

  create_table "notification_events", force: :cascade do |t|
    t.bigint "monitored_url_id", null: false
    t.string "event_key", null: false
    t.string "kind", null: false
    t.jsonb "payload", null: false
    t.datetime "delivered_at"
    t.datetime "next_delivery_at", null: false
    t.integer "delivery_attempts", default: 0, null: false
    t.string "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["monitored_url_id", "event_key"], name: "index_notification_events_on_monitored_url_id_and_event_key", unique: true
    t.index ["monitored_url_id"], name: "index_notification_events_on_monitored_url_id"
    t.index ["next_delivery_at"], name: "index_notifications_pending", where: "(delivered_at IS NULL)"
  end

  create_table "people", force: :cascade do |t|
    t.string "color", default: "#3B82F6", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index "user_id, lower((name)::text)", name: "index_people_unique_normalized_name", unique: true
    t.index ["user_id", "name"], name: "index_people_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "schedule_analyses", force: :cascade do |t|
    t.string "input_digest", null: false
    t.jsonb "result", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["input_digest"], name: "index_schedule_analyses_on_input_digest", unique: true
  end

  create_table "schedule_snapshots", force: :cascade do |t|
    t.text "ai_summary"
    t.boolean "changes_detected"
    t.datetime "checked_at"
    t.text "content"
    t.string "content_hash"
    t.datetime "created_at", null: false
    t.bigint "monitored_url_id", null: false
    t.jsonb "schedule_data"
    t.datetime "updated_at", null: false
    t.integer "source_revision", default: 1, null: false
    t.jsonb "analysis_metadata", default: {}, null: false
    t.jsonb "evidence", default: [], null: false
    t.index ["monitored_url_id", "checked_at", "id"], name: "index_snapshots_latest"
    t.index ["monitored_url_id"], name: "index_schedule_snapshots_on_monitored_url_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false, null: false
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "monitored_urls_count", default: 0, null: false
    t.integer "people_count", default: 0, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "monitored_urls", "people"
  add_foreign_key "monitored_urls", "users"
  add_foreign_key "notification_events", "monitored_urls"
  add_foreign_key "people", "users"
  add_foreign_key "schedule_snapshots", "monitored_urls"
end
