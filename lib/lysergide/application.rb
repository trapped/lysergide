require 'sinatra/base'
require 'sass'
require 'haml'
require 'coffee'

class Lysergide::Application < Sinatra::Base
	set :server, :webrick
	set :views, settings.root + '/../../views'

	# Static images
	get '/img/*' do |path|
		if File.exists? settings.root + "/../../images/#{path}"
			send_file settings.root + "/../../images/#{path}" 
		else
			status 404
		end
	end
end