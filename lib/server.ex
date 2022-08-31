defmodule TTT.Server do
  @initial_state {
    List.duplicate(nil, 9),
    [nil, nil],
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

  alias TTT.Logic

  def start do
    spawn(fn -> loop() end)
  end

  defp loop(state \\ @initial_state) do
    receive do
      {caller, {:play, position}} ->
        handle_play(caller, position, state)

      {caller, :register} ->
        handle_register(caller, state)
    end
    |> IO.inspect()
    |> loop()
  end

  defp handle_register(caller, {board, [nil, nil], nil}), do: {board, [caller, nil], nil}

  defp handle_register(caller, {board, [p1, nil], nil}) do
    send(p1, {:your_turn, board})
    {board, [p1, caller], p1}
  end

  defp handle_register(caller, state) do
    send(caller, {:error, :game_full})
    state
  end

  defp handle_play(caller, position, {board, [p1, p2], caller} = state) do
    with {:ok, current, next, symbol} <- validate_player(caller, p1, p2),
         {:ok, new_board} <- Logic.update_board(board, position, symbol) do
      send(current, {:accepted, new_board})

      if Logic.board_full?(new_board) || Logic.has_winner?(new_board, @win_patterns) do
        notify_and_reset_game([p1, p2], new_board)
      else
        send(next, {:your_turn, new_board})
        {new_board, [p1, p2], next}
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

  defp notify_and_reset_game(players, board) do
    IO.puts("game done")
    Enum.each(players, &send(&1, {:game_complete, board}))

    @initial_state
  end
end
