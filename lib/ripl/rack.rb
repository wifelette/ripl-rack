require 'ripl'
require 'rack'
require 'rack/test'

module Ripl::Rack
  VERSION = '0.2.1'

  def before_loop
    Commands.rack
    Commands.rackit! if config[:rackit]
    puts "Loading #{Commands.rack.env} environment (Rack #{Rack.version})"
    super
  end

  module Commands
    extend self
    def rack
      Ripl::Rack::App.instance
    end

    def rackit!
      Ripl::Rack::Commands.module_eval do
        rack.actions.each do |meth|
          define_method(meth) {|*args| rack.send(meth, *args) }
        end
      end
    end
  end

  class App
    include Rack::Test::Methods
    attr_reader :app, :env
    MESSAGE = "Rack config file '%s' doesn't exist. Specify with ENV['RACK_CONFIG']"

    def initialize(config_ru=nil)
      config_ru ||= ENV['RACK_CONFIG'] || 'config.ru'
      abort(MESSAGE % config_ru) unless File.exist? config_ru

      basepath = File.expand_path(config_ru)
      body = File.read(config_ru)

      file = <<~RUBY
        Rack::Builder.new do
          #{body}
        end
      RUBY

      @app = Kernel.eval(file, TOPLEVEL_BINDING, basepath, 0)

      @env = ENV['RACK_ENV'] || 'development'
    end

    def actions
      ::Rack::Test::Methods::METHODS
    end

    def self.instance
      @instance ||= self.new
    end
  end
end

Ripl::Shell.include Ripl::Rack
Ripl::Commands.include Ripl::Rack::Commands
