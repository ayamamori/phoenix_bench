defmodule PhoenixBench do

  @room "rooms:bench"
  @login [%{Event: "login", Ref: 1}] 
  @join [%{Event: "join", Topic: @room, Ref: 1}] 
  @leave [%{Event: "leave", Topic: @room, Ref: 3}]
  @say [%{Event: "say", Topic: @room, Ref: 2, Content: "aaa"}]
  @members [%{Event: "members", Topic: @room, Ref: 2}]
  @history [%{Event: "history", Topic: @room, Ref: 2, Limit: "20"}]
  @history_dm [%{Event: "history:dm", Topic: @room, Ref: 2, Limit: "20"}]
  @rooms_joined [%{Event: "rooms:joined", Ref: 3}]
  @rooms_subscr [%{Event: "rooms:subscr", Ref: 3}]
  @rooms_all [%{Event: "rooms:all", Ref: 3}]
  @subscr [%{Event: "subscr", Ref: 3, Room: @room}]
  @unsubscr [%{Event: "unsubscr", Ref: 3, Room: @room}]


  def bench(host, n_clients, start_id \\ 0) do
     clients_pids=create_clients(host, n_clients, start_id)
  end
  
  def create_clients(host, n_clients, start_id \\ 0) do
    start_id..(n_clients+start_id-1)
      |> Enum.map(fn i -> 
          if rem(i,100)==0, do: IO.puts i
          spawn_link(fn -> create_client(i, host) end)
        end)
  end

  defp create_client(i, host) do
    start = DateTime.utc_now 
    client = Socket.Web.connect! host, 4000, path: "/socket/websocket?user_id=#{inspect i}&user_name=#{inspect i}"
    finish = DateTime.utc_now 
    api_time = (finish |> DateTime.to_unix(:milliseconds)) - (start |> DateTime.to_unix(:milliseconds))
    IO.puts "#{api_time |> Integer.to_string} [ms]"
    receive_loop(i, client)
  end

  def receive_loop(user_id, client) do
    receive do
      :login -> push_login(user_id, client)
      :join -> push_join(user_id, client)
      :leave -> push_leave(user_id, client)
      :say -> push_say(user_id, client)
      :members -> push_members(user_id, client)
      :history -> push_history(user_id, client)
      :history_dm -> push_history_dm(user_id, client)
      :rooms_joined -> push_rooms_joined(user_id, client)
      :rooms_subscr -> push_rooms_subscr(user_id, client)
      :rooms_all -> push_rooms_all(user_id, client)
      :subscr -> push_subscr(user_id, client)
      :unsubscr -> push_unsubscr(user_id, client)
    end
    receive_loop(user_id, client)
  end

  def login(client_pid) do
    send_client_op(client_pid, :login)
  end
  def join(client_pid) do
    send_client_op(client_pid, :join)
  end
  def leave(client_pid) do
    send_client_op(client_pid, :leave)
  end
  def say(client_pid) do
    send_client_op(client_pid, :say)
  end
  def members(client_pid) do
    send_client_op(client_pid, :members)
  end
  def history(client_pid) do
    send_client_op(client_pid, :history)
  end
  def history_dm(client_pid) do
    send_client_op(client_pid, :history_dm)
  end
  def rooms_joined(client_pid) do
    send_client_op(client_pid, :rooms_joined)
  end
  def rooms_subscr(client_pid) do
    send_client_op(client_pid, :rooms_subscr)
  end
  def rooms_all(client_pid) do
    send_client_op(client_pid, :rooms_all)
  end
  def subscr(client_pid) do
    send_client_op(client_pid, :subscr)
  end
  def unsubscr(client_pid) do
    send_client_op(client_pid, :unsubscr)
  end

  defp send_client_op(client_pids, op) do
    client_pids |> Enum.each(fn pid -> send pid, op end)
  end


  def push_login(user_id, client) do
    push(client, @login, user_id)
  end
  def push_join(user_id, client) do
    push_topic(client, @join, user_id)
  end
  def push_leave(user_id, client) do
    push_topic(client, @leave, user_id)
  end
  def push_say(user_id, client) do
    push_topic(client, @say, user_id)
  end
  def push_members(user_id, client) do
    push_topic(client, @members, user_id)
  end
  def push_history(user_id, client) do
    push_topic(client, @history, user_id)
  end
  def push_history_dm(user_id, client) do
    push_topic(client, @history_dm, user_id)
  end
  def push_rooms_joined(user_id, client) do
    push_topic(client, @rooms_joined, user_id)
  end
  def push_rooms_subscr(user_id, client) do
    push(client, @rooms_subscr, user_id)
  end
  def push_rooms_all(user_id, client) do
    push(client, @rooms_all, user_id)
  end
  def push_subscr(user_id, client) do
    push(client, @subscr, user_id)
  end
  def push_unsubscr(user_id, client) do
    push(client, @unsubscr, user_id)
  end

  def push_topic(client, param, user_id) do
    param = [param |> List.first |> Map.put(:Topic, @room<>Integer.to_string(div(user_id,20)))]
    push(client, param, user_id)
  end
  def push(client, param, user_id) do
    start = DateTime.utc_now 
    client |> Socket.Web.send!({:binary, param |> Msgpax.pack!(iodata: false)})
    wait_recv(client, param |> List.first |> Map.get(:Event), user_id)
    finish = DateTime.utc_now 
    api_time = (finish |> DateTime.to_unix(:milliseconds)) - (start |> DateTime.to_unix(:milliseconds))

    IO.puts "#{api_time |> Integer.to_string} [ms]"
  end
  def wait_recv(socket, event, user_id) do
    received = socket 
      |> Socket.Web.recv! 
      |> elem(1) 
      |> Msgpax.unpack! 
      |> List.first
    case received["Event"] do
      ^event -> :ok
      "push:say"-> 
        if event == "say" and received["UserId"] == user_id do :ok else wait_recv(socket, event, user_id) end
      "phx_close"-> if event == "leave" do :ok else wait_recv(socket, event, user_id) end
      _ -> wait_recv(socket, event, user_id)
    end
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
