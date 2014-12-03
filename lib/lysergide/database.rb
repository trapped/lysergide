require 'active_record'

module Lysergide
	module Database
		# Connect to the database
		ActiveRecord::Base.establish_connection ({
			adapter: 'sqlite3',
			database: 'lysergide.db',
			pool: 16
		})

		# Define the database schema
		ActiveRecord::Schema.define do
			unless ActiveRecord::Base.connection.tables.include? 'users'
				create_table :users do |table|
					table.column :name,			:string
					table.column :email,		:string
					table.column :password,		:string
				end
			end

			unless ActiveRecord::Base.connection.tables.include? 'repos'
				create_table :repos do |table|
					table.column :name,			:string
					table.column :import_path,	:string
					table.column :user_id,		:integer
					table.column :last_pull,	:string
					table.column :pull_interval :integer
				end
			end

			unless ActiveRecord::Base.connection.tables.include? 'builds'
				create_table :builds do |table|
					table.column :repo_id,		:integer
					table.column :user_id,		:integer
					table.column :number,		:integer
					table.column :status,		:text
					table.column :date,			:string
					table.column :duration,		:integer
					table.column :ref,			:text
					table.column :log,			:text
				end
			end
		end

		class User < ActiveRecord::Base
			has_many :repos
			has_many :builds
		end

		class Repo < ActiveRecord::Base
			belongs_to :user
			has_many :builds
		end

		class Build < ActiveRecord::Base
			belongs_to :repo

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
