class CreateMonitoredUrls < ActiveRecord::Migration[8.1]
  def change
    create_table :monitored_urls do |t|
      t.references :user, null: false, foreign_key: true
      t.string :url
      t.string :name
      t.datetime :last_checked_at
      t.boolean :schedule_available
      t.boolean :active
      t.string :notification_email

      t.timestamps
    end
  end
end
