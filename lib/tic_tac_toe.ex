defmodule TTT.Client do
  def start(server_pid, port) do
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    loop_acceptor(server_pid, socket)
  end

  def loop_acceptor(server_pid, socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    spawn(fn -> register(server_pid, client) end)
    loop_acceptor(server_pid, socket)
  end

  def register(server_pid, socket) do
    send(server_pid, {self(), :register})

    puts("Waiting for other player...", socket)

    receive do
      {:your_turn, board} -> play(server_pid, board, socket)
      {:error, :game_full} -> puts("Game is full :(", socket)
    end

    :gen_tcp.close(socket)
  end

  defp play(server_pid, board, socket) do
    print_board(board, socket)

    position = ask_for_position(socket)
    send(server_pid, {self(), {:play, position - 1}})

    receive do
      {:error, error} ->
        print_error(error, socket)
        play(server_pid, board, socket)

      {:accepted, board} ->
        print_board(board, socket)

        puts("Waiting for other player...", socket)

        receive do
          {:your_turn, board} ->
            play(server_pid, board, socket)

          {:game_complete, board} ->
            print_board(board, socket)
            puts("Game complete!", socket)
        end
    end
  end

  defp ask_for_position(socket) do
    gets("Play at position (1-9): ", socket)
    |> String.trim()
    |> Integer.parse()
    |> case do
      {number, ""} ->
        number

      _ ->
        puts("Not a valid number", socket)
        ask_for_position(socket)
    end
  end

  defp print_error(error, socket) do
    case error do
      :not_your_turn -> "Weird, it wasn't my turn."
      :invalid_position -> "That's not a valid position."
      :cell_not_empty -> "That cell is not empty."
      error -> "Error '#{error}' occurred."
    end
    |> puts(socket)
  end

  defp print_board(board, socket) do
    board
    |> Enum.map(fn
      nil -> " "
      0 -> "X"
      1 -> "O"
    end)
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join(&1, " | "))
    |> Enum.intersperse("---------")
    |> Enum.join("\n")
    |> then(&"\n#{&1}\n")
    |> puts(socket)
  end

  defp gets(prompt, socket) do
    print(prompt, socket)
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp puts(line, socket) do
    print("#{line}\n", socket)
  end

  defp print(line, socket) do
    :gen_tcp.send(socket, line)
  end
end

defmodule TTT.Server do
  @initial_state {
    List.duplicate(nil, 9),
    nil,
    nil
  }

  @win_patterns [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6]
  ]

  @valid_positions 0..8

  def start do
    spawn(fn -> loop() end)
  end

  defp loop(state \\ @initial_state) do
    IO.inspect(state)

    new_state =
      receive do
        {caller, {:play, position}} when position not in @valid_positions ->
          send(caller, {:error, :invalid_position})
          state

        {caller, {:play, position}} ->
          {board, p1, p2} = state

          case Enum.at(board, position) do
            nil ->
              cond do
                caller == p1 ->
                  new_board = List.replace_at(board, position, 0)

                  if game_ends?(new_board) do
                    send(p1, {:accepted, new_board})
                    send(p1, {:game_complete, new_board})
                    send(p2, {:game_complete, new_board})
                  else
                    send(p1, {:accepted, new_board})
                    send(p2, {:your_turn, new_board})
                    {new_board, p1, p2}
                  end

                caller == p2 ->
                  new_board = List.replace_at(board, position, 1)

                  if game_ends?(new_board) do
                    send(p2, {:accepted, new_board})
                    send(p1, {:game_complete, new_board})
                    send(p2, {:game_complete, new_board})
                  else
                    send(p2, {:accepted, new_board})
                    send(p1, {:your_turn, new_board})
                    {new_board, p1, p2}
                  end
              end

            _ ->
              send(caller, {:error, :cell_not_empty})
              state
          end

        {caller, :register} ->
          case state do
            {board, nil, nil} ->
              {board, caller, nil}

            {board, p1, nil} ->
              send(p1, {:your_turn, board})
              {board, p1, caller}

            _ ->
              send(caller, {:error, :game_full})
              state
          end
      end

    loop(new_state)
  end

  defp game_ends?(board) do
    @win_patterns
    |> List.flatten()
    |> Enum.map(&Enum.at(board, &1))
    |> Enum.chunk_every(3)
    |> Enum.any?(fn line ->
      case line do
        [0, 0, 0] -> true
        [1, 1, 1] -> true
        _ -> false
      end
    end)
  end
end

defmodule TicTacToe do
  def run do
    server_pid = TTT.Server.start()
    TTT.Client.start(server_pid, 6000)
  end
end
