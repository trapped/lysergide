require 'lysergide/database'
require 'acid'
require 'fileutils'
require 'stringio'
require 'colorize'
require 'timeout'

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
			LOG.info("Lysergide::Worker##{@id}") { "Assigned to job ##{@job.id}, starting" }
			@job.date = Time.now
			# Create temporary directory for the job
			@dir = Dir.mktmpdir(["lysergide", "-job##{@job.id}"])
			LOG.info("Lysergide::Worker##{@id}") { "Created temporary directory '#{@dir}'" }
			status = pull_ref
			if status > 0
				fail "couldn't pull requested repository (#{status.to_s})" + case status
				when 999 then "- 'git pull' timed out (2 minutes). are you sure the repository isn't private?"
				else          ''
				end
			end
			begin
				status = run_acid
			rescue Psych::SyntaxError
				fail "couldn't parse neither 'acid.yml' nor 'lysergide.yml', check your syntax (no tabs allowed!)"
			rescue ArgumentError
				if $!.message == 'wrong first argument'
					fail "malformed env in either 'acid.yml' or 'lysergide.yml', check your syntax"
				end
				fail $!.message.to_s
			rescue NoMethodError
				if $!.message.start_with?("undefined method `merge'")
					fail "malformed env in either 'acid.yml' or 'lysergide.yml', check your syntax"
				end
				fail $!.message.to_s
			rescue
				fail $!.message.to_s
			end
			case status
				when 999 then fail "couldn't find either 'acid.yml' or 'lysergide.yml' (#{status.to_s})"
				when 0   then LOG.info("Lysergide::Worker##{@id}") { "Job ##{@job.id} completed successfully" }
				else          fail "last command returned #{status.inspect}"
			end
			@job.status = :success
			remove
		end

		# Calls the necessary git commands to pull the required ref for the build
		def pull_ref()
			if @dir
				LOG.info("Lysergide::Worker##{@id}") { "Pulling ref##{@job.ref} for job ##{@job.id}" }
				env = {
					"GIT_CONFIG_NOSYSTEM" => 'true',
					"GIT_SSL_NO_VERIFY" => 'true',
					"PAGER" => 'cat'
				}
				commands = [
					"git clone #{@job.repo.import_path} .",
					"git reset --hard #{@job.ref}"
				]
				worker = Acid::Worker.new(@id, env, 'bash -c')
				begin
					Timeout.timeout(2 * 60) do
						return Thread.new {
							commands.each do |cmd|
								status = worker.run cmd, @bufio, @dir, "lys.#{@id} $ ".bold
								if status > 0
									return status
								end
							end
							return 0
						}.value
					end
				rescue Timeout::Error
					worker.kill
					return 999
				end
			end
		end
		private :pull_ref

		# Runs Acid inside the build directory, effectively running the build
		def run_acid()
			if @dir
				LOG.info("Lysergide::Worker##{@id}") { "Running Acid in '#{@dir}'" }
				return Acid.start(@id, @dir, @bufio, cfg: ['acid.yml', 'lysergide.yml'], prompt: "lys.#{@id} $ ".bold)
			end
		end

		# Removes the worker itself from the parent worker pool
		def remove(msg = nil)
			LOG.info("Lysergide::Worker##{@id}") { "Removing worker" }
			ensure
				@job.duration = (Time.now - Time.parse(@job.date)).to_int
				if @job.status == :working
					@job.status = :failed
					LOG.info("Lysergide::Worker##{@id}") { "Job##{@job.id} failed (interrupted)" }
				else
					LOG.info("Lysergide::Worker##{@id}") { "Job finished as '#{@job.status.to_s}'" }
				end
				@job.log << @buffer
				if msg
					@job.log << "\nError: #{msg}\n".red
				end
				@job.save
				LOG.info("Lysergide::Worker##{@id}")  { "Saved #{@buffer.length} characters to job log" }
				if @dir
					FileUtils.remove_entry @dir
					LOG.info("Lysergide::Worker##{@id}") { 'Removed temporary directory' }
				end
				@done = true
				@pool_lock.synchronize {
					@pool.delete self
				}
			@thread.kill
			return nil
		end
		alias_method :fail, :remove

		# Is the worker done/can it be killed?
		def done?
			@done || false
		end
	end
end
