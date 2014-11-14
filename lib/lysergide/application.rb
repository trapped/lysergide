require 'sinatra/base'

class Lysergide::Application < Sinatra::Base
	get '/' do
		'/'
	end

	def self.start(port)
		set :server, :thin
		set :port, port
		run!
	end
end