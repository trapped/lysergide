require 'sinatra/base'
require 'lysergide/database'
require 'lysergide/login'
require 'lysergide/repos'
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
	use Lysergide::Repos

	get '/' do
		if session[:user]
			haml :dashboard, layout: :base, :locals => {
				title: 'Lysergide CI - Dashboard',
				user: User.find(session[:user])
			}
		else
			redirect '/login'
			haml :welcome, :locals => {
				title: 'Lysergide CI - Powered by Acid'
			}
		end
	end

	not_found do
		haml :notfound, layout: :base, :locals => {
			title: 'Lysergide CI - Not found'
		}
	end
end