require 'lysergide/database'
require 'dish/ext'

class Lysergide::User
	def initialize(id)
		@id = id
	end

	def name
		Lysergide::Database.name_of @id
	end

	def email
		Lysergide::Database.email_of @id
	end

	def repos
		Lysergide::Database.repos_of(@id).to_dish
	end

	def builds
		Lysergide::Database.builds_of(@id).to_dish
	end
end
