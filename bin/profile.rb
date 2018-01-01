#!/usr/bin/env ruby

profile_url = ARGV.shift

require 'zlib'
require 'base64'

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
rescue Extractor::ProxyError => e
#rescue Extractor::NotAuthorizedError => e
end

# Prepare this for transport (about 80% size reduction):
deflated = Zlib::Deflate.deflate(profile)
encoded = Base64.encode64(deflated)


# On the other end...:
# decoded = Base64.decode64(encoded)
# inflated = Zlib::Inflate.inflate(decoded)


byebug
puts 'yay'

