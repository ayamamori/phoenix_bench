defmodule PhoenixBench do

  def connect(n_client), do: connect([], n_client/100)
  def connect(clients, n_client) when n_client <= 0, do: clients
  def connect(clients, n_client) do
    :timer.sleep(100)
    connect(clients++ PhoenixBench.create_clients(100), n_client-1)
  end

  def bench do
    chat_msgpack = Msgpax.pack!(%{topic: "rooms:lobby", event: "new_msg", ref: 2, payload: %{content: "aaa"}})|> IO.iodata_to_binary() 
    n_client = 1000
    [one_client | other_client] = create_clients(n_client)
    #send one_client, {:send, chat_msgpack}

    #clients= create_clients(n_client)
    #clients |> Enum.each(&(&1 |> send({:send, chat_msgpack})))

    #main_loop

  end
  def create_clients(n_client) when n_client>=1 do
    join_msgpack = Msgpax.pack!(%{topic: "rooms:lobby", event: "phx_join", ref: 1, payload: nil})|> IO.iodata_to_binary() 

    receive_pid = spawn (fn -> receive_loop end)
    (for x <- 1..n_client, do: x)
      |> Enum.map(fn user_name -> 
            spawn (fn -> join_channel(user_name, join_msgpack, receive_pid) end)
         end)
  end

  def join_channel(user_name, join_msgpack, receive_pid) do
    start_time = :os.system_time(:milli_seconds)

    socket = Socket.Web.connect! "104.155.218.66", 4000, path: "/socket/websocket?user_name=#{user_name}"
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
      {:receive, received} -> IO.puts :os.system_time(:milli_seconds) 
    end
    receive_loop
  end

end
