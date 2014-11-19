require 'sinatra/base'
require 'sass'
require 'haml'
require 'coffee'

class Lysergide::Application < Sinatra::Base
	set :server, :webrick
	set :root, File.dirname(__FILE__) + '/../../'
	set :public_folder, 'static'
	enable :static
end