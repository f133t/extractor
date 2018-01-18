require 'zlib'
require 'base64'

class ProfileFetcherWorker
  include Sidekiq::Worker
  sidekiq_options queue: :profile_fetcher_worker

  def perform(args={})
    sleep 10
    profile_url = args.fetch('profile_url').gsub(/\r$/,'')
    operation_uuid = args.fetch('operation_uuid')

    unless params
      raise "Cannot get params for email #{email}"
    end

    session = fetch_session!

    status = 'success'
    begin
      profile = JSON.parse(session.fetch_profile!(profile_url: profile_url)).merge(status: :success, identity: {email: session.email, socks_proxy: session.socks_proxy}).to_json
    rescue Extractor::InvalidProfileUrlError,  Extractor::UserVisibilityError => e
      warn "ERROR: #{e}"
      profile = {status: :error, message: e.to_s, identity: {email: session.email, socks_proxy: session.socks_proxy}}.to_json
      status = 'error'
    rescue Extractor::NotAuthorizedError, Extractor::ProxyError, Errno::ECONNREFUSED, StandardError => e
      if e.to_s =~ %r{failure in name resolution}
        warn "WARN: Wating 5 seconds b/c of #{e}"
        sleep 5
        perform(args)
      end
      # We must mark this session as no longer valid:
      warn 'Removing %s from the session-hash because of [%s]...' % [email, e]
          remove_session!(session)
          warn 'Finished removing %s from the session-hash' % email
      raise e
    end

    # Prepare this for transport (about 80% size reduction):
    encoded = Base64.encode64(Zlib::Deflate.deflate(profile))

    Sidekiq::Client.new.push(
      'queue' => :profile_post_processor_worker,
      'class' => 'ProfilePostProcessorWorker',
      'args' => [
        operation_uuid: operation_uuid,
        profile_data_base64: encoded,
        profile_url: profile_url,
        status: status
      ]
    )
  end

  private

  def redis
    Rails.application.redis
  end

  def fetch_session!
    # Just fetch a session at random.
    key = redis.keys('session-hash:*').sample rescue nil
    raise 'No entries in session-hash:*' unless key

    params = JSON.parse(redis.get(key)) rescue nil
    raise 'Cannot parse JSON from redis key "%s"' % email
    session = Extractor::Session.new(
      email: params.fetch('email'),
      password: params.fetch('password'),
      user_agent: params.fetch('user_agent'),
      profile_url_template: params.fetch('profile_url_template'),
      cookies: params.fetch('cookies'),
      socks_proxy: params.fetch('socks_proxy'),
    )
  end

  def remove_session!(session)
    redis.del('session-hash:%s' % session.email)
  end
end
