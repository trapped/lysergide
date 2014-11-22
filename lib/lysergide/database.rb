require 'sqlite3'
require 'timeout'
require 'colorize'

module Lysergide
	module Database
		# Get a Database object
		def self.open(&block)
			conn = SQLite3::Database.new 'lysergide.db'
			# Allow accessing row data by column name instead of index
			conn.results_as_hash = true
			if block
				begin
					block.call(conn)
				ensure
					conn.close
				end
			else
				return conn
			end
		end

		def self.destroy()
			begin
				if !File.exists? 'lysergide.db'
					raise 'No database to wipe.'
				end
				print 'Do you really want to completely wipe the database? (10 seconds before timeout) [y/N] '
				Timeout.timeout(10) {
					answer = STDIN.gets.chomp
					if answer.length > 0 && answer[0].upcase == 'Y'
						File.delete 'lysergide.db'
					end
					puts "\nDatabase wiped. You can initialize a new one with 'lsd populate user email password'"
					return 0
				}
			rescue => e
				puts "Database wipe aborted: '#{e.message.to_s.red}'"
			end
			return 1
		end

		# Populate the database with initial/default data (admin account, etc.)
		def self.populate(name, email, password)
			self.open do |db|
				# Create users table
				db.execute %{
					CREATE TABLE users (
						id			integer	primary key	autoincrement,
						name		text	unique	not null,
						email		text	unique	not null,
						password	text			not null,
						repos		text,
						builds		text
					)
				}
				# Add admin user
				self.add_user(name || 'admin', email || 'admin@example.com', password || 'admin')

				# Create repos table
				db.execute %{
					CREATE TABLE repos (
						id			integer	primary key	autoincrement,
						name		text			not null,
						import_path	text	unique	not null,
						owner		integer			not null,
						builds		text
					)
				}

				# Create builds table
				db.execute %{
					CREATE TABLE builds (
						id			integer	primary key	autoincrement,
						repo		integer			not null,
						number		integer			not null,
						status		text			not null,
						duration	integer,
						ref			text			not null,
						log			text
					)
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
						(?, ?, ?)
				}, [name, email, password]
				return db.last_insert_row_id
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
						(?, ?, ?)
				}, [name || import_path.split('/').last.delete('.git'), # If no name was supplied, use the repo filename
					import_path,
					owner_id] # If the function was called using the owner id, use it, otherwise convert
				repo_id = db.last_insert_row_id
				db.execute_batch %{
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

		# If an email and password match an account, get its id
		def self.login(email, password)
			self.open do |db|
				row = db.get_first_row %{
					SELECT id FROM users
					WHERE email = ? AND password = ?
				}, [email, password]
				return row['id'] if row
			end
		end

		# Get a user row
		def self.user(id)
			self.open do |db|
				row = db.get_first_row %{
					SELECT name, email, repos, builds FROM users
					WHERE id = ?
				}, [id]
				return {
					:name => row['name'],
					:email => row['email'],
					:repos => row['repos'],
					:builds => row['builds']
				} if row
			end
		end

		# Get the row id of something (user, repo, build) by name
		def self.id_of(name, type=:user)
			self.open do |db|
				row = db.get_first_row %{
					SELECT id FROM ?
					WHERE name = ?
				}, [{case type
					when :user 'users'
					when :repo 'repos'
					when :build 'builds'
					else
						raise "unknown type #{type}"
					end
					}, name]
				return row['id'] if row
			end
		end

		# Get the name of something (user, repo)
		def self.name_of()
	end
end
