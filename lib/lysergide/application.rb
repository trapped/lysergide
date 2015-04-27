require 'sinatra/base'
require 'active_record'
require 'lysergide/database'
require 'lysergide/errors'
require 'lysergide/login'
require 'lysergide/repos'
require 'lysergide/builds'
require 'lysergide/hooks'
require 'lysergide/helpers'
require 'haml'

include Lysergide::Database

class Lysergide::Application < Sinatra::Base
	set :server, :thin
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + 'static'
	set :views, settings.root + 'views'
	enable :static, :dump_errors

	use Lysergide::Errors
	helpers Lysergide::ErrorHelpers
	use Lysergide::Login
	use Lysergide::Repos
	use Lysergide::Builds
	use Lysergide::Hooks

	before do
		LOG.info("Lysergide") {
			"#{request.scheme.upcase} #{request.request_method} from #{request.ip.to_s}: " +
			"#{request.path} user_agent:\"#{request.user_agent}\" content_length:\"#{request.content_length}\""
		}
	end

	after do
		ActiveRecord::Base.clear_active_connections!
	end

	get '/' do
		if session[:user]
			haml :dashboard, layout: :base, :locals => {
				title: 'Lysergide CI - Dashboard',
				helpers: Lysergide::Helpers,
				user: User.find(session[:user])
			}
		else
			redirect '/login'
			haml :welcome, :locals => {
				title: 'Lysergide CI - Powered by Acid'
			}
		end
	end
end
