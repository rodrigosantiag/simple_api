defmodule SimpleApiWeb.HelloController do
  use SimpleApiWeb, :controller

  def index(conn, _params) do
    json(conn, %{message: "Hello DO droplet #{SimpleApiWeb.Endpoint.url()}!!!"})
  end
end
