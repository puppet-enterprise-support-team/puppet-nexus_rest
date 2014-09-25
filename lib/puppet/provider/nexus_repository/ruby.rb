require 'json'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'config.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'exception.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'rest.rb'))

Puppet::Type.type(:nexus_repository).provide(:ruby) do
  desc "Uses Ruby's rest library"

  WRITE_ONCE_ERROR_MESSAGE = "%s is write-once only and cannot be changed without force."
  PROVIDER_TYPE_MAPPING = {
    'maven1'    => {
      :provider     => 'maven1',
      :providerRole => 'org.sonatype.nexus.proxy.repository.Repository',
      :format       => 'maven1',
    },
    'maven2'    => {
      :provider     => 'maven2',
      :providerRole => 'org.sonatype.nexus.proxy.repository.Repository',
      :format       => 'maven2',
    },
    'obr' => {
      :provider     => 'obr-proxy',
      :providerRole => 'org.sonatype.nexus.proxy.repository.Repository',
      :format       => 'obr',
    },
    'nuget'     => {
      :provider     => 'nuget-proxy',
      :providerRole => 'org.sonatype.nexus.proxy.repository.Repository',
      :format       => 'nuget',
    },
    'site'      => {
      :provider     => 'site',
      :providerRole => 'org.sonatype.nexus.proxy.repository.WebSiteRepository',
      :format       => 'site',
    },
  }

  def initialize(value={})
    super(value)
    @dirty_flag = false
  end

  def self.instances
    begin
      repositories = Nexus::Rest.get_all_plus_n('/service/local/repositories')
      repositories['data'].collect do |repository|

        remote_storage = repository.has_key?('remoteStorage') ? repository['remoteStorage'] : {}
        remote_authentication = remote_storage.has_key?('authentication') ? remote_storage['authentication'] : {}
        remote_connection = remote_storage.has_key?('connectionSettings') ? remote_storage['connectionSettings'] : {}

        new(
          :ensure                         => :present,
          :name                           => repository['id'],
          :label                          => repository['name'],
          :provider_type                  => repository.has_key?('format') ? repository['format'].to_sym : nil, # TODO using the format because it maps 1:1 to the provider_type
          :type                           => repository.has_key?('repoType') ? repository['repoType'].to_sym : nil,
          :policy                         => repository.has_key?('repoPolicy') ? repository['repoPolicy'].downcase.to_sym : nil,
          :exposed                        => repository.has_key?('exposed') ? repository['exposed'].to_s.to_sym : nil,
          :write_policy                   => repository.has_key?('writePolicy') ? repository['writePolicy'].downcase.to_sym : nil,
          :browseable                     => repository.has_key?('browseable') ? repository['browseable'].to_s.to_sym : nil,
          :indexable                      => repository.has_key?('indexable') ? repository['indexable'].to_s.to_sym : nil,
          :not_found_cache_ttl            => repository.has_key?('notFoundCacheTTL') ? Integer(repository['notFoundCacheTTL']) : nil,
          :local_storage_url              => repository.has_key?('overrideLocalStorageUrl') ? repository['overrideLocalStorageUrl'] : nil,
          :remote_storage                 => remote_storage.has_key?('remoteStorageUrl') ? remote_storage['remoteStorageUrl'].to_s : nil,
          :remote_auto_block              => repository.has_key?('autoBlockActive') ? repository['autoBlockActive'].to_s : nil,
          :remote_checksum_policy         => repository.has_key?('checksumPolicy') ? repository['checksumPolicy'].to_s.to_sym : nil,
          :remote_download_indexes        => repository.has_key?('downloadRemoteIndexes') ? repository['downloadRemoteIndexes'].to_s.to_sym : nil,
          :remote_file_validation         => repository.has_key?('fileTypeValidation') ? repository['fileTypeValidation'].to_s : nil,
          :remote_item_max_age            => remote_storage.has_key?('itemMaxAge') ? remote_storage['itemMaxAge'].to_s : :nil,
          :remote_artifact_max_age        => remote_storage.has_key?('artifactMaxAge') ? remote_storage['artifactMaxAge'].to_s : :nil,
          :remote_metadata_max_age        => remote_storage.has_key?('metadataMaxAge') ? remote_storage['metadataMaxAge'].to_s : :nil,
          :remote_request_timeout         => remote_connection.has_key?('connectionTimeout') ? remote_connection['connectionTimeout'].to_s : nil,
          :remote_request_retries         => remote_connection.has_key?('retrievalRetryCount') ? remote_connection['retrievalRetryCount'].to_s : nil,
          :remote_query_string            => remote_connection.has_key?('queryString') ? remote_connection['queryString'].to_s : nil,
          :remote_user_agent              => remote_connection.has_key?('userAgentString') ? remote_connection['userAgentString'].to_s : nil,
          :remote_user                    => remote_authentication.has_key?('username') ? remote_authentication['username'].to_s : :nil,
          :remote_password                => remote_authentication.has_key?('password') ? remote_authentication['password'].to_s : :nil,
          :remote_nt_lan_host             => remote_authentication.has_key?('ntlmHost') ? remote_authentication['ntlmHost'].to_s : :nil,
          :remote_nt_lan_domain           => remote_authentication.has_key?('ntlmDomain') ? remote_authentication['ntlmDomain'].to_s : :nil,
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
    begin
      Nexus::Rest.create('/service/local/repositories', map_resource_to_data)
    rescue Exception => e
      raise Puppet::Error, "Error while creating nexus_repository #{resource[:name]}: #{e}"
    end
  end

  def flush
    if @dirty_flag
      begin
        Nexus::Rest.update("/service/local/repositories/#{resource[:name]}", map_resource_to_data)
      rescue Exception => e
        raise Puppet::Error, "Error while updating nexus_repository #{resource[:name]}: #{e}"
      end
      @property_hash = resource.to_hash
    end
  end

  def destroy
    raise "The current configuration prevents the deletion of nexus_repository #{resource[:name]}; If this change is" +
      " intended, please update the configuration file (#{Nexus::Config.file_path}) in order to perform this change." \
      unless Nexus::Config.can_delete_repositories

    begin
      Nexus::Rest.destroy("/service/local/repositories/#{resource[:name]}")
    rescue Exception => e
      raise Puppet::Error, "Error while deleting nexus_repository #{resource[:name]}: #{e}"
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  # Returns the resource in a representation as expected by Nexus:
  #
  # {
  #   :data => {
  #              :id   => <resource name>
  #              :name => <resource label>
  #              ...
  #            }
  # }
  def map_resource_to_data
    content_type_details = PROVIDER_TYPE_MAPPING[resource[:provider_type].to_s] or raise Puppet::Error, "Nexus_repository[#{resource[:name]}]: unable to find a suitable mapping for type #{resource[:provider_type]}"
    data = {
      :id                      => resource[:name],
      :name                    => resource[:label],
      :repoType                => resource[:type].to_s,
      :provider                => content_type_details[:provider],
      :providerRole            => content_type_details[:providerRole],
      :format                  => content_type_details[:format],
      :repoPolicy              => resource[:policy].to_s.upcase,
      :exposed                 => resource[:exposed] == :true,

      :writePolicy             => resource[:write_policy].to_s.upcase,
      :browseable              => resource[:browseable] == :true,
      :indexable               => resource[:indexable] == :true,
      :notFoundCacheTTL        => resource[:not_found_cache_ttl],
    }
    data[:overrideLocalStorageUrl] = resource[:local_storage_url] unless resource[:local_storage_url].nil?
    {:data => data}
  end

  mk_resource_methods

  def type=(value)
    raise Puppet::Error, WRITE_ONCE_ERROR_MESSAGE % 'type'
  end

  def provider_type=(value)
    raise Puppet::Error, WRITE_ONCE_ERROR_MESSAGE % 'provider_type'
  end

  def policy=(value)
    @dirty_flag = true
  end

  def exposed=(value)
    @dirty_flag = true
  end

  def write_policy=(value)
    raise Puppet::Error, "Write policy cannot be changed." unless resource[:type] == :hosted
    @dirty_flag = true
  end

  def browseable=(value)
    @dirty_flag = true
  end

  def indexable=(value)
    @dirty_flag = true
  end

  def not_found_cache_ttl=(value)
    @dirty_flag = true
  end

  def download_remote_indexes=(value)
    @dirty_flag = true
  end

  def local_storage_url=(value)
    @dirty_flag = true
  end
end
