Gem::Specification.new do |s|
  s.name     = 'hm'
  s.version  = '0.0.1'
  s.authors  = ['Victor Shepelev']
  s.email    = 'zverok.offline@gmail.com'
  s.homepage = 'https://github.com/zverok/hm'

  s.summary = 'Idiomatic nested hash modifications'
  s.description = <<-EOF
    Hm is a library for clean, idiomatic and chainable processing of complicated Ruby structures,
    typically unpacked from JSON. It provides smart dig and bury, keys replacement,
    nested transformations and more.
  EOF
  s.licenses = ['MIT']

  s.files = `git ls-files lib LICENSE.txt *.md`.split($RS)
  s.require_paths = ["lib"]

  s.required_ruby_version = '>= 2.1.0'

  s.add_development_dependency 'yard'
  unless RUBY_ENGINE == 'jruby'
    s.add_development_dependency 'redcarpet'
    s.add_development_dependency 'github-markup'
  end
  s.add_development_dependency 'yard-junk'

  s.add_development_dependency 'rspec', '~> 3.7.0'
  s.add_development_dependency 'rspec-its'
  s.add_development_dependency 'saharspec'

  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'rubocop-rspec'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubygems-tasks'
  s.add_development_dependency 'benchmark-ips'
end
