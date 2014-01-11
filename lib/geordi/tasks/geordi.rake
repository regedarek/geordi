require 'rake'
require 'bundler'
require File.expand_path('../../cuc', __FILE__)

namespace :geordi do

  desc 'Run tests with `rake`'
  task :rake_test => [:bundle] do
    next unless file_containing?('Rakefile', /^task.+default.+(spec|test)/)

    announce 'Running tests (rake)'
    system! 'rake'
  end

  desc 'Run RSpec'
  task :spec, [:spec_args] => [:bundle] do |task, args|
    next unless File.directory?('spec')

    announce 'Running specs'
    spec_args = args[:spec_args] || []

    if file_containing?('Gemfile', /parallel_tests/) and spec_args.empty?
      note 'All specs at once (using parallel_tests)'
      system! 'bundle exec rake parallel:spec'

    else
      # tell which specs will be run
      if spec_args.empty?
        spec_args << 'spec/'
        note 'All specs in spec/'
      else
        note 'Only: ' + spec_args.join(', ')
      end

      command = ['bundle exec']
      # differentiate RSpec 1/2
      command << (File.exists?('script/spec') ? 'spec -c' : 'rspec')
      command << '-r rspec_spinner -f RspecSpinner::Bar' if file_containing?('Gemfile', /rspec_spinner/)
      command << spec_args.join(' ')

      puts
      system! command.join(' ')
    end
  end

  desc 'Run Cucumber features'
  task :features, [:feature_args] => [:bundle] do |task, args|
    next unless File.directory?('features')

    announce 'Running features'
    Geordi::Cucumber.new.run(args[:feature_args] || [])
  end

  desc 'Start a development server'
  task :server, [:port] => [:bundle] do |task, args|
    next unless File.directory?('public') # there will be no server to start
    port = args[:port] || 3000

    announce 'Booting a development server on Port ' + port

    command = if File.exists?('script/server')
      'script/server' # Rails 2
    else
      'bundle exec rails server' # Rails 3+
    end

    command << " -p #{port}"
    system command
  end

  desc 'Git pull'
  task :pull do
    announce 'Updating repository (git pull)'
    system! 'git pull'
  end

  desc 'Migrate'
  task :migrate => [:bundle] do
    next unless File.directory?('db/migrate')

    announce 'Migrating'

    if file_containing?('Gemfile', /parallel_tests/)
      system! 'bundle exec rake db:migrate parallel:prepare'
    else
      system! 'power-rake db:migrate'
    end
  end

  desc 'Create databases (only if a database.yml exists)'
  task :create_databases => ['config/database.yml', :bundle] do
    next unless File.exists?('config/database.yml')

    announce 'Creating databases'
    system! 'bundle exec rake db:create:all'
  end

  desc 'Create database.yml (only if missing and .sample.yml exists)'
  file 'config/database.yml' do |file_task|
    sample_yml = 'config/database.sample.yml'

    if File.exists?(sample_yml)
      announce 'Creating ' + file_task.name
      print 'Please enter your DB password: '
      db_password = STDIN.gets.strip

      sample = File.read(sample_yml)
      real = sample.gsub(/password:.*$/, "password: #{db_password}")
      File.open(file_task.name, 'w') { |f| f.write(real) }

      puts "Created #{file_task.name}."
    end
  end

  desc 'Bundle install (only if necessary)'
  task :bundle do
    if File.exists?('Gemfile') and !system('bundle check &>/dev/null')
      announce 'Bundling'
      system! 'bundle install'
    end
  end

  private

  def system!(*commands)
    # We cannot run Rake tasks natively (although we're inside a Rake task),
    # because we would probably not be using the version specified in the
    # Gemfile, and we don't want to add Geordi to a Gemfile either.
    Bundler.clean_system(*commands) or fail
  end

  def file_containing?(file, regex)
    File.exists?(file) and File.read(file).scan(regex).any?
  end

end
