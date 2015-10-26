require 'spec_helper'

require 'formatron/cli'
require 'formatron/cli/provision'

describe Formatron::CLI::Provision do
  include FakeFS::SpecHelpers

  # Test harness
  class Test < Formatron::CLI
    include Formatron::CLI::Provision
  end

  credentials = 'credentials'
  directory = 'directory'
  target = 'production'
  target_index = 1

  expected_constructor_params = [
    credentials,
    directory
  ]

  expected_params = [
    target
  ]

  before(:each) do
    @formatron = instance_double('Formatron')
    allow(@formatron).to receive(:targets) do
      %w(production test)
    end
    allow(@formatron).to receive(:protected?) do
      true
    end
  end

  context 'with no options and global defaults' do
    before(:each) do
      allow(Commander::Runner).to receive(:instance) do
        @singleton ||= Commander::Runner.new ['provision', '-t']
      end
    end

    it 'should prompt for target' do
      responses = <<-EOH.gsub(/^ {8}/, '')
        #{target_index}
        yes
      EOH
      @input = StringIO.new responses
      @output = StringIO.new
      # rubocop:disable Style/GlobalVars
      $terminal = HighLine.new @input, @output
      # rubocop:enable Style/GlobalVars
      expect(
        Formatron
      ).to receive(:new).once.with(
        File.join(Dir.home, '.formatron/credentials.json'),
        Dir.pwd
      ) do
        @formatron
      end
      expect(@formatron).to receive(:provision).with(
        *expected_params
      ).once
      Test.new.run
    end
  end

  context 'with no options and local defaults' do
    before(:each) do
      FileUtils.mkdir_p File.join(Dir.pwd, '.formatron')
      File.write File.join(Dir.pwd, '.formatron/credentials.json'), ''
      allow(Commander::Runner).to receive(:instance) do
        @singleton ||= Commander::Runner.new ['provision', '-t']
      end
    end

    it 'should prompt for target' do
      responses = <<-EOH.gsub(/^ {8}/, '')
        #{target_index}
        yes
      EOH
      @input = StringIO.new responses
      @output = StringIO.new
      # rubocop:disable Style/GlobalVars
      $terminal = HighLine.new @input, @output
      # rubocop:enable Style/GlobalVars
      expect(
        Formatron
      ).to receive(:new).once.with(
        File.join(Dir.pwd, '.formatron/credentials.json'),
        Dir.pwd
      ) do
        @formatron
      end
      expect(@formatron).to receive(:provision).with(
        *expected_params
      ).once
      Test.new.run
    end
  end

  context 'with all short form options' do
    before(:each) do
      allow(Commander::Runner).to receive(:instance) do
        @singleton ||=
          Commander::Runner.new [
            'provision',
            '-t',
            '-c', credentials,
            '-d', directory,
            target
          ]
      end
    end

    it 'should not prompt for target' do
      responses = <<-EOH.gsub(/^ {8}/, '')
        yes
      EOH
      @input = StringIO.new responses
      @output = StringIO.new
      # rubocop:disable Style/GlobalVars
      $terminal = HighLine.new @input, @output
      # rubocop:enable Style/GlobalVars
      expect(
        Formatron
      ).to receive(:new).once.with(
        *expected_constructor_params
      ) do
        @formatron
      end
      expect(@formatron).to receive(:provision).with(
        *expected_params
      ).once
      Test.new.run
    end
  end

  context 'with all long form options' do
    before(:each) do
      allow(Commander::Runner).to receive(:instance) do
        @singleton ||=
          Commander::Runner.new [
            'provision',
            '-t',
            '--credentials', credentials,
            '--directory', directory,
            target
          ]
      end
    end

    it 'should not prompt for target' do
      responses = <<-EOH.gsub(/^ {8}/, '')
        yes
      EOH
      @input = StringIO.new responses
      @output = StringIO.new
      # rubocop:disable Style/GlobalVars
      $terminal = HighLine.new @input, @output
      # rubocop:enable Style/GlobalVars
      expect(
        Formatron
      ).to receive(:new).once.with(
        *expected_constructor_params
      ) do
        @formatron
      end
      expect(@formatron).to receive(:provision).with(
        *expected_params
      ).once
      Test.new.run
    end
  end
end
