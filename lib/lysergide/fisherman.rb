require 'sinatra/base'
require 'lysergide/database'

include Lysergide::Database

class Lysergide::Fisherman < Sinatra::Base
	post '/hook' do
		# The header is actually X-Lysergide-Token
		repo = Repo.find_by_token(request.env["HTTP_X_LYSERGIDE_TOKEN"])
		if repo
			request.body.rewind
			body = request.body.read
			body.split('\n').each do |ref|
				sref = ref.split(' ')
				new_commit = sref[1]
				last_build = repo.builds.order(number: :desc).first
				number = 1
				if last_build
					number = last_build.number
				end
				if repo.builds.create ({
						number: number,
						ref: new_commit,
						status: "scheduled"
					})
					status 200
				else
					status 500
				end
			end
		else
			status 400
		end
	end
end
