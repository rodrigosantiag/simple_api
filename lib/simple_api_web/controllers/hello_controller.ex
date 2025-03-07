defmodule SimpleApiWeb.HelloController do
  use SimpleApiWeb, :controller

  def index(conn, _params) do
    json(conn, %{message: "Hello DO droplet #{get_ip()}!!!"})
  end

  def display_name(conn, _params) do
    json(conn, %{message: "Display name method from #{get_ip()}!!!"})
  end

  defp get_ip do
    case :inet.getifaddrs() do
      {:ok, ifs} ->
        ifs
        |> Enum.find_value(fn {_ifname, opts} ->
          case Keyword.get(opts, :addr) do
            {127, 0, 0, 1} -> nil
            {_, _, _, _} = ip -> to_string(:inet_parse.ntoa(ip))
            _ -> nil
          end
        end) || "Unknown IP"

      {:error, reason} ->
        "Error: #{inspect(reason)}"
    end
  end
end
