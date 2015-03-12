require 'sinatra/base'
require 'lysergide/database'
require 'lysergide/errors'
require 'lysergide/helpers'
require 'haml'
require 'uri'

include Lysergide::Database

class Lysergide::Builds < Sinatra::Base
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, settings.root + '/static'
	set :views, settings.root + '/views'
	enable :static

	use Lysergide::Errors
	helpers Lysergide::ErrorHelpers

	get '/repo/:name/builds' do |name|
		unless session[:user]
			redirect '/login'
		end
		user = User.find(session[:user])
		repo = user.repos.find_by_name(name)
		if repo
			haml :builds, layout: :base, :locals => {
				title: "Lysergide CI - #{name} - Builds",
				helpers: Lysergide::Helpers,
				user: user,
				repo: repo
			}
		else
			not_found
		end
	end

	get '/repo/:name/builds/:number' do |name, number|
		unless session[:user]
			redirect '/login'
		end
		user = User.find(session[:user])
		repo = user.repos.find_by_name(name) || not_found
		build = repo.builds.find_by_number(number)
		if build
			haml :builddetail, layout: :base, :locals => {
				title: "Lysergide CI - #{name} - Builds",
				helpers: Lysergide::Helpers,
				user: user,
				repo: repo,
				build: build
			}
		else
			not_found
		end
	end

	get '/repo/:name/builds/:number/retry' do |name, number|
		unless session[:user]
			redirect '/login'
		end
		user = User.find(session[:user])
		repo = user.repos.find_by_name(name) || redirect("/repo/#{name}/builds/#{number}")
		build = repo.builds.find_by_number(number)
		if build
			build.status = :scheduled
			build.save
			redirect "/repo/#{name}/builds/#{number}"
		else
			redirect "/repo/#{name}/builds/#{number}"
		end
	end
end