# frozen_string_literal: true

require 'json'
require 'omniai'
require_relative 'datacircle/version'
require_relative 'datacircle/client'
require_relative 'datacircle/calls'
require_relative 'datacircle/tools'
require_relative 'datacircle/mcp_server'

module OmniAI
  # Datacircle's open API as four OmniAI tools, with no key: find the best GTM APIs. We benchmark all the GTM APIs and
  # we put the results on our website, https://datacircle.dev
  #
  #   client.chat("Which email finder API is best?", tools: OmniAI::Datacircle.tools)
  #
  # datacircle_list_apis, datacircle_best_plans, datacircle_search_plans and datacircle_provider make one GET of
  # https://api.datacircle.dev/v1 each. Each answers a Hash; the API's error, or why it could not be reached, is
  # answered as {"error" => ...} for the model to read and call again, never raised.
  module Datacircle
    TOOLS = [ListApis, BestPlans, SearchPlans, Provider].freeze

    class << self
      # Where the tools call, https://api.datacircle.dev/v1 unless set.
      attr_writer :base_url

      def base_url
        @base_url || Client::BASE
      end

      # The four tools, for client.chat(tools: ...). text: true answers JSON text in place of a Hash.
      def tools(text: false)
        TOOLS.map { |tool| tool.new(text: text) }
      end

      # An OmniAI MCP server of the four tools, each answering JSON text: OmniAI::Datacircle.mcp_server.run serves
      # them on stdio to an MCP client.
      def mcp_server(**options)
        MCPServer.new(tools: tools(text: true), name: 'datacircle', version: VERSION, **options)
      end
    end
  end
end
