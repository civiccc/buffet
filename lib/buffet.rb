require 'fileutils'
require 'find'
require 'logger'
require 'pathname'

module Buffet
  autoload :CommandRunner, 'buffet/command_runner'
  autoload :Master, 'buffet/master'
  autoload :Project, 'buffet/project'
  autoload :Runner, 'buffet/runner'
  autoload :Settings, 'buffet/settings'
  autoload :Slave, 'buffet/slave'

  def self.logdir
    @logdir ||= Pathname.new(ENV['HOME']) + '.buffet/log'
  end

  def self.logfile
    'buffet.log'
  end

  def self.logger
    @logger ||= begin
      FileUtils.mkdir_p logdir
      Logger.new logdir + logfile
    end
  end

  def self.runner
    @runner ||= CommandRunner.new logger
  end

  def self.run! *command
    result = runner.run *command
    unless result.success?
      logger.error 'exiting due to non-zero exit status'
      exit result.status
    end
    result
  end

  # Given a set of files/directories, return all spec files contained
  def self.extract_specs_from files
    specs = []
    files.each do |spec_file|
      Find.find(spec_file) do |f|
        specs << f if f.match /_spec\.rb$/
      end
    end
    specs.uniq
  end
end
