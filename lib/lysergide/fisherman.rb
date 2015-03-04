require 'sinatra/base'
require 'lysergide/database'

include Lysergide::Database

class Lysergide::Fisherman < Sinatra::Base
	post '/hook/:hash' do
		repo = Repo.find(token: headers["X-Lysergide-Token"])
		if repo
			request.body.rewind
			request.body.read.split('\n').each do |ref|
				sref = ref.split ' '
				new_commit = sref[1]
				repo.builds.create ({
					number: repo.builds.sort_by(:number).last.number,
					ref: new_commit,
					status: "Scheduled"
				})
			end
		else
			status 400
		end
	end
end
