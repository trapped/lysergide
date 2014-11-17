Gem::Specification.new do |gem|
  gem.name      = 'lysergide'
  gem.version   = '0.1'

  gem.author    = 'trapped'
  gem.homepage  = 'https://github.com/trapped/lysergide'
  gem.summary   = 'Web frontend for Acid'
  gem.license   = 'MIT'

  gem.files     = %x{ git ls-files }.split("\n").select { |d| d =~ %r{^(LICENSE|README|bin/|lib/)} }

  gem.add_dependency 'sinatra'
  gem.add_dependency 'faraday'
  gem.add_dependency 'faraday_middleware'
  gem.add_dependency 'thin'
  gem.add_dependency 'sqlite3'
  gem.add_dependency 'haml'
  gem.add_dependency 'sass'
  gem.add_dependency 'coffee'
end
