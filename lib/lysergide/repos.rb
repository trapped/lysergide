require 'sinatra/base'
require 'lysergide/database'
require 'haml'

include Lysergide::Database

class Lysergide::Repos < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static
	use Rack::Session::Cookie, :key => 'lysergide.session', :path => '/', :secret => 'lysergide'

	get '/add/repo' do
		if session[:user]
			haml :addrepo, layout: :base, :locals => {
				title: 'Lysergide CI - Add repo',
				user: User.find(session[:user])
			}
		else
			redirect '/login'
		end
	end

	post '/add/repo' do
		if session[:user]
			if Repo.create(
				name: params[:name],
				import_path: params[:import_path],
				user_id: session[:user])\
			then
				status 200
			else
				status 500
			end
		else
			redirect '/login'
		end
	end
end