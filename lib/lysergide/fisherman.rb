require 'faraday'
require 'faraday_middleware'

module Fisherman
	@faraday = Faraday.new(:url => 'https://api.github.com') do |faraday|
		faraday.request  :json
		faraday.response :json
		faraday.adapter  Faraday.default_adapter
	end
end