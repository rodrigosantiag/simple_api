defmodule SimpleApiWeb.HelloController do
  use SimpleApiWeb, :controller

  def index(conn, _params) do
    json(conn, %{message: "Hello DO droplet #1!!!"})
  end
end
