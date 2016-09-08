defmodule PhoenixBench do

  @room "rooms:bench"
  @login_msgpack Msgpax.pack!(%{Event: "login", Ref: 1}) |> IO.iodata_to_binary() 
  @join_msgpack Msgpax.pack!(%{Event: "join", Topic: @room, Ref: 1}) |> IO.iodata_to_binary() 
  @leave_msgpack Msgpax.pack!(%{Event: "leave", Topic: @room, Ref: 3}) |> IO.iodata_to_binary()
  @say_msgpack Msgpax.pack!(%{Event: "say", Topic: @room, Ref: 2, Content: "aaa"}) |>IO.iodata_to_binary()
  @members_msgpack Msgpax.pack!(%{Event: "members", Topic: @room, Ref: 2}) |>IO.iodata_to_binary()
  @history_msgpack Msgpax.pack!(%{Event: "history", Topic: @room, Ref: 2, Limit: 20}) |>IO.iodata_to_binary()
  @history_dm_msgpack Msgpax.pack!(%{Event: "history:dm", Topic: @room, Ref: 2, Limit: 20}) |>IO.iodata_to_binary()
  @rooms_joined_msgpack Msgpax.pack!(%{Event: "rooms:joined", Ref: 3}) |>IO.iodata_to_binary()
  @rooms_subscr_msgpack Msgpax.pack!(%{Event: "rooms:subscr", Ref: 3}) |>IO.iodata_to_binary()
  @subscr_msgpack Msgpax.pack!(%{Event: "subscr", Ref: 3, Room: @room}) |>IO.iodata_to_binary()
  @unsubscr_msgpack Msgpax.pack!(%{Event: "unsubscr", Ref: 3, Room: @room}) |>IO.iodata_to_binary()


  def bench(host, n_clients, start_id \\ 0) do
     {mega, seconds, us} = :os.timestamp()  
     begin = (mega*1000000 + seconds)*1000000 + us
     clients=create_clients_seq(host, n_clients, start_id)
     #clients=create_clients(host, n_clients)
     {mega, seconds, us} = :os.timestamp()  
     IO.inspect (mega*1000000 + seconds)*1000000 + us - begin
     #clients |> login
     #{mega, seconds, us} = :os.timestamp()  
     #IO.inspect (mega*1000000 + seconds)*1000000 + us - begin
     #clients |> join
     #{mega, seconds, us} = :os.timestamp()  
     #IO.inspect (mega*1000000 + seconds)*1000000 + us - begin
     clients
  end
  
  def create_clients(host, n_clients, start_id \\ 0) do
    start_id..(n_clients+start_id-1)
      |> Enum.map(fn i -> Task.async(fn ->
          create_client(i, host)
        end)end)
      |> Enum.map(&Task.await/1)
      |> IO.inspect
  end
  def create_clients_seq(host, n_clients, start_id \\ 1) do
    for i <- start_id..(n_clients+start_id) do
      client = Socket.Web.connect! host, 4000, path: "/socket/websocket?user_id=#{inspect i}&user_name=#{inspect i}"
      #spawn_link fn -> recv_loop(client, self) end
      client
    end
  end

  defp create_client(i, host) do
    case Socket.Web.connect! host, 4000, path: "/socket/websocket?user_id=#{inspect i}&user_name=#{inspect i}" do
      nil -> 
      IO.inspect "nil!"
      create_client(i, host)
      client -> client
    end
  end

  def login(clients) do
    push(clients, @login_msgpack)
  end
  def join(clients) do
    push(clients, @join_msgpack)
  end
  def leave(clients) do
    push(clients, @leave_msgpack)
  end
  def say(clients) do
    push(clients, @say_msgpack)
  end
  def members(clients) do
    push(clients, @members_msgpack)
  end
  def history(clients) do
    push(clients, @history_msgpack)
  end
  def history_dm(clients) do
    push(clients, @history_dm_msgpack)
  end
  def rooms_joined(clients) do
    push(clients, @rooms_joined_msgpack)
  end
  def rooms_subscr(clients) do
    push(clients, @rooms_subscr_msgpack)
  end
  def subscr(clients) do
    push(clients, @subscr_msgpack)
  end
  def unsubscr(clients) do
    push(clients, @unsubscr_msgpack)
  end

  def push(clients, msgpack) do
    Enum.each clients, &(&1 |> Socket.Web.send!({:binary, msgpack}))
    clients
  end

  def recv_loop(socket, receive_pid) do
    received = socket 
      |> Socket.Web.recv! 
      |> elem(1) 
      |> Msgpax.unpack! 
    send receive_pid, {:receive, received}
    #IO.inspect received
    recv_loop(socket, receive_pid)
  end

end
