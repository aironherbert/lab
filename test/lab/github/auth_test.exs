defmodule Lab.GitHub.AuthTest do
  use ExUnit.Case, async: true

  alias Lab.GitHub.Auth

  @now 1_700_000_000

  @tag :tmp_dir
  test "generates a valid GitHub App JWT", %{tmp_dir: tmp_dir} do
    private_key = JOSE.JWK.generate_key({:rsa, 2048})
    private_key_path = Path.join(tmp_dir, "github-app.pem")
    {_jwk, pem} = JOSE.JWK.to_pem(private_key)
    File.write!(private_key_path, pem)

    token = Auth.generate_jwt("github-client-id", private_key_path, @now)

    assert {true, jwt, jws} = JOSE.JWT.verify_strict(private_key, ["RS256"], token)

    assert jwt.fields == %{
             "iat" => @now - 60,
             "exp" => @now + 600,
             "iss" => "github-client-id"
           }

    assert jws.fields["typ"] == "JWT"
  end
end
