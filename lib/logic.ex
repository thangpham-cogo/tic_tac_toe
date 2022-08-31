defmodule TTT.Logic do
  def has_winner?(board, win_patterns) do
    win_patterns
    |> List.flatten()
    |> Enum.map(&Enum.at(board, &1))
    |> Enum.chunk_every(3)
    |> Enum.any?(fn line ->
      case line do
        [nil, nil, nil] -> false
        [val, val, val] -> true
        _ -> false
      end
    end)
  end

  def board_full?(board) do
    Enum.all?(board, &(not is_nil(&1)))
  end

  def update_board(_, position, _) when position < 0, do: {:error, :invalid_position}

  def update_board(board, position, symbol) do
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
end
