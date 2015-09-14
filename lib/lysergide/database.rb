require 'active_record'
require 'lysergide/realtime'

module Lysergide
  module Database
    # Connect to the database
    ActiveRecord::Base.establish_connection(
      adapter:  'sqlite3',
      database: 'lysergide.db',
      pool:     1024
    )

    # Define the database schema
    ActiveRecord::Schema.define do
      unless ActiveRecord::Base.connection.tables.include? 'users'
        create_table :users do |t|
          t.string :name,     null: false
          t.string :email,    null: false
          t.string :password, null: false
        end
      end

      unless ActiveRecord::Base.connection.tables.include? 'repos'
        create_table :repos do |t|
          t.string  :name,        null: false
          t.string  :import_path, null: false
          t.integer :user_id,     null: false
          t.string  :token,       null: false
          t.string  :last_pull
          t.integer :pull_interval
          t.boolean :public,      null: false
        end
      end

      unless ActiveRecord::Base.connection.tables.include? 'builds'
        create_table :builds do |t|
          t.integer  :repo_id, null: false
          t.integer  :user_id, null: false
          t.integer  :number,  null: false
          t.text     :status
          t.string   :date
          t.integer  :duration
          t.text     :ref
          t.text     :log
        end
      end
    end

    class User < ActiveRecord::Base
      has_many :repos
      has_many :builds
    end

    class Repo < ActiveRecord::Base
      belongs_to :user
      has_many   :builds

      def public
        public?
      end

      def public?
        !!super
      end

      def public=(value)
        super([1, 'true', true, 't'].include? value ? 1 : 0)
        public?
      end

      after_update do |repo|
        Lysergide::RealtimePool.push(
          users: [repo.user.id],
          subs: %w(repos repo_update),
          msg: {
            type: 'repo_update',
            user: repo.user.name,
            repo: repo.name,
            public: repo.public?
          }
        )
      end
    end

    class Build < ActiveRecord::Base
      belongs_to :repo

      default_scope { order(number: :desc) }

      after_create do |build|
        Lysergide::RealtimePool.push(
          users: [build.repo.user.id],
          subs:  %(builds build_create),
          msg: {
            type: 'build_create',
            user: build.repo.user.name,
            repo: build.repo.name,
            build: {
              number: build.number,
              status: build.status,
              date:   build.date
            }
          }
        )
      end

      after_update do |build|
        Lysergide::RealtimePool.push(
          users: [build.repo.user.id],
          subs:  %w(builds build_update),
          msg: {
            type: 'build_update',
            user: build.repo.user.name,
            repo: build.repo.name,
            build: {
              number: build.number,
              status: build.status,
              date:   build.date
            }
          }
        )
      end

      def status
        super.to_sym
      end

      def status=(value)
        super(value.to_s)
        status
      end
    end
  end
end
