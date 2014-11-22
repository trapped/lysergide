require 'sinatra/base'
require 'lysergide/login'
require 'lysergide/database'
require 'haml'

include Lysergide::Database

class Lysergide::Application < Sinatra::Base
	set :server, :webrick
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + 'static'
	set :views, settings.root + 'views'
	enable :static
	use Rack::Session::Cookie, :key => 'rack.session', :path => '/', :secret => 'lysergide'

	use Lysergide::Login

	get '/' do
		user = User.find(session[:user]) || nil
		if user
			haml :dashboard, layout: :base, :locals => {
				:title => 'Lysergide CI - Dashboard',
				:user => user
			}
		else
			redirect '/login'
			haml :welcome, :locals => {
				:title => 'Lysergide CI - Powered by Acid'
			}
		end
	end
end