require 'lysergide/database'
require 'lysergide/workers'
require 'thread'

include Lysergide::Database

WORKERS_POOL_SIZE = 2

module Lysergide
	module Jobs
		@workers_pool = Array.new
		@workers_pool_lock = Mutex.new
		@dispatch_lock = Mutex.new
		@accept_jobs = false
		@scheduler_thread = nil

		# Retrieves the very next scheduled job and removes it from the queue
		def self.dispatch(worker_id, block = true)
			@dispatch_lock.synchronize {
				LOG.info('Lysergide::Jobs') { 'Dispatching job' }
				while true
					next_build = Build.find_by_status(:scheduled)
					if next_build
						LOG.debug('Lysergide::Jobs') { "Next build: #{next_build.id}" }
						next_build.status = :working
						next_build.log = "[Lysergide::Jobs] Assigned to worker ##{worker_id}\n"
						next_build.save
						return next_build
					else
						if block
							sleep(1)
						else
							return nil
						end
					end
				end
			}
		end

		# Checks if any worker in the pool is done running its job and eventually removes it
		def self.clear_pool()
			@workers_pool_lock.synchronize {
				LOG.info('Lysergide::Jobs') { 'Clearing worker pool' }
				@workers_pool.delete_if { |worker| worker.done? }
			}
		end

		# Gets a new worker if available
		def self.next_worker()
			@workers_pool_lock.synchronize {
				if @workers_pool.length < WORKERS_POOL_SIZE
					LOG.info('Lysergide::Jobs') { "Available workers: #{WORKERS_POOL_SIZE - @workers_pool.length}" }
					used_ids = @workers_pool.map { |worker| worker.id }
					LOG.debug('Lysergide::Jobs') { "Used worker IDs: #{used_ids.inspect}" }
					available_ids = Array.new(WORKERS_POOL_SIZE).fill { |id|
						used_ids.include?(id) ? nil : id
					}.delete_if { |elem| elem == nil }
					LOG.debug('Lysergide::Jobs') { "Available worker IDs: #{available_ids.inspect}" }
					if available_ids.length > 0
						LOG.info('Lysergide::Jobs') { 'Claiming worker' }
						return Lysergide::Worker.new(available_ids.first, @workers_pool, @workers_pool_lock)
					else
						LOG.info('Lysergide::Jobs') { 'No worker IDs available yet' }
						return nil
					end
				else
					LOG.info('Lysergide::Jobs') { 'No workers available yet' }
					return nil
				end
			}
		end

		# Checks for scheduled periodic builds and adds them to the queue; starts workers
		def self.schedule()
			clear_pool()
			LOG.info('Lysergide::Jobs') { 'Scheduling next job' }
			while worker = next_worker
				LOG.info('Lysergide::Jobs') { "Got new worker: #{worker.id}" }
				job = dispatch worker.id
				if job
					LOG.info('Lysergide::Jobs') { "Next job ID: #{job.id}" }
					@workers_pool_lock.synchronize {
						@workers_pool << worker
					}
					# This is a super strange hack I had to use: seems like calling the start() method
					# on 'worker' wouldn't work and freeze the thread or something - turns out I could
					# access it through the pool, so that's what is done right here
					@workers_pool.each do |wrk|
						if wrk.id == worker.id
							wrk.thread = Thread.new {
								wrk.start job
							}
							break
						end
					end
				else
					worker = nil
					break
				end
			end
		end

		# Resets all jobs marked as 'working' to 'scheduled' so that they can be picked up by dispatch
		def self.reschedule_blocked()
			builds = Build.where(status: :working)
			if builds && builds.length > 0
				LOG.info('Lysergide::Jobs') { "Resetting #{builds.length} jobs" }
				builds.update_all(status: :scheduled)
			end
		end

		# Removes temporary directories that haven't been cleaned up
		def self.delete_temp()
			Dir.chdir(Dir.tmpdir) do
				Dir.glob('./lysergide*-job*').select { |dir|
					LOG.info('Lysergide::Jobs') { "Removing '#{File.join(Dir.tmpdir, dir)}'" }
					FileUtils.remove_entry dir
				}
			end
		end

		# Starts the job scheduler (pulling events and addings jobs) on a separate thread
		def self.start()
			delete_temp
			reschedule_blocked
			LOG.info('Lysergide::Jobs') { 'Starting Lysergide::Jobs' }
			@accept_jobs = true
			@scheduler_thread = Thread.new {
				while @accept_jobs
					Lysergide::Jobs.schedule()
					sleep(1)
				end
				@scheduler_thread = nil
			}
		end

		# Stops the job scheduler with quite some violence
		def self.stop()
			LOG.info('Lysergide::Jobs') { 'Stopping' }
			ensure
				@accept_jobs = false
				if @scheduler_thread
					@scheduler_thread.kill
					@scheduler_thread = nil
				end
		end
	end
end