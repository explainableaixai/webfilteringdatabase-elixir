client = WebFilteringDatabase.Client.new(System.fetch_env!("AQ_API_KEY"))
IO.inspect(WebFilteringDatabase.Client.classify(client, "example.com"))
