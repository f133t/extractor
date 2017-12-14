#!/usr/bin/env ruby

profile_url = ARGV.shift

session = Extractor::Session.new(
  email: ENV.fetch('EMAIL'),
  password: ENV.fetch('PASSWORD'),
  user_agent: ENV.fetch('USER_AGENT'),
  profile_url_template: ENV.fetch('PROFILE_URL_TEMPLATE')
)

begin
  profile = session.fetch_profile!(profile_url: profile_url)
#rescue Extractor::ProxyError => e
#rescue Extractor::NotAuthorizedError => e
end

byebug
puts 'yay'

