defmodule SimpleApiWeb.HelloController do
  use SimpleApiWeb, :controller

  def index(conn, _params) do
    json(conn, %{message: "Hello DO droplet #{get_ip(conn)}!!!"})
  end

  defp get_ip(conn) do
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))

    if forwarded_for do
      String.split(forwarded_for, ",")
      |> Enum.map(&String.trim/1)
      |> List.first()
    else
      to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end
end
