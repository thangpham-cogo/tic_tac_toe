defmodule TTT.Server do
  use GenServer

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

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @impl true
  def init(_) do
    {:ok, @initial_state}
  end

  def register(pid \\ __MODULE__, player_pid) do
    GenServer.call(pid, {:register, player_pid})
  end

  def play(pid \\ __MODULE__, position) do
    GenServer.call(pid, {:play, position})
  end

  @impl true
  def handle_call({:register, player_pid}, _from, {board, [nil, nil], nil}) do
    next_state = {board, [player_pid, nil], nil}
    {:reply, next_state, next_state}
  end

  @impl true
  def handle_call({:register, player_pid}, _from, {board, [p1, nil], nil}) do
    send(p1, {:your_turn, board})
    next_state = {board, [p1, player_pid], p1}
    {:reply, next_state, next_state}
  end

  @impl true
  def handle_call({:register, _}, _from, state) do
    {:reply, {:error, :game_full}, state}
  end

  @impl true
  def handle_call({:play, position}, {caller, _}, {board, [p1, p2], caller} = state) do
    next_state =
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

    {:reply, next_state, next_state}
  end

  @impl true
  def handle_call({:play, _}, _, state) do
    {:reply, {:error, :not_your_turn}, state}
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
