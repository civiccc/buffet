require 'spec_helper'
require 'mkdtemp'

describe Buffet::CommandRunner do
  let(:log_buffer) { StringIO.new "" }
  let(:logger) { Logger.new log_buffer }
  let(:runner) { Buffet::CommandRunner.new logger }

  context 'with a successful command' do
    let(:touch_file) { 'file1' }

    before :all do
      Dir.mkdtemp do
        `touch #{touch_file}`
        @result = runner.run 'ls'
      end
      log_buffer.seek(0)
      @log_output = log_buffer.read
    end

    it 'returns a exit status of zero' do
      @result.status.should be_zero
    end

    it 'returns a #success? value of true' do
      @result.success?.should be_true
    end

    it 'returns the stdout output' do
      @result.stdout.chomp.should == touch_file
    end

    it 'returns the stderr output' do
      @result.stderr.should be_empty
    end

    it 'logs the command that was run' do
      @log_output.should match(/command: ls/)
    end

    it 'logs the exit status code of the command' do
      @log_output.should match(/status: 0/)
    end

    it 'logs the stdout output of the command' do
      @log_output.should match(/stdout:\n#{touch_file}/)
    end

    it 'logs the stderr output of the command' do
      @log_output.should match(/stderr:\n/)
    end
  end

  context 'with an unsuccessful command' do
    let(:existing_file) { 'file1' }
    let(:non_existing_file) { 'file2' }

    before :all do
      Dir.mkdtemp do
        `touch #{existing_file}`
        @result = runner.run 'ls', existing_file, non_existing_file
      end
      log_buffer.seek(0)
      @log_output = log_buffer.read
    end

    it 'returns a non-zero exit status' do
      @result.status.should_not be_zero
    end

    it 'returns a #success? value of false' do
      @result.success?.should be_false
    end

    it 'returns the stdout output' do
      @result.stdout.chomp.should == existing_file
      @result.stdout.chomp.should_not == non_existing_file
    end

    it 'returns the stderr output' do
      @result.stderr.should match(/#{non_existing_file}/)
      @result.stderr.should_not match(/#{existing_file}/)
    end

    it 'logs the command that was run' do
      @log_output.should match(/command: ls #{existing_file} #{non_existing_file}/)
    end

    it 'logs the exit status code of the command' do
      @log_output.should match(/status: #{@result.status}/)
    end

    it 'logs the stdout output of the command' do
      @log_output.should match(/stdout:\n#{existing_file}/)
    end

    it 'logs the stderr output of the command' do
      @log_output.should match(/stderr:\n.*#{non_existing_file}/)
    end
  end

  it 'logs to stdout by default' do
    Logger.should_receive(:new).with(STDOUT)
    runner = Buffet::CommandRunner.new
  end
end
