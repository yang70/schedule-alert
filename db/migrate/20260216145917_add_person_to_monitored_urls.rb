class AddPersonToMonitoredUrls < ActiveRecord::Migration[8.1]
  def change
    add_reference :monitored_urls, :person, null: true, foreign_key: true
  end
end
