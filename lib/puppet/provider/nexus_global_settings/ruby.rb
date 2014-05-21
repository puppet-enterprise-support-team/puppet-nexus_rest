require 'json'
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'config.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'exception.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'nexus', 'rest.rb'))

Puppet::Type.type(:nexus_global_settings).provide(:ruby) do
  desc "Nexus settings management based on Ruby."

  def initialize(value={}, dirty_flag = false)
    super(value)
    @dirty_flag = dirty_flag
  end

  def self.instances
    begin
      [ map_data_to_resource('current', Nexus::Rest.get_all('/service/local/global_settings/current')) ]
    rescue => e
      raise Puppet::Error, "Error while retrieving settings: #{e}"
    end
  end

  def self.prefetch(resources)
    settings = instances
    settings.keys.each do |name|
      if provider = settings.find { |setting| setting.name == name }
        resources[name].provider = provider
      end
    end
  end

  def flush
    if @dirty_flag
      begin
        Nexus::Rest.update("/service/local/global_settings/#{resource[:name]}", map_resource_to_data)
      rescue Exception => e
        raise Puppet::Error, "Error while updating nexus_global_settings #{resource[:name]}: #{e}"
      end
      @property_hash = resource.to_hash
    end
  end

  def self.map_data_to_resource(name, settings)
    data = settings['data']
    notification_settings = data['systemNotificationSettings']
    new(
      :name                 => name,
      :notification_enabled => notification_settings ? notification_settings['enabled'].to_s.to_sym : :absent,
      :notification_emails  => notification_settings ? notification_settings['emailAddresses'] : :absent,
      :notification_groups  => notification_settings ? notification_settings['roles'].join(',') : :absent
    )
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
    {
      :data => {
        :systemNotificationSettings => {
          :enabled        => resource[:notification_enabled],
          :emailAddresses => resource[:notification_emails] ? resource[:notification_emails].join(',') : '',
          :roles          => resource[:notification_groups] ? resource[:notification_groups] : []
        }
      }
    }
  end

  mk_resource_methods

  def notification_enabled=(value)
    mark_dirty
  end

  def mark_dirty
    @dirty_flag = true
  end
end
