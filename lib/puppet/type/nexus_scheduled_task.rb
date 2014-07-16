require 'puppet/property/boolean'
require 'puppet/property/keyvalue'
require 'puppet/property/list'

Puppet::Type.newtype(:nexus_scheduled_task) do
  @doc = 'A background task of a Nexus service.'

  ensurable

  newparam(:name, :namevar => true) do
    desc 'Name of the scheduled task. Although Nexus allows to use the same name for multiple tasks, the module will
      print a warning and ignore and subsequent task with the same name.'
  end

  newparam(:id) do
    desc 'A read-only parameter set by the nexus_scheduled_task.'
  end

  newproperty(:enabled, :parent => Puppet::Property::Boolean) do
    desc 'Enable or disable the scheduled task.'
    defaultto :true
    munge { |value| super(value).to_s.intern }
  end

  newproperty(:type) do
    desc 'The type of the task that will be scheduled to run. Can be the type name (as shown in the user interface) or
      the type id. The plugin ships a list of known type names; if a type name is not known, it is passed unmodified
      to Nexus.'
    validate do |value|
      raise ArgumentError, "Type must not be empty" if value.to_s.empty?
    end
  end

  newproperty(:task_settings) do
    desc 'Type specific settings to configure the task. It is recommended to configure the task through the user
      interface and use `puppet resource` to generate the expected value.'
    default {}
  end

  newproperty(:alert_email) do
    desc 'The email address where an email will be sent to in case that task execution failed. Set to `absent` to
      disable the email notification.'
    defaultto :absent
    validate do |value|
      raise ArgumentError, "Alert email must not be empty'." if value.to_s.empty?
      raise ArgumentError, "Alert email must be a valid email address, got '#{value}'." unless value =~ /@/ or value.intern == :absent
    end
    munge { |value| value.intern == :absent ? value.intern : value }
  end

  newproperty(:reoccurrence) do
    desc "The frequency this task will run. Can be one of: `manual`, `once`, `daily`, `weekly`, `monthly` or
      `advanced`."
    newvalues(:manual, :once, :hourly, :daily, :weekly, :monthly, :advanced)
  end

  newproperty(:cron_expression) do
    desc 'A cron expression that will control the running of the task.'
    validate do |value|
      raise ArgumentError, "Cron expression must be a non-empty string" if value.empty?
    end
  end

  newproperty(:start_date) do
    desc 'The date this task should start running, specified as `YYYY-MM-DD`. Mandatory unless `reoccurrence` is
      `manual` or `advanced`.'
    validate do |value|
      raise ArgumentError, "Start date must not be empty" if value.to_s.empty?
      raise ArgumentError, "Start date must match YYYY-MM-DD, got '#{value}'" unless value.to_s =~ /\d{4}-\d{2}-\d{2}/
    end
  end

  newproperty(:start_time) do
    desc 'The start time in `hh:mm` the task should run (according to the timezone of the service). Mandatory when
      `reoccurrence` set to `once` or `hourly`.'
    validate do |value|
      raise ArgumentError, "Start time must match the following format: <hh::mm>, got '#{value}'" unless value.to_s =~ /\d\d?:\d\d/
    end
  end

  newproperty(:recurring_time) do
    desc 'The time this task should run (according to the timezone of the service).'
    validate do |value|
      raise ArgumentError, "Recurring time must match the following format: <hh:mm>, got '#{value}'" unless value.to_s =~ /\d\d?:\d\d/
    end
  end

  newproperty(:recurring_day, :parent => Puppet::Property::List) do
    desc 'The day this task should run. Accepts a list of days. When `reoccurrence` is set to `weekly`, only days of
      the week (`monday`, `tuesday`, ...) are valid. When `reoccurrence` is set to `monthly`, only days of the month
      are valid (1, 2, 3, 4, ... 29, 30, 31 and `last`).'
    validate do |value|
      raise ArgumentError, "Reccuring day must not be empty" if value.to_s.empty?
      raise ArgumentError, "Multiple reccuring days must be provided as an array, not a comma-separated list." if value.to_s.include?(',')
    end
    munge do |value|
      munged_value = super(value)
      munged_value.is_a?(String) ? munged_value.downcase : munged_value
    end
    def membership
      :inclusive_membership
    end
  end

  validate do
    if self[:ensure] == :present
      raise ArgumentError, "Type is a mandatory property" if self[:type].nil?

      case self[:reoccurrence]
        when :manual
        when :once, :hourly
          ensure_nonempty_property_values([:start_date, :start_time])
        when :daily
          ensure_nonempty_property_values([:start_date, :recurring_time])
        when :weekly
          ensure_nonempty_property_values([:start_date, :recurring_day, :recurring_time])
          ensure_recurring_day_in(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'])
        when :monthly
          ensure_nonempty_property_values([:start_date, :recurring_day, :recurring_time])
          ensure_recurring_day_in([('1'..'31').to_a, 'last'].flatten)
        when :advanced
          ensure_nonempty_property_values([:cron_expression])
      end
    end
  end

  # Ensure all listed properties have non-empty values set.
  #
  def ensure_nonempty_property_values(properties)
    missing_fields = properties.collect { |property| property if self[property].nil? or self[property].to_s.empty? }.compact
    raise ArgumentError, "Setting reoccurrence to '#{self[:reoccurrence]}' requires #{missing_fields.join(' and ')} to be set as well" unless missing_fields.empty?
  end

  # Ensure all items of the recurring_day property are included in the given list of items.
  #
  # Note: make sure to pass an array with elements of the type string; otherwise there may be issues with the data types.
  def ensure_recurring_day_in(valid_items)
    self[:recurring_day].split(',').each do |item|
      raise ArgumentError, "Recurring day must be one of [#{valid_items.join(', ')}], got '#{item}'" unless valid_items.include?(item.to_s)
    end
  end

  newparam(:inclusive_membership) do
    desc "The list is considered a complete lists as opposed to minimum lists."
    newvalues(:inclusive)
    defaultto :inclusive
  end

  autorequire(:file) do
    Nexus::Config::file_path
  end
end
