#!/usr/local/bin/ruby
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + "/.."))

require 'buffet/buffet'
require 'buffet/settings'

module Buffet
  class Checker
    def self.check verbosity
      hosts = Settings.get['hosts']
      local_ruby_version = get_version_from_versionstring(`ruby --version`)

      hosts.each do |host|
        # check availability of each host
        exit_status, result = run_remote_command host, 'uptime'
        unless exit_status.zero?
          hosts.delete(host)
          puts "#{host} unreachable"
          next
        end

        # Check ruby version on each host
        exit_status, result = run_remote_command host, 'ruby --version'
        remote_ruby_version = get_version_from_versionstring(result)
        unless remote_ruby_version == local_ruby_version
          hosts.delete(host)
          puts "#{host} has mismatched ruby " +
               "(got #{remote_ruby_version}, expected #{local_ruby_version})"
        end

        # Check for presence of bundler
        exit_status, result = run_remote_command host, 'bundle --version'
        unless result.match(/^Bundler/)
          hosts.delete(host)
          puts "#{host} doesn't have bundle"
        end
      end

      # display good hosts
      hosts.each {|host| puts "#{host} Ok!" }
    end

    private

    def self.run_remote_command host, command
      result = `ssh buffet@#{host} -o PasswordAuthentication=no #{command} 2>&1`
      return $?.to_i, result
    end

    def self.get_version_from_versionstring versionstring
      versionstring.split(' ')[1]
    end
  end
end
