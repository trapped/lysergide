require 'logger'

module Lysergide
	LOG = Logger.new($stdout)

	def self.start(port)
		require 'lysergide/application'
		$lsd = Lysergide::Application.new
		$lsd.start(port)
	end
end