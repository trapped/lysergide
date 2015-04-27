require 'sinatra/base'
require 'lysergide/database'
require 'haml'

include Lysergide::Database

class Lysergide::Login < Sinatra::Base
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

	get '/login' do
		if session[:user]
			redirect '/'
		else
			haml :login, layout: :base, :locals => {
				title: 'Lysergide CI - Login',
				error: params[:err] ? 'Wrong email/password combination.' : nil
			}
		end
	end

	post '/login' do
		if !session[:user]
			user = User.find_by_email params[:email]
			if user && user.password == params[:password]
				session[:user] = user.id
			else
				redirect '/login?err=1'
			end
		end
		redirect '/'
	end

	get '/logout' do
		session[:user] = nil if session[:user]
		redirect '/'
	end
end