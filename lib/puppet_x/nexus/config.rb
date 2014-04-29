require 'json'
require 'yaml'
require 'rest_client'

module Nexus
  class Config
    CONFIG_FILENAME = '/etc/puppet/nexus_rest.conf'
    CONFIG_BASE_URL = 'base_url'
    CONFIG_USERNAME = 'username'
    CONFIG_PASSWORD = 'password'
    CONFIG_TIMEOUT = 'timeout'
    CONFIG_OPEN_TIMEOUT = 'open_timeout'

    def self.configure
      @config ||= read_config
      yield @config[:base_url], {
        :username => @config[:username],
        :password => @config[:password],
        :timeout => @config[:timeout],
        :open_timeout => @config[:open_timeout]
      }
    end

    def self.reset
      @config = nil
    end

    def self.resolve(url)
      unless url.start_with?('http')
        configure { |base_url, options|
          URI.join(base_url, url).to_s
        }
      else
        url
      end
    end

    def self.read_config
      begin
        Puppet::debug("Parsing configuration file #{CONFIG_FILENAME}")
        config = YAML.load_file(CONFIG_FILENAME)
      rescue
        raise Puppet::ParseError, "Could not parse YAML configuration file #{CONFIG_FILENAME}" + $!.inspect
      end

      if config[CONFIG_BASE_URL].nil?
        raise Puppet::ParseError, "Config file #{CONFIG_FILENAME} must contain a value for key '#{CONFIG_BASE_URL}'."
      end
      # TODO: add warning about insecure connection if protocol is http and host not localhost (credentials sent in plain text)
      if config[CONFIG_USERNAME].nil?
        raise Puppet::ParseError, "Config file #{CONFIG_FILENAME} must contain a value for key '#{CONFIG_USERNAME}'."
      end
      if config[CONFIG_PASSWORD].nil?
        raise Puppet::ParseError, "Config file #{CONFIG_FILENAME} must contain a value for key '#{CONFIG_PASSWORD}'."
      end
      config[CONFIG_TIMEOUT] = 10 if config[CONFIG_TIMEOUT].nil?
      config[CONFIG_OPEN_TIMEOUT] = 10 if config[CONFIG_OPEN_TIMEOUT].nil?

      {
        :base_url      => config[CONFIG_BASE_URL].chomp('/'),
        :username      => config[CONFIG_USERNAME],
        :password      => config[CONFIG_PASSWORD],
        :timeout       => Integer(config[CONFIG_TIMEOUT]),
        :open_timeout  => Integer(config[CONFIG_OPEN_TIMEOUT]),
      }
    end
  end
end