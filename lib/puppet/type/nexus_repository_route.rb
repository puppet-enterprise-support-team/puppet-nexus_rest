require 'uri'
require 'puppet/property/boolean'

Puppet::Type.newtype(:nexus_repository_route) do
  @doc = "Manages Nexus Repository Routes through a REST API"
  @@nexus_all_group_repositories_marker = '*'

  ensurable

  newparam(:id) do
    desc 'Read only value used to manage the resource, do not specify this in the manifest.'
  end

  newparam(:position, :namevar => true) do
    desc 'The position of the route configuration in the list of route configurations. These should be unique integers beginning from 0 and incrementing by steps of 1.'
    munge { |value| "#{Integer(value)}" }
  end

  newproperty(:url_pattern) do
    desc 'Regular expression used to match the artifact path.'
    defaultto ''
  end

  newproperty(:rule_type) do
    desc 'Regular expression used to match the artifact path.'
    defaultto :inclusive
    newvalues(:inclusive, :exclusive, :blocking)
  end

  newproperty(:repository_group) do
    desc 'The id of Repository Group that the route will be applied to'
    defaultto ''
  end

  newproperty(:repositories, :array_matching => :all) do
    desc 'Ordered list list of repositories and repository_groups that should be considered when the pattern is matched for a query in '
    defaultto []
    validate do |value|
      unless value.empty?
        raise ArgumentError, "repositories in route must be provided in an array" if value.include?(',')
      end
    end
  end

  autorequire(:file) do
    Nexus::Config::file_path
  end

  autorequire(:nexus_repository_group) do
    self[:repository_group] if self[:repository_group] != @@nexus_all_group_repositories_marker
    self[:repositories] if self[:repositories] and self[:repositories].size() > 0
  end

  autorequire(:nexus_repository) do
    self[:repositories] if self[:repositories] and self[:repositories].size() > 0
  end

  validate do
    if self[:ensure] == :present
      raise ArgumentError, "route position must be non-negative integer" if Integer(self[:position]) < 0
      raise ArgumentError, "route url_pattern must not be empty" if self[:url_pattern].empty?
      raise ArgumentError, "route repository_group must not be empty" if self[:repository_group].empty?
      raise ArgumentError, "route repositories list must not be empty" if self[:repositories].empty?
    end
  end

end
