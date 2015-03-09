require 'lysergide/database'

include Lysergide::Database

module Lysergide
	class Worker
		def initialize(id, pool, lock)
			@id = id
			@pool = pool
			@pool_lock = lock
			LOG.debug("Initialized worker ##{id}")
		end

		def thread
			@thread
		end

		def thread=(t)
			@thread = t
		end

		def id
			@id
		end

		# Stores the job (build) id and starts a thread to run it
		def start(job)
			@job = job
			LOG.info("Worker ##{@id}: job ##{job.id} started")
			job.status = :success
			job.save
		end

		# Removes the worker itself from the parent worker pool
		def remove()
			@pool_lock.synchronize {
				@pool.delete self
			}
			@thread.kill
		end
		private :remove

		# Is the worker done/can it be killed?
		def done?
			@done || false
		end
	end
end
