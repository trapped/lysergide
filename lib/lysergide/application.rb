require 'sinatra/base'

class Lysergide::Application < Sinatra::Base
	set :server, :thin

	get '/' do
		'/'
	end
end