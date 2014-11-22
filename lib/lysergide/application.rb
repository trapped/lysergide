require 'sinatra/base'
require 'lysergide/login'
require 'lysergide/database'
require 'haml'
require 'dish/ext'

class Lysergide::Application < Sinatra::Base
	set :server, :webrick
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + 'static'
	set :views, settings.root + 'views'
	enable :static
	use Rack::Session::Cookie, :key => 'rack.session', :path => '/', :secret => 'lysergide'

	use Lysergide::Login

	template :layout do
		haml :base
	end

	def user
		Lysergide::Database.user(session[:user]).to_dish if session[:user]
	end

	get '/' do
		if user
			haml :dashboard, :locals => {
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