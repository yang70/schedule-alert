class AddTournamentStartDateToMonitoredUrls < ActiveRecord::Migration[8.1]
  def change
    add_column :monitored_urls, :tournament_start_date, :date
    add_column :monitored_urls, :next_check_at, :datetime
  end
end
