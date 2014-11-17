require 'sqlite3'

module Lysergide
	module Database
		# Get a Database object
		def self.open(&block)
			conn = SQLite3::Database.new 'lysergide.db' do |db|
				# Allow accessing row data by column name instead of index
				db.results_as_hash = true
			end
			if block
				block.call conn
				conn.close
			else
				return conn
			end
		end

		# Populate the database with initial/default data (admin account, etc.)
		def self.populate()
			self.open do |db|
				# Create users table
				db.execute %{
					CREATE TABLE users (
						name		text	unique,
						email		text	unique,
						password	text,
						repos		text,
						builds		text
					);
				}
				# Add admin user
				self.add_user('admin', 'admin@example.com')

				# Create repos table
				db.execute %{
					CREATE TABLE repos (
						name		text,
						import_path	text	unique,
						owner		integer,
						builds		text
					);
				}

				# Create builds table
				db.execute %{
					CREATE TABLE builds (
						repo		integer,
						number		integer,
						status		text,
						duration	integer,
						ref			text,
						log			text
					);
				}
			end
		end

		# Add an user
		def self.add_user(name, email, password)
			self.open do |db|
				db.execute %{
					INSERT INTO users
						(name, email, password)
					VALUES
						(?, ?, ?);
				}, [name, email, password]
				return db.last_insert_row_id
			end
		end

		# Get the corresponding id from a username
		def self.user_id(name)
			self.open do |db|
				db.execute %{
					SELECT rowid FROM users
					WHERE name = '?';
				}, [name] do |row|
					return row['rowid']
				end
			end
		end

		# Add a repo
		def self.add_repo(name = nil, import_path, owner)
			self.open do |db|
				owner_id = owner.is_a? Integer ? owner : self.user_id(owner)
				db.execute %{
					INSERT INTO repos
						(name, import_path, owner)
					VALUES
						(?, ?, ?);
				}, [name || import_path.split('/').last.delete '.git', # If no name was supplied, use the repo filename
					import_path,
					owner_id] # If the function was called using the owner id, use it, otherwise convert
				repo_id = db.last_insert_row_id
				db.execute %{
					UPDATE users SET
						repos = repos ||
							CASE repos NOT LIKE '' THEN
								','
							END
					WHERE owner = ':owner';
					UPDATE users SET
						repos = repos || ':repo'
					WHERE owner = ':owner';
				}, {:owner => owner_id, :repo => repo_id}
				return repo_id
			end
		end
	end
end
