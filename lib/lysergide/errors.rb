require 'sinatra/base'
require 'haml'

module Lysergide
	module ErrorHelpers
		def route_missing
			if @app
				forward
			else
				not_found
			end
		end
	end
end

class Lysergide::Errors < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static
	use Rack::Session::Cookie, :key => 'lysergide.session', :path => '/', :secret => 'lysergide'

	# Seems like the before/after filters from Lysergide::Application either don't work with POST or they don't reach here
	before do
		LOG.info("Lysergide") {
			"#{request.scheme.upcase} #{request.request_method} from #{request.ip.to_s}: " +
			"#{request.path} user_agent:\"#{request.user_agent}\" content_length:\"#{request.content_length}\""
		}
	end

	not_found do
		haml :notfound, layout: :base, :locals => {
			title: 'Lysergide CI - Not found'
		}
	end
end
