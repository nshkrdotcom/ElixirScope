#!/usr/bin/env elixir

# Test HTTPoison connectivity to Gemini API
Mix.install([{:httpoison, "~> 2.0"}, {:jason, "~> 1.4"}])

api_key = System.get_env("GEMINI_API_KEY")

if api_key do
  url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{api_key}"
  headers = [{"Content-Type", "application/json"}]
  body = Jason.encode!(%{
    contents: [%{parts: [%{text: "Hello, test message"}]}],
    generationConfig: %{temperature: 0.3, maxOutputTokens: 100}
  })
  
  redacted_url = String.replace(url, ~r/key=[^&]+/, "key=***REDACTED***")
  IO.puts("Making request to: #{redacted_url}")
  IO.puts("Body size: #{byte_size(body)} bytes")
  
  case HTTPoison.post(url, body, headers, timeout: 30_000, recv_timeout: 30_000) do
    {:ok, response} ->
      IO.puts("✅ Success: HTTP #{response.status_code}")
      IO.puts("Response body: #{String.slice(response.body, 0, 200)}...")
      
    {:error, error} ->
      IO.puts("❌ HTTPoison Error: #{inspect(error)}")
      
      case error.reason do
        :nxdomain ->
          IO.puts("DNS resolution failed - this suggests a network connectivity issue")
        :timeout ->
          IO.puts("Request timeout - API might be slow or unreachable")
        :econnrefused ->
          IO.puts("Connection refused - API endpoint might be down")
        _ ->
          IO.puts("Other network error: #{inspect(error.reason)}")
      end
  end
else
  IO.puts("❌ No GEMINI_API_KEY environment variable found")
  IO.puts("Please set it with: export GEMINI_API_KEY='your-api-key'")
end 