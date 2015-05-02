require 'logger'

LOG ||= Logger.new($stdout)

# CI service with hooks for GitHub, BitBucket and git repositories
module Lysergide
  def self.start(port)
    GC.enable
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
