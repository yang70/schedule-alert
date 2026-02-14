class AddScheduleDataToScheduleSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :schedule_snapshots, :schedule_data, :jsonb
  end
end
