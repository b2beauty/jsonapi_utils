module JSONAPI::Utils
  module Request
    def jsonapi_request_handling
      setup_request
      check_request
    end

    def setup_request
      @request ||= JSONAPI::RequestParser.new(
        params,
        context: context,
        key_formatter: key_formatter,
        server_error_callbacks: (self.class.server_error_callbacks || [])
      )
    end

    def check_request
      @request.errors.blank? || jsonapi_render_errors(json: @request)
    end

    # Overrides the JSONAPI::ActsAsResourceController#process_request method.
    #
    # It might be removed when the following line on JR is fixed:
    # https://github.com/cerebris/jsonapi-resources/blob/release-0-8/lib/jsonapi/acts_as_resource_controller.rb#L62
    #
    # @return [String]
    #
    # @api public
    def process_request
      process_operations
      render_results(@operation_results)
    rescue => e
      handle_exceptions(e)
    end

    def resource_params
      build_params_for(:resource)
    end

    def relationship_params
      build_params_for(:relationship)
    end

    private

    def build_params_for(param_type)
      return {} if @request.operations.empty?

      keys      = %i(attributes to_one to_many)
      operation = @request.operations.find { |e| e.options[:data].keys & keys == keys }
      if operation.nil?
        {}
      elsif param_type == :relationship
        operation.options[:data].values_at(:to_one, :to_many).compact.reduce(&:merge)
      else
        operation.options[:data][:attributes]
      end
    end
  end
end
