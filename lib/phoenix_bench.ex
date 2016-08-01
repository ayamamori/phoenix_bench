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
    chat_msgpack = Msgpax.pack!(%{topic: "rooms:lobby", event: "new_msg", ref: 2, payload: %{content: "aaa"}})|> IO.iodata_to_binary() 
    n_client = 1000
    host_name = ""
    [one_client | other_client] = create_clients(n_client, host_name)
    #send one_client, {:send, chat_msgpack}

    #clients= create_clients(host_name, n_client)
    #clients |> Enum.each(&(&1 |> send({:send, chat_msgpack})))

    #main_loop

  end
  @doc
  """
    Create clients with random (sequencial number) user_name
  """
  def create_clients(n_client, host_name, channel \\ "rooms:lobby") when n_client>=1 do
    receive_pid = spawn (fn -> receive_loop end)
    (for x <- 1..n_client, do: x)
      |> Enum.map(fn user_name -> 
            create_client(user_name, host_name, channel, receive_pid)
         end)
  end

  def create_client(user_name, host_name, channel \\ "rooms:lobby") when is_binary(channel) do
    create_client(user_name, host_name, channel, (spawn (fn -> receive_loop end)))
  end
  defp create_client(user_name, host_name, channel, receive_pid) do
    join_msgpack = Msgpax.pack!(%{topic: "#{channel}", event: "phx_join", ref: 1, payload: nil})|> IO.iodata_to_binary() 
    spawn (fn -> join_channel(host_name, user_name, join_msgpack, receive_pid) end)
  end

  def join_channel(host_name, user_name, join_msgpack, receive_pid) do
    start_time = :os.system_time(:milli_seconds)

    socket = Socket.Web.connect! host_name, 4000, path: "/socket/websocket?user_name=#{user_name}"
    socket |> (Socket.Web.send! {:binary, join_msgpack})
    socket |> Socket.Web.recv! |> elem(1) |> Msgpax.unpack! 

    end_time = :os.system_time(:milli_seconds)
    IO.puts "Handshake time: #{(end_time - start_time)}[ms]"
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
      {:receive, received} -> :nop #IO.inspect received
    end
    receive_loop
  end

end
