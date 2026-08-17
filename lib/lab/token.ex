defmodule Lab.Token do
  @moduledoc """
  Generates signed JSON Web Tokens.

  Tokens use HMAC SHA-256 and expire after one hour by default.
  """

  @algorithm "HS256"
  @default_ttl 3_600

  @spec generate(map(), binary(), keyword()) :: {:ok, binary()} | {:error, :invalid_secret}
  def generate(claims, secret, opts \\ []) when is_map(claims) and is_binary(secret) do
    if byte_size(secret) >= 32 do
      issued_at = Keyword.get_lazy(opts, :issued_at, fn -> System.system_time(:second) end)
      ttl = Keyword.get(opts, :ttl, @default_ttl)

      claims =
        claims
        |> stringify_keys()
        |> Map.put_new("iat", issued_at)
        |> Map.put_new("exp", issued_at + ttl)

      {_jws, token} =
        secret
        |> JOSE.JWK.from_oct()
        |> JOSE.JWT.sign(%{"alg" => @algorithm, "typ" => "JWT"}, claims)
        |> JOSE.JWS.compact()

      {:ok, token}
    else
      {:error, :invalid_secret}
    end
  end

  defp stringify_keys(claims) do
    Map.new(claims, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end
end
