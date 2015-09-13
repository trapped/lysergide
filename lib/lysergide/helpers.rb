include Lysergide::Database

module Lysergide
  module Helpers
    def duration(num)
      if num.nil?
        return '' # Old builds didn't support date/duration
      end
      secs  = num.to_int
      mins  = secs / 60
      hours = mins / 60
      days  = hours / 24

      if days > 0
        "#{days} days and #{hours % 24} hours"
      elsif hours > 0
        "#{hours} hours and #{mins % 60} minutes"
      elsif mins > 0
        "#{mins} minutes and #{secs % 60} seconds"
      elsif secs >= 0
        "#{secs} seconds"
      end
    end

    def valid_repo_name?(name)
      (name =~ /\A\p{Alnum}+\z/) != nil
    end

    def valid_repo_path?(path)
      (URI.regexp =~ path) != nil
    end

    def repo_public?(user, repo)
      return nil unless user = User.find_by_name(user)
      return nil unless repo = user.repos.find_by_name(repo)
      repo.public?
    end

    def client_user?(user, client_id)
      return nil unless user = User.find_by_name(user)
      client_id == user.id
    end

    def alert_obj(err)
      return nil unless err
      obj = Object.new
      obj.class.module_eval do
        attr_accessor :type
        attr_accessor :msg
      end
      obj.type =
        case err
        when 'name', 'path', 'not_owner', 'unknown'
          'danger'
        else
          'warning'
        end
      obj.msg =
        case err
        when 'name'
          'Invalid repo name; only alphanumeric names are allowed.'
        when 'path'
          'Invalid repo path; check it is a valid URI and git recognizes it.'
        when 'unknown'
          'Unknown error.'
        when 'not_owner'
          'Only the repo owner can retry builds.'
        else
          "Unknown error: #{err}"
        end
      obj
    end
  end
end
