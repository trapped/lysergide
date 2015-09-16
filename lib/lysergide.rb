require 'logger'

LOG ||= Logger.new($stdout)

# CI service with hooks for GitHub, BitBucket and git repositories
module Lysergide
  def self.start(port)
    GC.enable
    require 'lysergide/jobs'
    Lysergide::Jobs.start
    require 'lysergide/application'
    lys = Lysergide::Application
    lys.set :port, port
    lys.set :bind, '0.0.0.0'
    lys.run!
    Lysergide::Jobs.stop
  end
end
