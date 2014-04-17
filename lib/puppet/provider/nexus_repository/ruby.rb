require 'json'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'config.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'rest.rb'))

Puppet::Type.type(:nexus_repository).provide(:ruby) do
  desc "Uses Ruby's rest library"

  WRITE_ONCE_ERROR_MESSAGE = "%s is write-once only and cannot be changed without force."
  PROVIDER_ROLE_MAPPING = {
    :hosted  => 'org.sonatype.nexus.proxy.repository.Repository',
    :proxy   => 'org.sonatype.nexus.proxy.repository.Repository',
    :virtual => 'org.sonatype.nexus.proxy.repository.ShadowRepository',
  }

  def initialize(value={})
    super(value)
    @property_flush = {}
  end

  def self.instances
    begin
      repositories = Nexus::Rest.get_all('/service/local/repositories')
      repositories['data'].collect do |repository|
        new(
          :ensure        => :present,
          :name          => repository['id'],
          :label         => repository['name'],
          :provider_type => repository['provider'],
          :type          => repository['repoType'],
          :policy        => repository['repoPolicy']
        )
      end
    rescue => e
      raise Puppet::Error, "Error while retrieving all nexus_repository instances: #{e}"
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
    provider_Role = PROVIDER_ROLE_MAPPING[resource[:type]] or raise Puppet::Error, "Nexus_repository[#{resource[:name]}]: unable to find a suitable provider role for type #{resource[:type]}"
    begin
      Nexus::Rest.create('/service/local/repositories', {
        :data => {
          'contentResourceURI'      => Nexus::Config.resolve("/content/repositories/#{resource[:name]}"),
          :id                       => resource[:name],
          :name                     => resource[:label],
          :repoType                 => resource[:type].to_s,
          :provider                 => resource[:provider_type].to_s,
          :providerRole             => provider_Role,
          'format'                  => 'maven2',
          :repoPolicy               => resource[:policy].to_s,

          'writePolicy'             => 'READ_ONLY',
          'browseable'              => true,
          'indexable'               => true,
          'exposed'                 => true,
          'downloadRemoteIndexes'   => false,
          'notFoundCacheTTL'        => 1440,

          'defaultLocalStorageUrl'  => '',
          'overrideLocalStorageUrl' => '',
        }
      })
    rescue Exception => e
      raise Puppet::Error, "Error while creating nexus_repository #{resource[:name]}: #{e}"
    end
  end

  def flush
    if @property_flush
      data = {}
      data[:repoPolicy] = resource[:policy].to_s if @property_flush[:policy]
      unless data.empty?
        # required values
        data[:id] = resource[:name]
        data[:repoType] = resource[:type]
        data[:repoPolicy] = resource[:policy].to_s
        begin
          Nexus::Rest.update("/service/local/repositories/#{resource[:name]}", {:data => data})
        rescue Exception => e
          raise Puppet::Error, "Error while updating nexus_repository #{resource[:name]}: #{e}"
        end
      end
      @property_hash = resource.to_hash
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

  mk_resource_methods

  def type=(value)
    raise Puppet::Error, WRITE_ONCE_ERROR_MESSAGE % 'type'
  end

  def provider_type=(value)
    raise Puppet::Error, WRITE_ONCE_ERROR_MESSAGE % 'provider_type'
  end

  def policy=(value)
    @property_flush[:policy] = true
  end
end