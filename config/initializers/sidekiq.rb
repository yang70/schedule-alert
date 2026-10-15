Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
  # Browser work has its own bounded capacity; mail and dispatch remain responsive.
  config.capsule("checks") do |capsule|
    capsule.concurrency = Integer(ENV.fetch("BROWSER_CONCURRENCY", "1"))
    capsule.queues = [ "checks" ]
  end
  config.on(:startup) do
    schedule = YAML.load_file(Rails.root.join("config/sidekiq.yml"))
    Sidekiq::Cron::Job.load_from_hash!(schedule.fetch(:schedule))
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
