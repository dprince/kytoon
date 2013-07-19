require 'rake/testtask'

KYTOON_PROJECT = "#{File.dirname(__FILE__)}" unless defined?(KYTOON_PROJECT)

$:.unshift File.join(File.dirname(__FILE__),'lib')
require 'kytoon'
include Kytoon

Dir[File.join(File.dirname(__FILE__), 'rake', '*.rake')].each do  |rakefile|
        import(rakefile)
end

Rake::TestTask.new(:test) do |t|
        t.pattern = 'test/*_test.rb'
        t.verbose = true
end
Rake::Task['test'].comment = "Unit"

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "kytoon"
    gem.summary = "Create & configure ephemeral virtual private clouds."
    gem.description = "A set of Rake tasks that provide a framework to help automate the creation and configuration server groups."
    gem.email = "dprince@redhat.com"
    gem.homepage = "http://github.com/dprince/kytoon"
    gem.authors = ["Dan Prince"]
    gem.add_dependency 'rake'
    gem.add_dependency 'builder'
    gem.add_dependency 'json'
    gem.add_dependency 'fog'
    gem.add_dependency 'thor'
    gem.add_dependency 'uuidtools'
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end
