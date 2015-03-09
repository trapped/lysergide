require 'logger'

module Lysergide
	LOG = Logger.new($stdout)

	def self.start(port)
		require 'lysergide/jobs'
		Lysergide::Jobs.start
		require 'lysergide/application'
		lsd = Lysergide::Application
		lsd.set :port, port
		lsd.set :bind, '0.0.0.0'
		lsd.run!
		Lysergide::Jobs.stop
	end
end
