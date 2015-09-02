require 'sinatra/base'
require 'lysergide/database'
require 'lysergide/errors'
require 'lysergide/helpers'
require 'haml'
require 'uri'

include Lysergide::Database
include Lysergide::Helpers

class Lysergide::Builds < Sinatra::Base
  set :root, File.dirname(__FILE__) + '/../../'
  set :public_folder, settings.root + '/static'
  set :views, settings.root + '/views'
  enable :static

  use Lysergide::Errors
  helpers Lysergide::ErrorHelpers

  get '/:user/:repo/builds' do |user, repo|
    begin
      unless User.find_by_name(user).repos.find_by_name(repo).public? || session[:user] && session[:user] == User.find_by_name(user).id
        not_found
      end
    rescue
      not_found
    end
    user = User.find_by_name(user) || not_found
    repo = user.repos.find_by_name(repo) || not_found
    haml :builds, layout: :base, :locals => {
      title: "Lysergide CI - #{user.name}/#{repo.name} - Builds",
      helpers: Lysergide::Helpers,
      user: user,
      repo: repo,
      alert: alert_obj(params[:err])
    }
  end

  get '/:user/:repo/builds/:number' do |user, repo, number|
    begin
      unless User.find_by_name(user).repos.find_by_name(repo).public? || session[:user] && session[:user] == User.find_by_name(user).id
        not_found
      end
    rescue
      not_found
    end
    user = User.find_by_name(user) || not_found
    repo = user.repos.find_by_name(repo) || not_found
    build = repo.builds.find_by_number(number) || not_found
    haml :builddetail, layout: :base, :locals => {
      title: "Lysergide CI - #{user.name}/#{repo.name} - Build ##{number} details",
      helpers: Lysergide::Helpers,
      user: user,
      repo: repo,
      build: build,
      alert: alert_obj(params[:err])
    }
  end

  get '/:user/:repo/builds/:number/retry' do |user, repo, number|
    begin
      unless User.find_by_name(user).repos.find_by_name(repo).public? || session[:user] && session[:user] == User.find_by_name(user).id
        not_found
      end
    rescue
      not_found
    end
    user = User.find_by_name(user) || not_found
    repo = user.repos.find_by_name(repo) || not_found
    build = repo.builds.find_by_number(number) || not_found
    if user.id == session[:user]
      build.status = :scheduled
      build.save
      redirect "/#{user.name}/#{repo.name}/builds/#{number}"
    else
      redirect "/#{user.name}/#{repo.name}/builds/#{number}?err=not_owner"
    end
  end
end
