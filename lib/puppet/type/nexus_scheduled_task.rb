require 'puppet/property/boolean'
require 'puppet/property/keyvalue'
require 'puppet/property/list'

Puppet::Type.newtype(:nexus_scheduled_task) do
  @doc = 'A background task of a Nexus service.'

  @@known_task_types = {
    'Optimize Repository Index' => 'OptimizeIndexTask',
  }

  ensurable

  newparam(:name, :namevar => true) do
    desc 'Name of the scheduled task. Although Nexus allows to use the same name for multiple tasks it is discouraged and likely to fail.'
  end

  newproperty(:enabled, :parent => Puppet::Property::Boolean) do
    desc 'Enable or disable the scheduled task.'
    defaultto :true
    munge { |value| super(value).to_s.intern }
  end

  newproperty(:type_id) do
    desc 'The machine readable type of the service that will be scheduled to run.'
    validate do |value|
      raise ArgumentError, "Type id must not be empty" if value.nil? or value.empty?
    end
  end

  newproperty(:task_settings, :parent => Puppet::Property::KeyValue) do
    desc 'Type specific settings to configure the task.'
    validate do |value|
      raise ArgumentError, "Task settings contains restricted character: = (got #{value})" unless value.values.select { |item| item.include?('=') }.empty?
    end
    def membership
      :inclusive_membership
    end
  end

  newproperty(:alert_email) do
    desc 'The email address where an email will be sent in case that task execution will fail.'
    defaultto ''
    validate do |value|
      raise ArgumentError, "Alert email must be a valid email address, got '#{value}'." unless value.empty? or value =~ /@/
    end
  end

  newproperty(:reoccurrence) do
    desc "The frequency this task will run. Can be one of: `manual`, `once`, `daily`, `weekly`, `monthly` or
      `advanced`. Specifying any value beside `manual` or `advanced` requires the `start_date` to be set. If `advanced`
      is selected, the `cron_expression` property is required."
    newvalues(:manual, :once, :daily, :weekly, :monthly, :advanced)
  end

  newproperty(:cron_expression) do
    desc 'A cron expression that will control the running of the task.'
    defaultto ''
  end

  newproperty(:start_date) do
    desc 'The start date in millis seconds this task should start running. Mandatory unless `reoccurrence` is `manual` or `advanced`.'
    validate do |value|
      unless value.nil?
        raise ArgumentError, "Start date must be a non-negative integer, got '#{value}'" unless value.to_s =~ /\d+/
        raise ArgumentError, "Start date must be bigger than zero, got #{value}" unless value.to_i > 0
      end
    end
    munge { |value| Integer(value) }
  end

  newproperty(:recurring_time) do
    desc 'The time this task should run.'
    validate do |value|
      raise ArgumentError, "Recurring time must match the following format: <hh:mm>, got '#{value}'" unless value.to_s =~ /\d\d?:\d\d?/
    end
  end

  newproperty(:recurring_day, :parent => Puppet::Property::List) do
    desc 'The day this task should run.'
    validate do |value|
      raise ArgumentError, "Reccuring day must not be empty" if value.empty?
    end
    def membership
      :inclusive_membership
    end
  end

  validate do
    reoccurrence = self[:reoccurrence]
    start_date_nil_or_empty = (self[:start_date].nil? or self[:start_date].to_s.empty?)
    cron_expression_nil_or_empty = (self[:cron_expression].nil? or self[:cron_expression].to_s.empty?)
    fail("Setting reoccurrence to '#{reoccurrence}' requires start_date to be set as well") if reoccurrence != :manual and reoccurrence != :advanced and start_date_nil_or_empty
    fail("Setting reoccurrence to 'advanced' requires cron_expression to be set as well") if reoccurrence == :advanced and cron_expression_nil_or_empty
  end

  newparam(:inclusive_membership) do
    desc "The list is considered a complete lists as opposed to minimum lists."
    newvalues(:inclusive)
    defaultto :inclusive
  end
end
