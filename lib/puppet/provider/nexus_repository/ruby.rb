require 'json'
require File.join(File.dirname(__FILE__), '..', 'nexus_rest')

Puppet::Type.type(:nexus_repository).provide(:ruby) do
    desc "Uses Ruby's rest library"

    def self.instances
      repositories = Nexus::Rest.get_all('/service/local/repositories')
      return repositories['data'].collect do |repository|
        name = repository['id']
        new(:name => name, :ensure => :present)
      end
    end

  def self.prefetch(resources)
    repositories = instances
    resources.keys.each do |name|
      if provider = repositories.find { |repository| repository.name == name }
        resources[name].provider = provider
      end
    end
  end

    def create
      begin
        Nexus::Rest.create('/service/local/repositories')
      rescue Exception => e
        raise Puppet::Error, "Error while creating nexus_repository #{resource[:name]}: #{e}"
      end
    end

    def update
      begin
        Nexus::Rest.update("/service/local/repositories/#{resource[:name]}")
      rescue Exception => e
        raise Puppet::Error, "Error while updating nexus_repository #{resource[:name]}: #{e}"
      end
    end

    def destroy
      begin
        Nexus::Rest.destroy("/service/local/repositories/#{resource[:name]}")
      rescue Exception => e
        raise Puppet::Error, "Error while deleting nexus_repository #{resource[:name]}: #{e}"
      end
    end

    def exists?
      @property_hash[:ensure] == :present
    end
end