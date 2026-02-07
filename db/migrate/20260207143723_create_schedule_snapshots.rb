class CreateScheduleSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :schedule_snapshots do |t|
      t.references :monitored_url, null: false, foreign_key: true
      t.text :content
      t.string :content_hash
      t.text :ai_summary
      t.datetime :checked_at
      t.boolean :changes_detected

      t.timestamps
    end
  end
end
