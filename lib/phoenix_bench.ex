defmodule PhoenixBench do

  @room "rooms:bench"
  @login %{Event: "login", Ref: 1} 
  @join %{Event: "join", Topic: @room, Ref: 1} 
  @leave %{Event: "leave", Topic: @room, Ref: 3}
  @say %{Event: "say", Topic: @room, Ref: 2, Content: "aaa"}
  @members %{Event: "members", Topic: @room, Ref: 2}
  @history %{Event: "history", Topic: @room, Ref: 2, Limit: 20}
  @history_dm %{Event: "history:dm", Topic: @room, Ref: 2, Limit: 20}
  @rooms_joined %{Event: "rooms:joined", Ref: 3}
  @rooms_subscr %{Event: "rooms:subscr", Ref: 3}
  @subscr %{Event: "subscr", Ref: 3, Room: @room}
  @unsubscr %{Event: "unsubscr", Ref: 3, Room: @room}


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
    client = Socket.Web.connect! host, 4000, path: "/socket/websocket?user_id=#{inspect i}&user_name=#{inspect i}"
    receive_loop(i, client)
  end

  def receive_loop(i, client) do
    receive do
      :login -> push_login(i, client)
      :join -> push_join(i, client)
      :leave -> push_leave(i, client)
      :say -> push_say(i, client)
      :members -> push_members(i, client)
      :history -> push_history(i, client)
      :history_dm -> push_history_dm(i, client)
      :rooms_joined -> push_rooms_joined(i, client)
      :rooms_subscr -> push_rooms_subscr(i, client)
      :subscr -> push_subscr(i, client)
      :unsubscr -> push_unsubscr(i, client)
    end
    receive_loop(i, client)
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
  def subscr(client_pid) do
    send_client_op(client_pid, :subscr)
  end
  def unsubscr(client_pid) do
    send_client_op(client_pid, :unsubscr)
  end

  defp send_client_op(client_pids, op) do
    client_pids |> Enum.each(fn pid -> send pid, op end)
  end


  def push_login(i, client) do
    push(client, @login)
  end
  def push_join(i, client) do
    push_topic(client, @join, i)
  end
  def push_leave(i, client) do
    push_topic(client, @leave, i)
  end
  def push_say(i, client) do
    push_topic(client, @say, i)
  end
  def push_members(i, client) do
    push_topic(client, @members, i)
  end
  def push_history(i, client) do
    push_topic(client, @history, i)
  end
  def push_history_dm(i, client) do
    push_topic(client, @history_dm, i)
  end
  def push_rooms_joined(i, client) do
    push_topic(client, @rooms_joined, i)
  end
  def push_rooms_subscr(i, client) do
    push(client, @rooms_subscr)
  end
  def push_subscr(i, client) do
    push(client, @subscr)
  end
  def push_unsubscr(i, client) do
    push(client, @unsubscr)
  end

  def push_topic(client, param, user_id) do
    param = param |> Map.put(:Topic, @room<>Integer.to_string(user_id))
    push(client, param)
  end
  def push(client, param) do
    start = DateTime.utc_now 
    client |> Socket.Web.send!({:binary, param |> Msgpax.pack!(iodata: false)})
    wait_recv(client, param[:Event])
    finish = DateTime.utc_now 
    api_time = (finish |> DateTime.to_unix(:milliseconds)) - (start |> DateTime.to_unix(:milliseconds))

    IO.puts "#{api_time |> Integer.to_string} [ms]"
  end
  def wait_recv(socket, event) do
    received = socket 
      |> Socket.Web.recv! 
      |> elem(1) 
      |> Msgpax.unpack! 
    case received["Event"] do
      ^event -> :ok
      "push:"<>^event -> :ok
      _ -> wait_recv(socket, event)
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
