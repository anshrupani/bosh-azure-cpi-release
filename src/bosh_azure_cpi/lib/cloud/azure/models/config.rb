# frozen_string_literal: true

module Bosh::AzureCloud
  # TODO: Refactoring: Move class to new file: LoadBalancerConfig
  class LoadBalancerConfig
    attr_reader :name, :resource_group_name, :backend_pool_name

    def initialize(resource_group_name, name, backend_pool_name = nil)
      @resource_group_name = resource_group_name
      @name = name
      @backend_pool_name = backend_pool_name
    end

    def to_s
      "name: #{@name}, resource_group_name: #{@resource_group_name}, backend_pool_name: #{@backend_pool_name}"
    end
  end

  # TODO: Refactoring: Move class to new file: ApplicationGatewayConfig
  class ApplicationGatewayConfig
    attr_reader :name, :resource_group_name, :backend_pool_name

    def initialize(resource_group_name, name, backend_pool_name = nil)
      @resource_group_name = resource_group_name
      @name = name
      @backend_pool_name = backend_pool_name
    end

    def to_s
      "name: #{@name}, resource_group_name: #{@resource_group_name}, backend_pool_name: #{@backend_pool_name}"
    end
  end

  # TODO: Refactoring: Move class to new file: AvailabilitySetConfig
  class AvailabilitySetConfig
    attr_reader :name
    attr_reader :platform_update_domain_count, :platform_fault_domain_count

    def initialize(name, platform_update_domain_count, platform_fault_domain_count)
      @name = name
      @platform_update_domain_count = platform_update_domain_count
      @platform_fault_domain_count = platform_fault_domain_count
    end

    def to_s
      "name: #{@name}, platform_update_domain_count: #{@platform_update_domain_count} platform_fault_domain_count: #{@platform_fault_domain_count}"
    end
  end

  # TODO: Refactoring: Move class to new file: AzureStackConfig
  class AzureStackConfig
    attr_accessor :authentication
    attr_reader :domain, :resource, :endpoint_prefix

    def initialize(azure_stack_config_hash)
      @domain = azure_stack_config_hash['domain']
      @authentication = azure_stack_config_hash['authentication']
      @resource = azure_stack_config_hash['resource']
      @endpoint_prefix = azure_stack_config_hash['endpoint_prefix']
    end
  end

  # TODO: Refactoring: Move class to new file: AzureConfig
  class AzureConfig
    include Helpers

    attr_reader :environment, :subscription_id, :location, :resource_group_name
    attr_reader :azure_stack
    attr_reader :credentials_source, :tenant_id, :client_id, :client_secret, :default_managed_identity, :managed_identity_resource_id
    attr_accessor :storage_account_name
    attr_reader :use_managed_disks
    attr_reader :default_security_group
    attr_reader :enable_vm_boot_diagnostics, :is_debug_mode, :keep_failed_vms
    attr_reader :enable_telemetry, :isv_tracking_guid
    attr_reader :pip_idle_timeout_in_minutes
    attr_reader :parallel_upload_thread_num
    attr_reader :ssh_user, :ssh_public_key
    attr_reader :stemcell_api_version
    attr_reader :use_default_account_for_cleaning
    attr_reader :compute_gallery_name
    attr_reader :compute_gallery_replicas

    def initialize(azure_config_hash)
      @environment = azure_config_hash['environment']
      @environment == ENVIRONMENT_AZURESTACK && !azure_config_hash['azure_stack'].nil? && @azure_stack = AzureStackConfig.new(azure_config_hash['azure_stack'])
      @subscription_id = azure_config_hash['subscription_id']
      @location = azure_config_hash['location']
      @resource_group_name = azure_config_hash['resource_group_name']

      # Identity
      @credentials_source = azure_config_hash['credentials_source']
      @tenant_id = azure_config_hash['tenant_id']
      @client_id = azure_config_hash['client_id']
      @client_secret = azure_config_hash['client_secret']
      @default_managed_identity = Bosh::AzureCloud::ManagedIdentity.new(azure_config_hash['default_managed_identity']) unless azure_config_hash['default_managed_identity'].nil?
      @managed_identity_resource_id = azure_config_hash['managed_identity_resource_id']

      @use_managed_disks = azure_config_hash['use_managed_disks']
      @storage_account_name = azure_config_hash['storage_account_name']

      @default_security_group = Bosh::AzureCloud::SecurityGroup.parse_security_group(
        azure_config_hash['default_security_group']
      )

      # Troubleshooting
      @enable_vm_boot_diagnostics = azure_config_hash['enable_vm_boot_diagnostics']
      @is_debug_mode = false
      @is_debug_mode = azure_config_hash['debug_mode'] unless azure_config_hash['debug_mode'].nil?
      @keep_failed_vms = azure_config_hash['keep_failed_vms']

      # Telemetry
      @enable_telemetry = azure_config_hash.fetch('enable_telemetry', false)
      @isv_tracking_guid = azure_config_hash.fetch('isv_tracking_guid', DEFAULT_ISV_TRACKING_GUID)

      @pip_idle_timeout_in_minutes = azure_config_hash.fetch('pip_idle_timeout_in_minutes', 4)

      @parallel_upload_thread_num = 16
      @parallel_upload_thread_num = azure_config_hash['parallel_upload_thread_num'].to_i unless azure_config_hash['parallel_upload_thread_num'].nil?

      @ssh_user = azure_config_hash['ssh_user']
      @ssh_public_key = azure_config_hash['ssh_public_key']

      # Flag to skip looping all storage account in subscription
      @use_default_account_for_cleaning = false
      @use_default_account_for_cleaning = azure_config_hash['use_default_account_for_cleaning'] unless azure_config_hash['use_default_account_for_cleaning'].nil?

      # A compatible director sends vm.stemcell.api_version in the cpi method call context
      # https://github.com/cloudfoundry/bosh/blob/v268.5.0/src/bosh-director/lib/cloud/external_cpi.rb#L86
      @stemcell_api_version = azure_config_hash.key?('vm') ? azure_config_hash['vm']['stemcell']['api_version'] : 2
      raise "Stemcell must support api version 2 or higher" if @stemcell_api_version < 2

      @compute_gallery_name = azure_config_hash['compute_gallery_name']
      # Azure suggests 1:20 ratio for replicas to vms, but at least 3 replicas are recommended for productions images
      @compute_gallery_replicas = azure_config_hash.fetch('compute_gallery_replicas', 3)
    end

    def managed_identity_enabled?
      @credentials_source == CREDENTIALS_SOURCE_MANAGED_IDENTITY
    end
  end

  # TODO: Refactoring: Move class to new file: AgentConfig
  class AgentConfig
    def initialize(agent_config_hash)
      @config = agent_config_hash
    end

    def to_h
      @config
    end
  end

  class Config
    attr_reader :azure, :agent

    def initialize(config_hash)
      @config = config_hash
      @azure = AzureConfig.new(config_hash['azure'] || {})
      @agent = AgentConfig.new(config_hash['agent'] || {})
    end
  end
end
