# WebFilteringDatabase

Filtering categories for domains, from Elixir. Systems that decide whether traffic is allowed, such as DNS services, proxies, parental-control backends and MSP consoles, call `classify/2` for domains their local list does not know, and receive a category from [web filtering categories for Elixir gateways](https://www.webfilteringdatabase.com) and similar enforcement points.

## Installation

```elixir
{:webfilteringdatabase, "~> 1.0"}
```

## Usage

```elixir
wf = WebFilteringDatabase.Client.new(System.fetch_env!("AQ_API_KEY"))
{:ok, body} = WebFilteringDatabase.Client.classify(wf, "freshly-registered.example")
```

The body is the service's JSON as a map. It carries the filtering category and a confidence value, and the product's API reference lists the rest. Treat a map containing `"detail"` or `"error"` as a failure even when the HTTP status was 200.

## Architecture: ETS in front, a learner behind

The BEAM makes the usual filtering design pleasant to build. Keep categories in an ETS table that every request process reads concurrently. Let a single GenServer do the slow work of classifying unknown domains:

```elixir
defmodule MyFilter.Learner do
  use GenServer
  @table :domain_categories

  def start_link(key), do: GenServer.start_link(__MODULE__, key, name: __MODULE__)
  def lookup(host) do
    case :ets.lookup(@table, host) do
      [{^host, cat}] -> cat
      [] -> GenServer.cast(__MODULE__, {:learn, host}); :unclassified
    end
  end

  @impl true
  def init(key) do
    :ets.new(@table, [:named_table, :public, read_concurrency: true])
    {:ok, %{client: WebFilteringDatabase.Client.new(key), pending: MapSet.new()}}
  end

  @impl true
  def handle_cast({:learn, host}, %{pending: p} = s) do
    if MapSet.member?(p, host) do
      {:noreply, s}
    else
      me = self()
      Task.start(fn -> send(me, {:learned, host, WebFilteringDatabase.Client.classify(s.client, host)}) end)
      {:noreply, %{s | pending: MapSet.put(p, host)}}
    end
  end

  @impl true
  def handle_info({:learned, host, {:ok, %{"web_filtering_category" => cat}}}, s) do
    :ets.insert(@table, {host, cat})
    {:noreply, %{s | pending: MapSet.delete(s.pending, host)}}
  end

  def handle_info({:learned, host, _other}, s),
    do: {:noreply, %{s | pending: MapSet.delete(s.pending, host)}}
end
```

At boot, fill the table from the licensed file. Request processes call `lookup/1`, which never blocks on the network. Unknown hosts get `:unclassified` once and a real category from then on. The `pending` set stops a burst of requests from causing duplicate classifications.

## Choosing the unclassified policy

| Where | Sensible default |
|---|---|
| Primary and secondary schools | Block until classified |
| Offices | Allow and log |
| Guest networks | Allow, except known risky categories |
| Locked-down devices | Block |

Brand-new domains are common in phishing and fraud campaigns, so a short hold costs strict networks very little.

## Per-tenant policy for MSPs

In a multi-tenant console, the domain-to-category table is shared by everyone, and the category-to-action rules belong to each tenant. Store the rules in a small Ecto schema per tenant. A new client then benefits immediately from everything the platform has learned, and nobody's rule change leaks into another tenant.

## Results and errors

- `{:ok, map}`: the service answered with a 2xx status. Check the map for an error field anyway.
- `{:error, {:api_error, status, body}}`: 401 means the key is unknown, 403 means the plan is inactive or the quota is used, 429 means slow down.
- `{:error, exception}`: a network failure.

Calls use `Req.post/2`, and Req does not retry POST by default. In the learner above, a failure simply clears the pending flag, and the next request for that host tries again. That is often all the retry logic a filter needs.

`new/2` raises `FunctionClauseError` for an empty key, and so does `classify/2` for an empty host.

## Privacy

Only the value you pass and your key are sent. When classifying full URLs, drop query strings first, since they can carry tokens or personal data and the host decides the category.

## Schools and the Children's Internet Protection Act

US schools and libraries that take E-rate funding must filter under CIPA. Adult, gambling, weapons and proxy categories map directly onto that duty. Many districts also want to handle generative AI separately, open in class and closed in exams. Load [AI chat and generation sites as a filter category](https://www.aitoolsblocklist.com) from the AI register for that decision.

## Finding out before enforcing

Resolver and proxy logs already show how people use the network. An [AI activity report from proxy logs](https://www.shadowaitools.com) is a good input before tightening policy. For topic-level context on unknown domains, [IAB labels for hosts outside your list](https://www.websitecategorizationapi.com) are available from the sibling API.

## Testing

Point `:base_url` at a stub endpoint that returns a fixed category and assert that your learner writes it to ETS:

```elixir
wf = WebFilteringDatabase.Client.new("test", base_url: "http://localhost:4040")
```

## Other languages

[webfilteringdatabase-go](https://pkg.go.dev/github.com/explainableaixai/webfilteringdatabase-go), [the Flutter client](https://pub.dev/packages/webfilteringdatabase) and [the Rust crate](https://crates.io/crates/webfilteringdatabase).

## License

MIT
