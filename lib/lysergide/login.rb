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