require 'sinatra/base'
require 'lysergide/database'
require 'haml'

include Lysergide::Database

module Lysergide
  module ErrorHelpers
    def route_missing
      if @app
        super
      else
        not_found
      end
    end
  end
end

class Lysergide::Errors < Sinatra::Base
  set :root, File.dirname(__FILE__) + '/../../'
  set :public_folder, settings.root + '/static'
  set :views, settings.root + '/views'
  enable :static
  use Rack::Session::Cookie, key: 'lysergide.session', path: '/', secret: 'lysergide'

  not_found do
    haml :notfound, layout: :base, locals: {
      title: 'Lysergide CI - Not found',
      user: User.find(session[:user])
    }
  end
end
