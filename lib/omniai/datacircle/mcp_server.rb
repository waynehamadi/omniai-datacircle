# frozen_string_literal: true

module OmniAI
  module Datacircle
    # OmniAI's MCP server as MCP clients talk to it: a notification (notifications/initialized) gets no answer, a
    # request with no params (tools/list, ping) is read as one with empty params, a method it does not serve gets
    # JSON-RPC's error, and each answer leaves at once on stdio.
    class MCPServer < OmniAI::MCP::Server
      METHODS = %w[initialize ping tools/list tools/call].freeze

      # Writes each answer through, as a client on a pipe waits for it.
      class Stdio < OmniAI::MCP::Transport::Stdio
        def puts(text)
          super
          @stdout.flush
        end
      end

      def run(transport: Stdio.new)
        super
      end

      def process(message)
        data = JSON.parse(message)
        return super unless data.is_a?(Hash)
        return if data['id'].nil?
        return unknown(data) unless METHODS.include?(data['method'])

        super(JSON.generate(data.merge('params' => data['params'] || {})))
      rescue JSON::ParserError
        super
      end

      private

      def unknown(data)
        JSON.generate({ jsonrpc: '2.0', id: data['id'],
                        error: { code: -32_601, message: "method not found: #{data['method']}" } })
      end
    end
  end
end
