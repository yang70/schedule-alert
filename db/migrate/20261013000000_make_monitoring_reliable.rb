class MakeMonitoringReliable < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :admin, :boolean, null: false, default: false
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string
    add_index :users, :confirmation_token, unique: true
    # Keep existing accounts accessible. New signups and email changes require confirmation.
    execute "UPDATE users SET confirmed_at = created_at"
    add_column :users, :monitored_urls_count, :integer, null: false, default: 0
    add_column :users, :people_count, :integer, null: false, default: 0
    execute "UPDATE users SET monitored_urls_count = (SELECT COUNT(*) FROM monitored_urls WHERE user_id = users.id), people_count = (SELECT COUNT(*) FROM people WHERE user_id = users.id)"

    add_column :monitored_urls, :source_revision, :integer, null: false, default: 1
    add_column :monitored_urls, :check_token, :string
    add_column :monitored_urls, :check_enqueued_at, :datetime
    add_column :monitored_urls, :check_started_at, :datetime
    add_column :monitored_urls, :check_status, :string, null: false, default: "idle"
    add_column :monitored_urls, :last_attempt_at, :datetime
    add_column :monitored_urls, :last_error, :string
    add_column :monitored_urls, :failure_count, :integer, null: false, default: 0
    add_column :monitored_urls, :schedule_data, :jsonb
    add_column :monitored_urls, :release_notified_revision, :integer, null: false, default: 0
    execute "UPDATE monitored_urls SET release_notified_revision = 1 WHERE schedule_available = true"
    execute "UPDATE monitored_urls SET next_check_at = CURRENT_TIMESTAMP WHERE active = true AND tournament_start_date >= (CURRENT_TIMESTAMP AT TIME ZONE 'America/Los_Angeles')::date AND next_check_at IS NULL"
    execute "UPDATE monitored_urls SET person_id = NULL WHERE person_id IN (SELECT id FROM people WHERE people.user_id <> monitored_urls.user_id)"
    add_index :monitored_urls, [ :next_check_at, :tournament_start_date ], where: "active = true", name: "index_monitored_urls_due"

    add_column :schedule_snapshots, :source_revision, :integer, null: false, default: 1
    add_column :schedule_snapshots, :analysis_metadata, :jsonb, null: false, default: {}
    add_column :schedule_snapshots, :evidence, :jsonb, null: false, default: []
    add_index :schedule_snapshots, [ :monitored_url_id, :checked_at, :id ], name: "index_snapshots_latest"

    create_table :schedule_analyses do |t|
      t.string :input_digest, null: false
      t.jsonb :result, null: false
      t.timestamps
    end
    add_index :schedule_analyses, :input_digest, unique: true

    create_table :notification_events do |t|
      t.references :monitored_url, null: false, foreign_key: true
      t.string :event_key, null: false
      t.string :kind, null: false
      t.jsonb :payload, null: false
      t.datetime :delivered_at
      t.datetime :next_delivery_at, null: false
      t.integer :delivery_attempts, null: false, default: 0
      t.string :last_error
      t.timestamps
    end
    add_index :notification_events, [ :monitored_url_id, :event_key ], unique: true
    add_index :notification_events, :next_delivery_at, where: "delivered_at IS NULL", name: "index_notifications_pending"

    duplicates = select_value("SELECT COUNT(*) FROM (SELECT user_id, LOWER(name) FROM people GROUP BY user_id, LOWER(name) HAVING COUNT(*) > 1) duplicates").to_i
    raise "Resolve case-insensitive duplicate person names before migrating" if duplicates.positive?
    add_index :people, "user_id, LOWER(name)", unique: true, name: "index_people_unique_normalized_name"
  end

  def down
    remove_index :people, name: "index_people_unique_normalized_name"
    drop_table :notification_events
    drop_table :schedule_analyses
    remove_index :schedule_snapshots, name: "index_snapshots_latest"
    remove_columns :schedule_snapshots, :source_revision, :analysis_metadata, :evidence
    remove_index :monitored_urls, name: "index_monitored_urls_due"
    remove_columns :monitored_urls, :source_revision, :check_token, :check_enqueued_at, :check_started_at, :check_status, :last_attempt_at, :last_error, :failure_count, :schedule_data, :release_notified_revision
    remove_columns :users, :admin, :confirmation_token, :confirmed_at, :confirmation_sent_at, :unconfirmed_email, :monitored_urls_count, :people_count
  end
end
