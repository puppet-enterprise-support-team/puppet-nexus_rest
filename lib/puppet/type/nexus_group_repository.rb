require 'uri'
require 'puppet/property/list'

Puppet::Type.newtype(:nexus_group_repository) do
  @doc = "Manages Nexus Group Repository through a REST API"

  ensurable

  newparam(:name, :namevar => true) do
    desc 'Unique group identifier; once created cannot be changed unless the Group Repository is destroyed. The Nexus UI will show it as Group ID.'
  end

  newproperty(:label) do
    desc 'Human readable label of the Group Repository. The Nexus UI will show it as Group Name.'
  end

  newproperty(:provider_type) do
    desc 'The content provider of the Group Repository'
    defaultto :maven2
    newvalues(:maven1, :maven2, :nuget, :site, :obr)
  end

  newproperty(:exposed, :boolean => true) do
    desc 'Controls if the Group Repository is remotely accessible. Responds to the \'Publish URL\' setting in the UI.'
    defaultto :true
    munge { |value| @resource.munge_boolean(value) }
  end

  newproperty(:repositories, :parent => Puppet::Property::List) do
    desc 'A list of repositories contained in this Group Repository'
    defaultto []
    validate do |value|
      unless value.empty?
        raise ArgumentError, "repositories in group must be provided in an array" if value.include?(',')
      end
    end
    def membership
      :inclusive_membership
    end

  end

  autorequire(:file) do
    Nexus::Config::file_path
  end

  def munge_boolean(value)
    return :true if [true, "true", :true].include? value
    return :false if [false, "false", :false].include? value
    fail("Expected boolean parameter, got '#{value}'")
  end

  newparam(:inclusive_membership) do
    desc "The list is considered a complete lists as opposed to minimum lists."
    newvalues(:inclusive)
    defaultto :inclusive
  end

end
