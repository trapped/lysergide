require 'sinatra/base'
require 'lysergide/database'

include Lysergide::Database

class Lysergide::Fisherman < Sinatra::Base
	post '/hook' do
		repo = Repo.where(name: params[:name], remote: params[:remote]).first
		if repo
			params[:refs].split('\n').each do |ref|
				sref = ref.split ' '
				new_commit = sref[1]
				repo.builds.create {
					number: repo.builds.sort_by(:number).last.number,
					ref: new_commit,
					status: "Scheduled"
				}
			end
		else
			status 400
		end
	end
end
