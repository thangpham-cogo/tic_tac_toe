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
