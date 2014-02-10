require 'spec_helper'

describe Buffet::Settings do
  before do
    Buffet::Settings.reset!
  end

  describe '.[]' do
    it 'reads from a Yaml file called "buffet.yml"' do
      YAML.should_receive(:load_file).
        with('buffet.yml').
        and_return({'foo' => 'bar'})
      Buffet::Settings['foo'].should == 'bar'
    end

    it 'memoizes the contents of the settings file' do
      YAML.should_receive(:load_file).once.
        and_return({'foo' => 'bar'})
      Buffet::Settings['foo'].should == 'bar'
      Buffet::Settings['foo'].should == 'bar'
    end
  end

  describe '.prepare_command' do
    context 'with an explicit setting' do
      before do
        YAML.stub(:load_file).
          and_return('prepare_command' => 'prep')
      end

      it 'returns the set value' do
        Buffet::Settings.prepare_command.should == 'prep'
      end
    end

    context 'with no explicit setting' do
      before do
        YAML.stub(:load_file).and_return({})
      end

      it 'returns the default value' do
        Buffet::Settings.prepare_command.should == 'bin/before-buffet-run'
      end
    end
  end

  describe '.prepare_command?' do
    context 'with an explicit setting' do
      before do
        YAML.stub(:load_file).
          and_return('prepare_command' => 'foo')
      end

      it 'returns true' do
        Buffet::Settings.prepare_command?.should be_true
      end
    end

    context 'with no explicit setting' do
      before do
        YAML.stub(:load_file).and_return({})
      end

      context 'with the default file present' do
        before do
          File.stub(:exist?).and_return(true)
        end

        it 'returns true' do
          Buffet::Settings.prepare_command?.should be_true
        end
      end

      context 'without the default file present' do
        before do
          File.stub(:exist?).and_return(false)
        end

        it 'returns false' do
          Buffet::Settings.prepare_command?.should be_false
        end
      end
    end
  end
end
