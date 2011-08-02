#!/usr/bin/env ruby

require 'buffet/settings'

DATA_PATH = File.expand_path(File.dirname(__FILE__) + '/../../data')

FAIL_FILE = DATA_PATH + "/fails.dat"
ALL_FILE  = DATA_PATH + "/all.dat"
REPO_FILE = DATA_PATH + "/repo.dat"

require 'fileutils'

module Buffet
  class Regression
    def initialize(new_passes, new_fails)
      FileUtils.mkdir_p(DATA_PATH)
      regressions, old_all, old_fails = [], [], []
      old_repo = ""
      
      # Don't bother checking for regressions if the repos are the same.
      if File.exist? REPO_FILE
        File.open(REPO_FILE, 'r') do |file|
          old_repo = file.readlines.join ""
        end
      end

      if has_old_data
        if old_repo != Settings.get['repository']
          File.delete(FAIL_FILE)
          File.delete(ALL_FILE)
        else
          File.open(ALL_FILE , 'r') do |file|
            old_all = eval(file.readlines.join "")
          end

          File.open(FAIL_FILE, 'r') do |file|
            old_fails = eval(file.readlines.join "")
          end

          regressions = get_regressions(old_fails, old_all, new_fails)
        end
      end

      File.open(ALL_FILE , 'w') do |file|
        all = new_passes + new_fails
        file.write all.inspect
      end

      File.open(FAIL_FILE, 'w') do |file|
        file.write new_fails.inspect
      end

      File.open(REPO_FILE, 'w') do |file|
        file.write Settings.get['repository']
      end

      @regressions = regressions
    end

    def regressions
      @regressions
    end

    private

    def get_regressions(old_fails, old_all, new_fails)
      regressions = []

      new_fails.each do |fail|
        if not old_fails.include? fail and old_all.include? fail
          regressions.push(fail)
        end
      end

      regressions
    end

    def has_old_data
      File.exists? ALL_FILE or File.exists? FAIL_FILE
    end
  end
end
