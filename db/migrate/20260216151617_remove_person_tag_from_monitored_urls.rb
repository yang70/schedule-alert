class RemovePersonTagFromMonitoredUrls < ActiveRecord::Migration[8.1]
  def change
    remove_column :monitored_urls, :person_tag, :string
  end
end
