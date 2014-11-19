require 'sinatra/base'
require 'sass'
require 'haml'
require 'coffee'

class Lysergide::Application < Sinatra::Base
	set :server, :webrick
	set :views, settings.root + '/../../views'
	set :public_folder, settings.root + '/../../static'
	enable :static
end