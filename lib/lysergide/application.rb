require 'sinatra/base'
require 'erb'
require 'coffee'

class Lysergide::Application < Sinatra::Base
	set :server, :thin

	get '/' do
		erb :index
	end
end