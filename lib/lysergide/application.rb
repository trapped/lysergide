require 'sinatra/base'
require 'active_record'
require 'lysergide/database'
require 'lysergide/errors'
require 'lysergide/login'
require 'lysergide/builds'
require 'lysergide/hooks'
require 'lysergide/realtime'
require 'lysergide/helpers'
require 'lysergide/repos'
require 'tilt/haml'
require 'haml'

include Lysergide::Database

module Lysergide
  class Application < Sinatra::Base
    set :server, :thin
    set :root, File.dirname(__FILE__) + '/../../'
    set :public_folder, settings.root + 'static'
    set :views, settings.root + 'views'
    enable :static, :dump_errors

    use Lysergide::Errors
    helpers Lysergide::ErrorHelpers
    use Lysergide::Login
    use Lysergide::Builds
    use Lysergide::Hooks
    use Lysergide::Realtime
    use Lysergide::Repos

    # before do
    #   LOG.info('Lysergide') {
    #     "#{request.scheme.upcase} #{request.request_method} from #{request.ip}: " \
    #     "#{request.path} user_agent:\"#{request.user_agent}\" content_length:\"#{request.content_length}\""
    #   }
    # end

    after do
      ActiveRecord::Base.clear_active_connections!
    end

    get '/' do
      if session[:user]
        haml :dashboard, layout: :base, locals: {
          title: 'Lysergide CI - Dashboard',
          helpers: Lysergide::Helpers,
          user: User.find(session[:user])
        }
      else
        redirect '/login'
        haml :welcome, locals: {
          title: 'Lysergide CI - Powered by Acid'
        }
      end
    end

    get '/favicon.ico' do
      halt 200, { 'Content-Type' => 'image/svg+xml' }, haml(:favicon)
    end
  end
end
