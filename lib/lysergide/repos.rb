require 'sinatra/base'
require 'lysergide/database'
require 'lysergide/errors'
require 'lysergide/helpers'
require 'digest'
require 'haml'
require 'uri'

include Lysergide::Database
include Lysergide::Helpers

class Lysergide::Repos < Sinatra::Base
  set :root, File.dirname(__FILE__) + '/../../'
  set :public_folder, settings.root + '/static'
  set :views, settings.root + '/views'
  enable :static

  use Lysergide::Errors
  helpers Lysergide::ErrorHelpers

  get '/add/repo' do
    redirect '/login' unless session[:user]
    haml :addrepo, layout: :base, :locals => {
      title: 'Lysergide CI - Add repo',
      user: User.find(session[:user]),
      alert: alert_obj(params[:err])
    }
  end

  post '/add/repo' do
    redirect '/login' unless session[:user]
    case
    when !valid_repo_name?(params[:name])
      status 500
      redirect '/add/repo?err=name'
    when !valid_repo_path?(params[:import_path])
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

  get '/:user/:repo' do |user, repo|
    begin
      unless User.find_by_name(user).repos.find_by_name(repo).public? || session[:user] && session[:user] == User.find_by_name(user).id
        not_found
      end
    rescue
      not_found
    end
    user = User.find_by_name(user) || not_found
    repo = user.repos.find_by_name(repo) || not_found
    haml :repo, layout: :base, :locals => {
      title: "Lysergide CI - #{user.name}/#{repo.name}",
      user: user,
      repo: repo,
      alert: alert_obj(params[:err])
    }
  end

  get '/:user/:repo/status.svg' do |user, repo|
    begin
      unless User.find_by_name(user).repos.find_by_name(repo).public? || session[:user] && session[:user] == User.find_by_name(user).id
        not_found
      end
    rescue
      not_found
    end
    user = User.find_by_name(user) || not_found
    repo = user.repos.find_by_name(repo) || not_found
    halt 200, { 'Content-Type' => 'image/svg+xml' }, haml(:status, :locals => {
      user: user,
      repo: repo
    })
  end
end
