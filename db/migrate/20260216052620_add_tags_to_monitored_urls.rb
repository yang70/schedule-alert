class AddTagsToMonitoredUrls < ActiveRecord::Migration[8.1]
  def change
    add_column :monitored_urls, :person_tag, :string
    add_column :monitored_urls, :sport, :string
  end
end
