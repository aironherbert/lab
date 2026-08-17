defmodule Lab.GitHub.Auth do
  @moduledoc """
  Generates short-lived JWTs used to authenticate the GitHub App.

  The GitHub App client ID and PEM private-key path are read from
  `GITHUB_APP_CLIENT_ID` and `GITHUB_APP_PRIVATE_KEY_PATH`.
  """

  @algorithm "RS256"
  @token_lifetime_seconds 600
  @clock_skew_seconds 60

  @spec generate_jwt() :: binary()
  def generate_jwt do
    client_id = System.fetch_env!("GITHUB_APP_CLIENT_ID")
    private_key_path = System.fetch_env!("GITHUB_APP_PRIVATE_KEY_PATH")

    generate_jwt(client_id, private_key_path)
  end

  @doc false
  @spec generate_jwt(binary(), Path.t(), integer()) :: binary()
  def generate_jwt(client_id, private_key_path, now \\ System.system_time(:second)) do
    private_key =
      private_key_path
      |> File.read!()
      |> JOSE.JWK.from_pem()

    payload = %{
      "iat" => now - @clock_skew_seconds,
      "exp" => now + @token_lifetime_seconds,
      "iss" => client_id
    }

    private_key
    |> JOSE.JWT.sign(%{"alg" => @algorithm, "typ" => "JWT"}, payload)
    |> JOSE.JWS.compact()
    |> elem(1)
  end
end
