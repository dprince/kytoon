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
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = "kytoon"
    gemspec.summary = "Create & configure ephemeral virtual private clouds."
    gemspec.description = "A set of Rake tasks that provide a framework to help automate the creation and configuration of VPC server groups."
    gemspec.email = "dprince@redhat.com"
    gemspec.homepage = "http://github.com/dprince/kytoon"
    gemspec.authors = ["Dan Prince"]
    gemspec.add_dependency 'rake'
    gemspec.add_dependency 'builder'
    gemspec.add_dependency 'json'
    gemspec.add_dependency 'uuidtools'
  end
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end
