require 'lysergyde/database'

include Lysergide::Database

class Lysergide::Worker
	def initialize(id, pool)
		@id = id
		@pool = pool
	end

	def id
		@id
	end

	# Stores the job (build) id and starts a thread to run it
	def start(job)
		@job = job
	end

	# Removes the worker itself from the parent worker pool
	def remove()
		@pool.delete self
	end
	private :remove

	# Is the worker done/can it be killed?
	def done?
		@done || false
	end
end