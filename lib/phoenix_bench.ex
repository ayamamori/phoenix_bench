defmodule PhoenixBench do

  def bench do
    join = Msgpax.pack!(%{topic: "rooms:lobby", event: "phx_join", ref: 1, payload: nil})|> IO.iodata_to_binary() 
    n_client = 1000
    spawn_clients(join,n_client)
  end
  def spawn_clients(join_msgpack,n_client) when n_client>=1 do
    spawn fn -> 
      start_time = :os.system_time(:milli_seconds)
      socket = Socket.Web.connect! "", 4000, path: "/socket/websocket?user_name=#{n_client}"
      end_time = :os.system_time(:milli_seconds)
      socket |> (Socket.Web.send! {:binary, join_msgpack})
      socket |> Socket.Web.recv! |> elem(1) |> Msgpax.unpack! 
      IO.puts (end_time - start_time)

    end
    
    spawn_clients(join_msgpack,n_client-1)
  end
  def spawn_clients(join_msgpack,n_client) when n_client<1 do
    spawn_clients(join_msgpack,0)
  end
end
