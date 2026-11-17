# Datacircle tools for OmniAI

Find the best GTM APIs. We benchmark all the GTM APIs and we put the results on our website: https://datacircle.dev

This gem gives [OmniAI](https://github.com/ksylvest/omniai) four tools that call Datacircle's API at https://api.datacircle.dev/v1. You need no key and no account to call the API.

| Tool | What the tool gives | Call |
| --- | --- | --- |
| `datacircle_list_apis` | Every GTM API on Datacircle, with the API's slug, number of plans, number of providers and best plan | `GET /apis` |
| `datacircle_best_plans` | One API's plans, sorted by score out of 100, best first. Each plan comes with a rank and a price per 1,000 calls | `GET /apis/{slug}/best` |
| `datacircle_search_plans` | Plans that match a provider or plan name. Search all APIs or one API. Sort by score, provider or price | `GET /plans` |
| `datacircle_provider` | The APIs a provider sells, and the provider's rank on each API | `GET /providers/{slug}` |

## Install

```bash
bundle add omniai-datacircle
```

The gem needs OmniAI 2.8.4 or later, and Ruby 3.2 or later. Add your provider's OmniAI gem too, like `omniai-openai`.

## Use the tools in a chat

```ruby
require "omniai/openai"
require "omniai/datacircle"

client = OmniAI::OpenAI::Client.new
response = client.chat("Which email finder API is best for under $5 per 1,000?", tools: OmniAI::Datacircle.tools)
puts response.text
```

OmniAI runs each tool call from the model. OmniAI then sends the tool's answer back to the model and returns the model's text. Every OmniAI provider works the same way, like `OmniAI::Anthropic::Client.new` or `OmniAI::Google::Client.new`. To offer fewer tools, pass a shorter list, like `tools: [OmniAI::Datacircle::BestPlans.new]`.

You can call a tool yourself:

```ruby
OmniAI::Datacircle::BestPlans.new.call({ "slug" => "email-finder", "limit" => 3 })
# => {"api" => "Employee email", "slug" => "email-finder", ..., "plans" => [{"api" => "Employee email", "rank" => 1, "provider" => "Emelia", ...}]}
```

Each tool returns a Hash. OmniAI sends the Hash to the model as JSON. Each plan comes with a rank, provider, plan, score, price per 1,000 (`perThousand`, in dollars) and a page on datacircle.dev. The plan's page lists every field of the plan. For an unknown slug or any other API error, the tool returns `{"error" => ...}` with the API's error message. The model reads the error and can call the tool again. A tool never raises an exception for an API error. Your chat keeps running.

OmniAI sends tools to OpenAI in strict mode, and strict mode requires every key. For OpenAI the gem marks the optional keys as nullable. The model then sends null for an unused key.

## Serve the tools to an MCP client

**mcp.rb**

```ruby
require "omniai/datacircle"

OmniAI::Datacircle.mcp_server.run
```

`ruby mcp.rb` serves the four tools on stdio. Each tool answers in JSON text. Set your MCP client to start mcp.rb with the command `ruby` and the argument `/path/to/mcp.rb`.

The server is OmniAI's MCP server. We made three changes for MCP clients. The server sends no answer to a notification. A request with no params works. The server flushes each answer to stdout.

## Network

Each tool call makes one HTTPS GET request to https://api.datacircle.dev/v1. A tool makes a second request when the model sends a name in place of a slug. A tool also makes a second request when the model sends a provider in place of an API. A request holds the tool's own arguments and nothing else: no key and nothing from your config or messages. The API takes up to 60 calls a minute from one IP address. A tool waits once, for a minute at most, when the API replies with a wait. The gem depends only on OmniAI. The gem stores nothing.

## Links

- Datacircle: https://datacircle.dev
- The API: https://datacircle.dev/api
- The API's spec: https://api.datacircle.dev/v1/openapi.json
- The meaning of each key: https://datacircle.dev/fields

MIT license.
