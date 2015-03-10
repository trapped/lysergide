require 'lysergide/database'
require 'stringio'

include Lysergide::Database

module Lysergide
	class Worker
		def initialize(id, pool, lock)
			@id = id
			@pool = pool
			@pool_lock = lock
			@buffer = '' # used by web clients: create a new StringIO on this to have indipendent pos
			@bufio = StringIO.new @buffer # used by the Acid worker
			LOG.debug("Lysergide::Worker##{@id}") { "Initialized worker ##{id}" }
		end

		def thread
			@thread
		end

		def thread=(t)
			@thread = t
		end

		def buffer
			@buffer
		end

		def id
			@id
		end

		# Stores the job (build) id and starts a thread to run it
		def start(job)
			@job = job
			LOG.info("Lysergide::Worker##{@id}") { "Assigned to job ##{job.id}, starting" }
		end

		# Removes the worker itself from the parent worker pool
		def remove(msg = nil)
			LOG.info("Lysergide::Worker##{@id}") { 'Removing worker' }
			ensure
				if @job.status == :working
					@job.status = :failed
					LOG.info("Lysergide::Worker##{@id}") { "Job##{@job.id} failed (interrupted)" }
				else
					LOG.info("Lysergide::Worker##{@id}") { "Job finished as '#{@job.status.to_s}'" }
				end
				@job.log << @buffer
				if msg
					@job.log << "\nError: #{msg}\n"
				end
				@job.save
				LOG.info("Lysergide::Worker##{@id}")  { "Saved #{@buffer.length} characters to job log" }
				@done = true
				@pool_lock.synchronize {
					@pool.delete self
				}
			@thread.kill
		end
		alias_method :fail, :remove
		private :remove, :fail

		# Is the worker done/can it be killed?
		def done?
			@done || false
		end
	end
end
