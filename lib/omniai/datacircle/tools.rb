# frozen_string_literal: true

module OmniAI
  module Datacircle
    # A tool of Datacircle's open API: its name is datacircle_ and its class's, like datacircle_best_plans.
    class Tool < OmniAI::Tool
      def self.namify
        "datacircle_#{name.split('::').last.gsub(/(?<=[a-z])(?=[A-Z])/, '_').downcase}"
      end

      # text: true answers JSON text, as an MCP server sends it, in place of a Hash.
      def initialize(text: false, **)
        super(**)
        @text = text
      end

      # The tool's answer to the model's arguments, as OmniAI's chat and MCP server call it: the call's Hash (its JSON
      # with text: true), or the API's error as {"error" => ...}, never raised. Arguments it does not take are dropped,
      # a number sent as text is read, one out of range is brought into it.
      def call(args = {})
        given = args.is_a?(Hash) ? args.to_h { |key, value| [key.to_s, value] } : {}
        kept = self.class.parameters.properties.keys.each_with_object({}) do |key, kept|
          kept[key.to_sym] = given[key.to_s] unless given[key.to_s].nil?
        end
        found = begin
          @function.call(**kept)
        rescue Error => e
          { 'error' => e.message }
        end
        @text ? JSON.generate(found) : found
      end

      # The tool as the provider sends it. A strict tool (OmniAI's OpenAI provider sends strict: true) takes only an
      # object whose every key is required: each key the tool can do without is sent as a null, which #call drops.
      def serialize(context: nil)
        serialized = super
        strict = serialized[:strict] ? serialized : serialized[:function]
        return serialized unless strict.is_a?(Hash) && strict[:strict] && strict[:parameters].is_a?(Hash)

        strict[:parameters] = every_key_required(strict[:parameters])
        serialized
      end

      private

      def every_key_required(schema)
        required = Array(schema[:required]).map(&:to_s)
        properties = schema[:properties].to_h do |key, property|
          next [key, property] if required.include?(key.to_s)

          nullable = property.merge(type: ['null', *property[:type]].uniq)
          nullable[:enum] = [*property[:enum], nil].uniq if property[:enum]
          [key, nullable]
        end
        schema.merge(properties: properties, required: properties.keys)
      end

      def calls
        Calls.new(base_url: Datacircle.base_url)
      end
    end

    # GET /apis
    class ListApis < Tool
      description "Lists the GTM APIs on Datacircle's sheet (https://datacircle.dev), with each API's slug, how many plans " \
                  "and providers it has and its best plan. Call it first to find an API's slug."
      parameter :query, :string, description: "Words of the API's name or slug, like email or linkedin profile: the APIs " \
                                              "that hold the most of them come first. The sheet's order when left out."
      parameter :limit, :integer, description: 'How many APIs to give, 1 to 200. 20 when left out: the sheet has about 150.'

      def execute(query: nil, limit: nil)
        calls.list_apis(query: query, limit: limit)
      end
    end

    # GET /apis/{slug}/best
    class BestPlans < Tool
      description "Gives an API's plans best first by their score out of 100 on Datacircle's benchmark " \
                  '(https://datacircle.dev), each with its rank, provider, plan, $ per 1,000 calls and its page. ' \
                  "#{PRICE}"
      parameter :slug, :string, description: "The API's slug, like email-finder or linkedin-profile, as " \
                                             'datacircle_list_apis gives it.'
      parameter :limit, :integer, description: 'How many plans to give, 1 to 50. 10 when left out.'
      required %i[slug]

      def execute(slug: nil, limit: nil)
        calls.best_plans(slug: slug, limit: limit)
      end
    end

    # GET /plans
    class SearchPlans < Tool
      description "Searches every plan on Datacircle's sheet (https://datacircle.dev), or one API's, by provider or plan " \
                  'name, sorted by score, provider or price. Gives how many were found and up to limit of them. ' \
                  "#{PRICE}"
      parameter :query, :string, description: "Words that must all appear in the provider's or plan's name, like bright data."
      parameter :api, :string, description: "Only this API's plans: its name or slug, like email-finder. A provider's " \
                                            'name goes in query, never here. Every API when left out.'
      parameter :sort, :string, enum: %w[score provider price],
                                description: 'score (best first, the default), provider (A to Z) or price ($ per 1,000, ' \
                                             'lowest first).'
      parameter :limit, :integer, description: 'How many plans to give, 1 to 50. 10 when left out.'
      parameter :offset, :integer, description: 'How many found plans to skip first. 0 when left out.'

      def execute(query: nil, api: nil, sort: nil, limit: nil, offset: nil)
        calls.search_plans(query: query, api: api, sort: sort, limit: limit, offset: offset)
      end
    end

    # GET /providers/{slug}
    class Provider < Tool
      description "Gives each API one provider sells and its rank on each on Datacircle's benchmark " \
                  '(https://datacircle.dev), with its best plan there, its best rank first. total is how many APIs it ' \
                  'sells, ranked on how many of them it has a rank.'
      parameter :slug, :string, description: "The provider's slug, like bright-data, or its name, like Bright Data: the " \
                                             'name is made a slug.'
      required %i[slug]

      def execute(slug: nil)
        calls.provider(slug: slug)
      end
    end
  end
end
