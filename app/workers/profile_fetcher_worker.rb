require 'zlib'
require 'base64'

class ProfileFetcherWorker
  include Sidekiq::Worker
  sidekiq_options queue: :profile_fetcher_worker

  def perform(args={})
    sleep 5
    profile_url = args.fetch('profile_url')
    operation_uuid = args.fetch('operation_uuid')

    redis = Rails.application.redis

    email = redis.brpoplpush('session-ring', 'session-ring')
    params = JSON.parse(redis.get('session-hash:%s' % email))

    session = Extractor::Session.new(
      email: params.fetch('email'),
      password: params.fetch('password'),
      user_agent: params.fetch('user_agent'),
      profile_url_template: params.fetch('profile_url_template'),
      cookies: params.fetch('cookies'),
      socks_proxy: params.fetch('socks_proxy'),
    )

    begin
      profile = session.fetch_profile!(profile_url: profile_url)
    rescue Extractor::NotAuthorizedError, Extractor::ProxyError, Errno::ECONNREFUSED => e
      # We must mark this session as no longer valid:
      warn 'Removing %s from the session-ring...' % email
      loop do
        session_email = redis.brpop('session-ring')
        if session_email == email
          # OK it's been removed from the session-ring -- also remove it from the hash:
          redis.del('session-hash:%s' % email)
          warn 'Finished removing %s from the session-ring' % email
          break
        else
          redis.lpush('session-ring', session_email)
        end
      end
    end

    # Prepare this for transport (about 80% size reduction):
    encoded = Base64.encode64(Zlib::Deflate.deflate(profile))

    Sidekiq::Client.new.push(
      'queue' => :profile_post_processor_worker,
      'class' => 'ProfilePostProcessorWorker',
      'args' => [
        operation_uuid: operation_uuid,
        profile_data_base64: encoded,
        profile_url: profile_url
      ]
    )
  end
end
