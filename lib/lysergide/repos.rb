require 'sinatra/base'
require 'lysergide/database'
require 'lysergide/errors'
require 'digest'
require 'haml'
require 'uri'

include Lysergide::Database

class Lysergide::Repos < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static
	use Rack::Session::Cookie, :key => 'lysergide.session', :path => '/', :secret => 'lysergide'

	use Lysergide::Errors
	helpers Lysergide::ErrorHelpers

	def is_valid_name?(name)
		(name =~ /\A\p{Alnum}+\z/) != nil
	end

	def is_valid_path?(path)
		(URI.regexp =~ path) != nil
	end

	def alert_obj(err)
		return nil unless err
		obj = Object.new
		obj.class.module_eval {
			attr_accessor :type
			attr_accessor :msg
		}
		obj.type = 
			case err
			when 'name', 'path', 'unknown'
				'danger'
			else
				'warning'
			end
		obj.msg =
			case err
			when 'name'
				'Invalid repo name; only alphanumeric names are allowed.'
			when 'path'
				'Invalid repo path; check it is a valid URI and git recognizes it.'
			when 'unknown'
				'Unknown error.'
			else
				"Unknown error: #{err}"
			end
		return obj
	end

	get '/repo/:name' do |name|
		unless session[:user]
			redirect '/login'
		end
		user = User.find(session[:user])
		repo = user.repos.find_by_name(name)
		if repo
			haml :repo, layout: :base, :locals => {
				title: "Lysergide CI - #{name}",
				user: user,
				repo: repo,
				alert: alert_obj(params[:err])
			}
		else
			not_found
		end
	end

	get '/add/repo' do
		unless session[:user]
			redirect '/login'
		end
		haml :addrepo, layout: :base, :locals => {
			title: 'Lysergide CI - Add repo',
			user: User.find(session[:user]),
			alert: alert_obj(params[:err])
		}
	end

	post '/add/repo' do
		unless session[:user]
			redirect '/login'
		end
		case
		when !is_valid_name?(params[:name])
			status 500
			redirect '/add/repo?err=name'
		when !is_valid_path?(params[:import_path])
			status 500
			redirect '/add/repo?err=path'
		end
		if Repo.create(
			name: params[:name],
			import_path: params[:import_path],
			user_id: session[:user],
			token: Digest::SHA256.hexdigest("#{params[:name]}:#{params[:import_path]}:#{session[:user]}"))
		then
			status 200
			redirect '/'
		else
			status 500
			redirect '/add/repo?err=unknown'
		end
	end
end