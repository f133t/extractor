
redis_config = {
  url: "redis://#{ENV['REDIS_HOSTNAME']}:6379/0",
  namespace: 'sidekiq-jobs',
  network_timeout: 5
}
Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end
