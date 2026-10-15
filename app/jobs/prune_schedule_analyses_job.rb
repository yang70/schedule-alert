class PruneScheduleAnalysesJob < ApplicationJob
  queue_as :default

  def perform
    ScheduleAnalysis.where("created_at < ?", 30.days.ago).in_batches.delete_all
  end
end
