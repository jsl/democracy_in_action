module DemocracyInAction
  module TestMethods

    class DisabledConnectionException < Exception
    end

    def self.included(base)
      base.send :include, InstanceMethods
      base.extend ClassMethods

      base.send :alias_method, :send_request_without_disabling, :send_request
      base.send :alias_method, :send_request, :send_request_with_disabling
      base.send :alias_method, :validate_connection_without_disabling, :validate_connection
      base.send :alias_method, :validate_connection, :validate_connection_with_disabling
    end
    module InstanceMethods
      # Prevent the API from contacting the remote service.  Used for development and testing purposes.
      def disable!
        @disabled = true
      end

      # Confirm whether the API is allowed to contact the service.
      def disabled?
        @disabled || self.class.disabled?
      end
      
      def validate_connection_with_disabling
        raise DisabledConnectionException.new("Connection disabled.") if disabled?
        validate_connection_without_disabling
      end

      def send_request_with_disabling(base_url, options={})
        raise DisabledConnectionException.new('You must override send_request_and_get_response in disablded DIA connections.') if disabled?
        send_request_without_disabling(base_url, options)
      end
    end
    module ClassMethods
      @@disabled = false

      def disabled?
        @@disabled
      end

      def disable!
        @@disabled = true
      end
    end
  end
end
