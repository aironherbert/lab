defmodule Lab.TokenTest do
  use ExUnit.Case, async: true

  alias Lab.Token

  @secret "a-strong-secret-with-at-least-32-bytes"

  test "generates a signed JWT with temporal claims" do
    assert {:ok, token} =
             Token.generate(%{sub: "user-123", role: "admin"}, @secret,
               issued_at: 1_700_000_000,
               ttl: 900
             )

    assert {true, jwt, _jws} =
             JOSE.JWT.verify_strict(JOSE.JWK.from_oct(@secret), ["HS256"], token)

    assert jwt.fields == %{
             "sub" => "user-123",
             "role" => "admin",
             "iat" => 1_700_000_000,
             "exp" => 1_700_000_900
           }
  end

  test "preserves explicitly supplied temporal claims" do
    assert {:ok, token} =
             Token.generate(%{"iat" => 10, "exp" => 20}, @secret, issued_at: 30)

    assert {true, jwt, _jws} =
             JOSE.JWT.verify_strict(JOSE.JWK.from_oct(@secret), ["HS256"], token)

    assert jwt.fields["iat"] == 10
    assert jwt.fields["exp"] == 20
  end

  test "rejects secrets shorter than 256 bits" do
    assert {:error, :invalid_secret} = Token.generate(%{sub: "user-123"}, "short")
  end
end
