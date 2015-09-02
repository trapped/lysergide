module Lysergide::Helpers
  def duration(num)
    if num.nil?
      # Old builds didn't support date/duration
      return ''
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

  def alert_obj(err)
    return nil unless err
    obj = Object.new
    obj.class.module_eval {
      attr_accessor :type
      attr_accessor :msg
    }
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
        "Only the repo owner can retry builds."
      else
        "Unknown error: #{err}"
      end
    obj
  end
end
