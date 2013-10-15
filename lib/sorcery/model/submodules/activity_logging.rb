require 'dm-types'
module Sorcery
  module Model
    module Submodules
      # This submodule keeps track of events such as login, logout, and last activity time, per user.
      # It helps in estimating which users are active now in the site.
      # This cannot be determined absolutely because a user might be reading a page without clicking anything 
      # for a while.
      # This is the model part of the submodule, which provides configuration options.
      module ActivityLogging
        def self.included(base)
          base.extend(ClassMethods)

          base.sorcery_config.class_eval do
            attr_accessor :last_login_at_attribute_name,                  # last login attribute name.
                          :last_logout_at_attribute_name,                 # last logout attribute name.
                          :last_activity_at_attribute_name,               # last activity attribute name.
                          :last_login_from_ip_address_name,               # last activity login source
                          :activity_timeout                               # how long since last activity is 
                                                                          #the user defined logged out?
          end
          
          base.sorcery_config.instance_eval do
            @defaults.merge!(:@last_login_at_attribute_name                => :last_login_at,
                             :@last_logout_at_attribute_name               => :last_logout_at,
                             :@last_activity_at_attribute_name             => :last_activity_at,
                             :@last_login_from_ip_address_name             => :last_login_from_ip_address,
                             :@activity_timeout                            => 10 * 60)
            reset!
          end

          base.sorcery_config.after_config << :define_activity_logging_mongoid_fields if defined?(Mongoid) and base.ancestors.include?(Mongoid::Document)
          if defined?(DataMapper) and base.ancestors.include?(DataMapper::Resource)
            # NOTE raise exception if data-store is not supported
            unless base.repository.adapter.is_a?(DataMapper::Adapters::MysqlAdapter)
              raise 'Unsupported DataMapper Adapter'
            end
            base.sorcery_config.after_config << :define_activity_logging_datamapper_fields
          end
        end
        
        module ClassMethods
          # get all users with last_activity within timeout
          def current_users
            config = sorcery_config
            get_current_users
          end

          protected

          def define_activity_logging_mongoid_fields
            field sorcery_config.last_login_at_attribute_name,    :type => Time
            field sorcery_config.last_logout_at_attribute_name,   :type => Time
            field sorcery_config.last_activity_at_attribute_name, :type => Time
            field sorcery_config.last_login_from_ip_address_name, :type => String
          end

          def define_activity_logging_datamapper_fields
            property sorcery_config.last_login_at_attribute_name,    Time
            property sorcery_config.last_logout_at_attribute_name,   Time
            property sorcery_config.last_activity_at_attribute_name, Time
            property sorcery_config.last_login_from_ip_address_name, String
            # Workaround local timezone retrieval problem NOTE dm-core issue #193
            [sorcery_config.last_login_at_attribute_name,
             sorcery_config.last_logout_at_attribute_name,
             sorcery_config.last_activity_at_attribute_name].each do |sym|
               alias_method "orig_#{sym}", sym
               define_method(sym) do
                 t = send("orig_#{sym}")
                 t && Time.new(t.year, t.month, t.day, t.hour, t.min, t.sec, 0)
               end
             end
          end
        end
      end
    end
  end
end
