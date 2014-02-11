defmodule ExplexWeb.Router.API do
  use Plug.Router
  import Plug.Connection
  import ExplexWeb.Router.Util
  import ExplexWeb.Util.Plugs
  alias ExplexWeb.User
  alias ExplexWeb.Package
  alias ExplexWeb.Release
  alias ExplexWeb.RegistryBuilder


  plug Plug.Parsers, parsers: [ExplexWeb.Util.JsonDecoder]
  plug :accept, vendor: "explex", allow: [{"application","json"}, "json", "elixir"]
  plug :match
  plug :dispatch

  get "user/:name" do
    if user = User.get(name) do
      body =
        user.__entity__(:keywords)
        |> Dict.take([:username, :email, :created])
      body = body.update_created(&to_iso8601/1)
      send_render(conn, body)
    else
      send_resp(conn, 404, "")
    end
  end

  post "user" do
    User.create(conn.params["username"], conn.params["email"], conn.params["password"])
    |> send_creation_resp(conn)
  end

  put "package/:name" do
    with_authorized user do
      if package = Package.get(name) do
        package.meta(conn.params["meta"])
        |> Package.update
        |> send_update_resp(conn)
      else
        Package.create(name, user, conn.params["meta"])
        |> send_creation_resp(conn)
      end
    end
  end

  post "package/:name/release" do
    with_authorized do
      if package = Package.get(name) do
        result =
          Release.create(package, conn.params["version"], conn.params["git_url"],
                         conn.params["git_ref"], conn.params["requirements"])
          |> send_creation_resp(conn)

        RegistryBuilder.rebuild
        result
      else
        send_resp(conn, 404, "")
      end
    end
  end

  match _ do
    send_resp(conn, 404, "")
  end
end
