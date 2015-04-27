require 'lysergide/database'
require 'sinatra/base'
require 'json'
require 'openssl'
require 'rack/utils'

include Lysergide::Database

class Lysergide::Hooks < Sinatra::Base
	# Seems like the before/after filters from Lysergide::Application either don't work with POST or they don't reach here
	before do
		LOG.info("Lysergide") {
			"#{request.scheme.upcase} #{request.request_method} from #{request.ip.to_s}: " +
			"#{request.path} user_agent:\"#{request.user_agent}\" content_length:\"#{request.content_length}\""
		}
	end

	after do
		ActiveRecord::Base.clear_active_connections!
	end

	# Default (post-receive-lys) hook
	post '/hook' do
		# Disable cookies for this request
		request.session_options[:skip] = true
		# The header is actually X-Lysergide-Token
		repo = Repo.find_by_token(request.env["HTTP_X_LYSERGIDE_TOKEN"])
		if repo
			request.body.rewind
			body = request.body.read
			body.split('\n').each do |ref| # reverse chronological order
				sref = ref.split(' ')
				new_commit = sref[1]
				last_build = repo.builds.order(number: :desc).first
				number = 1
				if last_build
					number = last_build.number + 1
				end
				new_build = repo.builds.create({
					user_id: repo.user.id,
					number: number,
					ref: new_commit,
					status: :scheduled
				})
				if new_build
					LOG.info('Lysergide::Hooks') {
						"New build (#{new_build.repo.user.name}/#{new_build.repo.name}##{new_build.number}) has been scheduled"
					}
					status 200 # TODO: only the latest commit?
				else
					LOG.error('Lysergide::Hooks') { "Internal error on repo.builds.create (standard hook)" }
					status 500
				end
			end
		else
			LOG.error('Lysergide::Hooks') { "No matching repo found for token #{request.env['HTTP_X_LYSERGIDE_TOKEN']}" }
			status 400
		end
	end

	# GitHub (JSON) hook
	post '/hook/github' do
		# Disable cookies for this request
		request.session_options[:skip] = true
		request.body.rewind
		body = request.body.read
		gh_payload = JSON.parse(body)
		case request.env['HTTP_X_GITHUB_EVENT']
		when 'ping'
			LOG.info('Lysergide::Hooks') { "Received GitHub ping event (#{gh_payload['zen']}/#{gh_payload['hook_id']})" }
			halt 200
		when 'push'
			commits = gh_payload['commits']
			gh_repo = gh_payload['repository']
			repos = Repo.where(import_path: [gh_repo['url'], gh_repo['clone_url'], gh_repo['git_url'], gh_repo['ssh_url']])
			if !repos || repos.empty?
				LOG.error('Lysergide::Hooks') { "No matching repo for '#{gh_repo['url']}'"}
				halt 400, {'Content-Type' => 'text/plain'}, 'No matching repo'
			end
			repos.each do |repo|
				unique_signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), repo.token, body)
				if Rack::Utils.secure_compare(unique_signature, request.env['HTTP_X_HUB_SIGNATURE'])
					commits.each do |commit|
						new_commit = commit['sha'] || commit['id']
						if !new_commit || new_commit.empty?
							LOG.error('Lysergide::Hooks') { "Couldn't get the commit SHA or id from JSON (GitHub hook)" }
							halt 400, {'Content-Type' => 'text/plain'}, 'Couldn\'t get commit SHA or id from JSON'
						end
						last_build = repo.builds.order(number: :desc).first
						number = 1
						if last_build
							number = last_build.number + 1
						end
						new_build = repo.builds.create({
							user_id: repo.user.id,
							number: number,
							ref: new_commit,
							status: :scheduled
						})
						if new_build
							LOG.info('Lysergide::Hooks') {
								"New build (#{new_build.repo.user.name}/#{new_build.repo.name}##{new_build.number}) has been scheduled"
							}
							halt 200
						else
							LOG.error('Lysergide::Hooks') { "Internal error on repo.builds.create (GitHub hook)" }
							halt 500
						end
					end
				end
			end
		else
			LOG.error('Lysergide::Hooks') { "Unhandled GitHub hook event: #{request.env['HTTP_X_GITHUB_EVENT']}" }
			halt 400
		end
	end

	# BitBucket (unsigned JSON) hook
	post '/hook/bitbucket' do
		# Disable cookies for this request
		request.session_options[:skip] = true
		request.body.rewind
		body = request.body.read
		bb_payload = JSON.parse(body)
		repo_url = "#{bb_payload['canon_url']}/#{bb_payload['repository']['owner']}/#{bb_payload['repository']['name']}"
		repos = Repo.where(import_path: repo_url)
		if !repos || repos.empty?
			LOG.error('Lysergide::Hooks') { "No matching repo for '#{repo_url}'"}
			halt 400, {'Content-Type' => 'text/plain'}, 'No matching repo'
		end
		repos.each do |repo|
			commits = bb_payload['commits']
			commits.each do |commit|
				new_commit = commit['raw_node']
				if !new_commit || new_commit.empty?
					LOG.error('Lysergide::Hooks') { "Couldn't get the commit raw node from JSON (BitBucket hook)" }
					halt 400, {'Content-Type' => 'text/plain'}, 'Couldn\'t get commit raw node from JSON'
				end
				last_build = repo.builds.order(number: :desc).first
				number = 1
				if last_build
					number = last_build.number + 1
				end
				new_build = repo.builds.create({
					user_id: repo.user.id,
					number: number,
					ref: new_commit,
					status: :scheduled
				})
				if new_build
					LOG.info('Lysergide::Hooks') {
						"New build (#{new_build.repo.user.name}/#{new_build.repo.name}##{new_build.number}) has been scheduled"
					}
					halt 200
				else
					LOG.error('Lysergide::Hooks') { "Internal error on repo.builds.create (BitBucket hook)" }
					halt 500
				end
			end
		end
	end
end
