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
     clients_pids=create_clients(host, n_clients)
  end
  
  def create_clients(host, n_clients, start_id \\ 0) do
    start_id..(n_clients+start_id-1)
      |> Enum.map(fn i -> 
          Process.sleep(1)
          IO.inspect self
          spawn_link(fn -> create_client(i, host) end)
        end)
      |> IO.inspect
  end

  defp create_client(i, host) do
    client = Socket.Web.connect! host, 4000, path: "/socket/websocket?user_id=#{inspect i}&user_name=#{inspect i}"
    receive_loop(client)
  end

  def receive_loop(clients_pids) do
    receive do
      :login -> push_login(clients_pids)
      :join -> push_join(clients_pids)
      :leave -> push_leave(clients_pids)
      :say -> push_say(clients_pids)
      :members -> push_members(clients_pids)
      :history -> push_history(clients_pids)
      :history_dm -> push_history_dm(clients_pids)
      :rooms_joined -> push_rooms_joined(clients_pids)
      :rooms_subscr -> push_rooms_subscr(clients_pids)
      :subscr -> push_subscr(clients_pids)
      :unsubscr -> push_unsubscr(clients_pids)
    end
    receive_loop(clients_pids)
  end

  def login(client_pids) do
    send_client_op(client_pids, :login)
  end
  def join(client_pids) do
    send_client_op(client_pids, :join)
  end
  def leave(client_pids) do
    send_client_op(client_pids, :leave)
  end
  def say(client_pids) do
    send_client_op(client_pids, :say)
  end
  def members(client_pids) do
    send_client_op(client_pids, :members)
  end
  def history(client_pids) do
    send_client_op(client_pids, :history)
  end
  def history_dm(client_pids) do
    send_client_op(client_pids, :history_dm)
  end
  def rooms_joined(client_pids) do
    send_client_op(client_pids, :rooms_joined)
  end
  def rooms_subscr(client_pids) do
    send_client_op(client_pids, :rooms_subscr)
  end
  def subscr(client_pids) do
    send_client_op(client_pids, :subscr)
  end
  def unsubscr(client_pids) do
    send_client_op(client_pids, :unsubscr)
  end

  defp send_client_op(client_pids, op) do
    client_pids |> Enum.each(fn pid -> send pid, op end)
  end


  def push_login(client) do
    push(client, @login_msgpack)
  end
  def push_join(client) do
    push(client, @join_msgpack)
  end
  def push_leave(client) do
    push(client, @leave_msgpack)
  end
  def push_say(client) do
    push(client, @say_msgpack)
  end
  def push_members(client) do
    push(client, @members_msgpack)
  end
  def push_history(client) do
    push(client, @history_msgpack)
  end
  def push_history_dm(client) do
    push(client, @history_dm_msgpack)
  end
  def push_rooms_joined(client) do
    push(client, @rooms_joined_msgpack)
  end
  def push_rooms_subscr(client) do
    push(client, @rooms_subscr_msgpack)
  end
  def push_subscr(client) do
    push(client, @subscr_msgpack)
  end
  def push_unsubscr(client) do
    push(client, @unsubscr_msgpack)
  end

  def push(client, msgpack) do
    client |> Socket.Web.send!({:binary, msgpack})
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
