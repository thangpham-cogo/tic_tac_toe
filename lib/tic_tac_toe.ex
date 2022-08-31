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
    # p1
    nil,
    # p2
    nil,
    # current
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

  @p1_symbol 0
  @p2_symbol 1

  def start do
    spawn(fn -> loop() end)
  end

  defp loop(state \\ @initial_state) do
    IO.inspect(state)

    receive do
      {caller, {:play, position}} ->
        handle_play(caller, position, state)

      {caller, :register} ->
        handle_register(caller, state)
    end
    |> loop()
  end

  defp handle_register(caller, {board, nil, nil, nil}), do: {board, caller, nil, nil}

  defp handle_register(caller, {board, p1, nil, nil}) do
    send(p1, {:your_turn, board})
    {board, p1, caller, p1}
  end

  defp handle_register(caller, state) do
    send(caller, {:error, :game_full})
    state
  end

  defp handle_play(caller, position, {board, p1, p2, caller} = state) do
    with {:ok, current, next, symbol} <- validate_player(caller, p1, p2),
         {:ok, new_board} <- update_board(board, position, symbol) do
      send(current, {:accepted, new_board})

      if game_ends?(new_board) do
        notify_and_reset_game([p1, p2], new_board)
      else
        send(next, {:your_turn, new_board})
        {new_board, p1, p2, next}
      end
    else
      {:error, error} ->
        send(caller, {:error, error})
        state
    end
  end

  defp handle_play(caller, _, state) do
    send(caller, {:error, :not_your_turn})
    state
  end

  defp validate_player(caller, caller, p2), do: {:ok, caller, p2, @p1_symbol}
  defp validate_player(caller, p1, caller), do: {:ok, caller, p1, @p2_symbol}
  # crash the game
  defp validate_player(_caller, _p1, _p2), do: {:error, :unknown_current_player}

  defp update_board(_, position, _) when position < 0, do: {:error, :invalid_position}

  defp update_board(board, position, symbol) do
    case Enum.fetch(board, position) do
      {:ok, nil} ->
        new_board = List.replace_at(board, position, symbol)
        {:ok, new_board}

      {:ok, _} ->
        {:error, :cell_not_empty}

      _ ->
        {:error, :invalid_position}
    end
  end

  defp notify_and_reset_game(players, board) do
    Enum.each(players, &send(&1, {:game_complete, board}))

    @initial_state
  end

  defp game_ends?(board) do
    has_winner?(board) || board_full?(board)
  end

  defp has_winner?(board) do
    @win_patterns
    |> List.flatten()
    |> Enum.map(&Enum.at(board, &1))
    |> Enum.chunk_every(3)
    |> Enum.any?(fn line ->
      case line do
        [@p1_symbol, @p1_symbol, @p1_symbol] -> true
        [@p2_symbol, @p2_symbol, @p2_symbol] -> true
        _ -> false
      end
    end)
  end

  defp board_full?(board) do
    Enum.all?(board, &(not is_nil(&1)))
  end
end

defmodule TicTacToe do
  def run do
    server_pid = TTT.Server.start()
    TTT.Client.start(server_pid, 6000)
  end
end
