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

ActiveRecord::Schema[8.1].define(version: 2026_02_14_180947) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "monitored_urls", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "last_checked_at"
    t.string "name"
    t.datetime "next_check_at"
    t.string "notification_email"
    t.boolean "schedule_available"
    t.date "tournament_start_date"
    t.datetime "updated_at", null: false
    t.string "url"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_monitored_urls_on_user_id"
  end

  create_table "schedule_snapshots", force: :cascade do |t|
    t.text "ai_summary"
    t.boolean "changes_detected"
    t.datetime "checked_at"
    t.text "content"
    t.string "content_hash"
    t.datetime "created_at", null: false
    t.bigint "monitored_url_id", null: false
    t.datetime "updated_at", null: false
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
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "monitored_urls", "users"
  add_foreign_key "schedule_snapshots", "monitored_urls"
end
