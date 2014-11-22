require 'sinatra/base'
require 'lysergide/database'
require 'haml'
require 'colorize'

class Lysergide::Login < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static
	use Rack::Session::Cookie, :key => 'rack.session', :path => '/', :secret => 'lysergide'

	get '/login' do
		if session[:user]
			redirect '/'
		else
			haml :login, :layout => :base, :locals => {
				:title => 'Lysergide CI - Login'
			}
		end
	end

	post '/login' do
		if !session[:user]
			user = Lysergide::Database.login(params[:email], params[:password])
			puts __FILE__ + user.inspect.to_s.red
			if user
				session[:user] = user
			end
		end
		redirect '/'
	end
end