require 'sinatra/base'
require 'lysergide/database'
require 'lysergide/errors'
require 'haml'
require 'uri'

include Lysergide::Database

class Lysergide::Builds < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static
	use Rack::Session::Cookie, :key => 'lysergide.session', :path => '/', :secret => 'lysergide'

	use Lysergide::Errors
	helpers Lysergide::ErrorHelpers

	before do
		unless session[:user]
			redirect '/login'
		end
	end

	get '/repo/:name/builds' do |name|
		user = User.find(session[:user])
		repo = user.repos.find_by_name(name)
		if repo
			haml :builds, layout: :base, :locals => {
				title: "Lysergide CI - #{name} - Builds",
				user: user,
				repo: repo
			}
		else
			not_found
		end
	end

	get '/repo/:name/builds/:number' do |name, number|
		user = User.find(session[:user])
		repo = user.repos.find_by_name(name) || not_found
		build = repo.builds.find_by_number(number)
		if build
			haml :build_detail, layout: :base, :locals => {
				title: "Lysergide CI - #{name} - Builds",
				user: user,
				repo: repo,
				build: build
			}
		else
			not_found
		end
	end
end