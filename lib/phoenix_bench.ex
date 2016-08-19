defmodule PhoenixBench do

  def connect_with_wait(coef, unit, host_name) do
    connect(coef, unit, host_name)
    loop
  end
  def loop, do: loop

  def connect(coef, unit, host_name), do: connect([], coef, unit, host_name)
  def connect(clients, coef, _, _) when coef <= 0, do: clients
  def connect(clients, coef, unit, host_name) do
    :timer.sleep(100)
    connect(clients ++ PhoenixBench.create_clients(unit, host_name), coef-1, unit)
  end

  def bench do
    chat_msgpack = Msgpax.pack!(%{
        Event: "msg:new", 
        Topic: "rooms:lobby", 
        Ref: 2, 
        Content: "aaa",
      })|> IO.iodata_to_binary() 
    n_client = 1
    host_name = "104.199.139.193"
    #host_name = "localhost"
    #[one_client | other_client] = create_clients(n_client, host_name)
    #send one_client, {:send, chat_msgpack}

    clients= create_clients(n_client, host_name)
    clients |> Enum.each(&(&1 |> send({:send, chat_msgpack})))

    receive_loop

  end

  @doc """
    Create clients with random (sequencial number) user_id
  """
  def create_clients(n_client, host_name, channel \\ "rooms:lobby") when n_client>=1 do
    receive_pid = spawn (fn -> receive_loop end)
    (for x <- 1..n_client, do: x)
      |> Enum.map(fn user_id -> 
            create_client(user_id, host_name, channel, receive_pid)
         end)
  end

  def create_client(user_id, host_name, channel \\ "rooms:lobby") when is_binary(channel) do
    create_client(user_id, host_name, channel, (spawn (fn -> receive_loop end)))
  end
  defp create_client(user_id, host_name, channel, receive_pid) do
    join_msgpack = Msgpax.pack!(%{
        Event: "phx_join", 
        Topic: "#{channel}", 
        Ref: 1, 
      })|> IO.iodata_to_binary() 
    spawn (fn -> join_channel(host_name, user_id, join_msgpack, receive_pid) end)
  end

  def join_channel(host_name, user_id, join_msgpack, receive_pid) do

    socket = Socket.Web.connect! host_name, 4000, path: "/socket/websocket?user_id=#{user_id}&user_name=aaa"
    socket |> (Socket.Web.send! {:binary, join_msgpack})
    socket |> Socket.Web.recv! |> elem(1) |> Msgpax.unpack! 

    spawn fn -> recv_loop(socket, receive_pid) end
    send_loop(socket)
  end

  def send_loop(socket) do
    receive do
      {:send, msgpack} -> 
        socket |> (Socket.Web.send! {:binary, msgpack})
    end
    send_loop(socket)
  end

  def recv_loop(socket, receive_pid) do
    received = socket 
      |> Socket.Web.recv! 
      |> elem(1) 
      |> Msgpax.unpack! 
    send receive_pid, {:receive, received}
    recv_loop(socket, receive_pid)
  end

  def receive_loop do
    receive do
      {:receive, received} -> IO.inspect received
    end
    receive_loop
  end

end
