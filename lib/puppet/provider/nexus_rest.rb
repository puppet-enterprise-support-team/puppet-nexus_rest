require 'json'
require 'yaml'
require 'rest_client'

module Nexus
  class Config
    CONFIG_FILE_NAME = '/etc/puppet/nexus_rest.conf'
    CONFIG_BASE_URL = 'base_url'
    CONFIG_ADMIN_USERNAME = 'admin_username'
    CONFIG_ADMIN_PASSWORD = 'admin_password'

    def self.base_url
      return config[CONFIG_BASE_URL].chomp('/')
    end

    def self.admin_username
      return config[CONFIG_ADMIN_USERNAME]
    end

    def self.admin_password
      return config[CONFIG_ADMIN_PASSWORD]
    end

    def self.config
      @config  ||= read_config
    end

    def self.read_config
      # todo: add autorequire soft dependency
      begin
        config = YAML.load_file(CONFIG_FILE_NAME)
      rescue
        raise Puppet::ParseError, "Could not parse YAML configuration file " + CONFIG_FILE_NAME + " " + $!.inspect
      end

      if config[CONFIG_BASE_URL].nil?
        raise Puppet::ParseError, "Config file #{CONFIG_FILE_NAME} must contain a value for key '#{CONFIG_BASE_URL}'."
      end
      if config[CONFIG_ADMIN_USERNAME].nil?
        raise Puppet::ParseError, "Config file #{CONFIG_FILE_NAME} must contain a value for key '#{CONFIG_ADMIN_USERNAME}'."
      end
      if config[CONFIG_ADMIN_PASSWORD].nil?
        raise Puppet::ParseError, "Config file #{CONFIG_FILE_NAME} must contain a value for key '#{CONFIG_ADMIN_PASSWORD}'."
      end

      config
    end
  end

  class Rest
    def self.client
      base_url = Nexus::Config.base_url
      admin_username = Nexus::Config.admin_username
      admin_password = Nexus::Config.admin_password
      RestClient::Resource.new(base_url, :user => admin_username, :password => admin_password, :headers => {:accept => :json})
    end

    def self.get_all(resource_name)
      base_url = Nexus::Config.base_url
      begin
        nexus = RestClient::Resource.new(base_url)
        response = nexus[resource_name].get(:accept => :json)
      rescue => e
        []
      end

      begin
        JSON.parse(response)
      rescue => e
        raise Puppet::Error,"Could not parse the JSON response from Nexus: " + response
      end
    end

    def self.create(resource_name, data)
      begin
        client[resource_name].post JSON.generate(data), :content_type => :json
      rescue Exception => e
        raise "Failed to submit POST to #{resource_name}: #{e}"
      end
    end

    def self.update(resource_name, data)
      begin
        client[resource_name].put JSON.generate(data), :content_type => :json
      rescue Exception => e
        raise "Failed to submit PUT to #{resource_name}: #{e}"
      end
    end

    def self.destroy(resource_name)
      begin
        client[resource_name].delete
      rescue RestClient::ResourceNotFound
        # resource already deleted, nothing to do
      rescue Exception => e
        raise "Failed to submit DELETE to #{resource_name}: #{e}"
      end
    end
  end
end
