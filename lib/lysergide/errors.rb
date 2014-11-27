require 'sinatra/base'
require 'haml'

class Lysergide::Errors < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static
	use Rack::Session::Cookie, :key => 'lysergide.session', :path => '/', :secret => 'lysergide'

	not_found do
		haml :notfound, layout: :base, :locals => {
			title: 'Lysergide CI - Not found'
		}
	end

	def route_missing
		not_found
	end
end
