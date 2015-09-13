require 'lysergide/database'
require 'lysergide/workers'
require 'thread'

include Lysergide::Database

WORKERS_POOL_SIZE = ENV['LYS_WORKER_POOL_SIZE'] || 2

module Lysergide
  module Jobs
    @workers_pool = []
    @workers_pool_lock = Mutex.new
    @dispatch_lock = Mutex.new
    @accept_jobs = false
    @scheduler_thread = nil

    # Retrieves the very next scheduled job and removes it from the queue
    def self.dispatch(worker_id, block = true)
      @dispatch_lock.synchronize do
        LOG.info('Lysergide::Jobs') { 'Dispatching job' }
        loop do
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
      end
    end

    # Checks if any worker in the pool is done running its job and
    # eventually removes it
    def self.clear_pool
      @workers_pool_lock.synchronize do
        LOG.info('Lysergide::Jobs') do
          'Clearing worker pool'
        end
        @workers_pool.delete_if(&:done?)
      end
    end

    # Gets a new worker if available
    def self.next_worker
      @workers_pool_lock.synchronize do
        if @workers_pool.length < WORKERS_POOL_SIZE
          LOG.info('Lysergide::Jobs') do
            "Available workers: #{WORKERS_POOL_SIZE - @workers_pool.length}"
          end
          used_ids = @workers_pool.map(&:id)
          LOG.debug('Lysergide::Jobs') do
            "Used worker IDs: #{used_ids.inspect}"
          end
          available_ids = Array.new(WORKERS_POOL_SIZE).fill do |id|
            used_ids.include?(id) ? nil : id
          end.delete_if(&:nil?)
          LOG.debug('Lysergide::Jobs') do
            "Available worker IDs: #{available_ids.inspect}"
          end
          if available_ids.length > 0
            LOG.info('Lysergide::Jobs') { 'Claiming worker' }
            return Lysergide::Worker.new(available_ids.first, @workers_pool, @workers_pool_lock)
          else
            LOG.info('Lysergide::Jobs') do
              'No worker IDs available yet'
            end
            return nil
          end
        else
          LOG.info('Lysergide::Jobs') do
            'No workers available yet'
          end
          return nil
        end
      end
    end

    # Checks for scheduled periodic builds and adds them to the queue;
    # starts workers
    def self.schedule
      clear_pool
      LOG.info('Lysergide::Jobs') { 'Scheduling next job' }
      while worker = next_worker
        LOG.info('Lysergide::Jobs') { "Got new worker: #{worker.id}" }
        job = dispatch worker.id
        if job
          LOG.info('Lysergide::Jobs') { "Next job ID: #{job.id}" }
          @workers_pool_lock.synchronize do
            @workers_pool << worker
          end
          # This is a super strange hack I had to use: seems like calling the
          # start() methodon 'worker' wouldn't work and freeze the thread or
          # something - turns out I could access it through the pool, so that's
          # what is done right here
          @workers_pool.each do |wrk|
            if wrk.id == worker.id
              wrk.thread = Thread.new {
                begin
                  wrk.start job
                rescue SystemExit
                  unless wrk.done?
                    LOG.error("Lysergide::Worker##{wrk.id}") do
                      "Worker thread died: #{$ERROR_INFO}\n#{$ERROR_POSITION.join "\n"}"
                    end
                    wrk.fail $ERROR_INFO.message.to_s
                  end
                ensure
                  wrk = nil
                end
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

    # Resets all jobs marked as 'working' to 'scheduled' so that they can be
    # picked up by dispatch
    def self.reschedule_blocked
      builds = Build.where(status: :working)
      if builds && builds.length > 0
        LOG.info('Lysergide::Jobs') do
          "Resetting #{builds.length} jobs"
        end
        builds.update_all(status: :scheduled)
      end
    end

    # Removes temporary directories that haven't been cleaned up
    def self.delete_temp
      Dir.chdir(Dir.tmpdir) do
        Dir.glob('./lysergide*-job*').select do |dir|
          LOG.info('Lysergide::Jobs') do
            "Removing '#{File.join(Dir.tmpdir, dir)}'"
          end
          FileUtils.remove_entry dir
        end
      end
    end

    # Starts the job scheduler (pulling events and addings jobs) on a
    # separate thread
    def self.start
      delete_temp
      reschedule_blocked
      Thread.abort_on_exception = true unless Thread.abort_on_exception
      LOG.info('Lysergide::Jobs') { 'Starting Lysergide::Jobs' }
      @accept_jobs = true
      @scheduler_thread = Thread.new do
        begin
          while @accept_jobs
            Lysergide::Jobs.schedule
            sleep(1)
          end
          @scheduler_thread = nil
        rescue
          LOG.error('Lysergide::Jobs') do
            "Scheduler thread died: #{$ERROR_INFO}\n#{$ERROR_POSITION}"
          end
          stop
        end
      end
    end

    # Stops the job scheduler with quite some violence
    def self.stop
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
