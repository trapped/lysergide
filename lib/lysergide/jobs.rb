require 'lysergide/database'
require 'lysergide/workers'
require 'thread'

include Lysergide::Database

module Lysergide
	module Jobs
		@workers_pool = []
		@workers_pool_lock = Mutex.new
		@dispatch_lock = Mutex.new
		@accept_jobs = false
		@scheduler_thread = nil

		# Retrieves the very next scheduled job and removes it from the queue
		def self.dispatch(worker_id)
			@dispatch_lock.synchronize {
				scheduled_builds = Builds.where(status: :scheduled).sort_by &:date
				next_build = scheduled_builds.first
				next_build.status = :assigned
				next_build.log << "[Lysergide::Jobs] Assigned to worker ##{worker_id}\n"
				return next_build.id
			}
		end

		# Checks if any worker in the pool is done running its job and eventually removes it
		def self.clean_pool()
			@workers_pool_lock.synchronize {
				@workers_pool.delete_if { |worker| worker.done? }
			}
		end

		# Gets a new worker if available
		def self.next_worker()
			@workers_pool_lock.synchronize {
				if workers_pool.length < (defined? WORKERS_POOL_SIZE ? WORKERS_POOL_SIZE : 16)
					used_ids = @workers_pool.map { |worker| worker.id }
					available_ids = [].fill{ |id| used_ids.include? id ? nil : id }.delete_if{ |elem| elem == nil }
					if available_ids.length > 0
						Lysergide::Worker.new available_ids.first
					end
				end
			}
		end

		# Checks for scheduled periodic builds and adds them to the queue; starts workers
		def self.schedule()
			clean_pool()
			while worker = next_worker
				job = dispatch worker.id
				if job
					worker.start job
					@workers_pool_lock.synchronize {
						workers_pool << worker
					}
				else
					worker = nil
					break
				end
			end
		end

		# Starts the job scheduler (pulling events and addings jobs) on a separate thread
		def self.start()
			@accept_jobs = true
			@scheduler_thread = Thread.new {
				while @accept_jobs
					Lysergide::Jobs.schedule()
					sleep(1000)
				end
				@scheduler_thread = nil
			}
		end

		# Stops the job scheduler with quite some violence
		def self.stop()
			@accept_jobs = false
			if @scheduler_thread
				@scheduler_thread.kill
				@scheduler_thread = nil
			end
		end
	end
end