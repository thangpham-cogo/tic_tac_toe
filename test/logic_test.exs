defmodule TTT.LogicTest do
  use ExUnit.Case

  setup do
    board = List.duplicate(nil, 9)

    win_patterns = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6]
    ]

    %{board: board, win_patterns: win_patterns}
  end

  describe "has_winner?/2" do
    test "returns false if board is empty", %{board: board, win_patterns: win_patterns} do
      assert false == TTT.Logic.has_winner?(board, win_patterns)
    end

    test "returns true if any win pattern is present", %{board: board, win_patterns: win_patterns} do
      boards_with_win_pattern =
        win_patterns
        |> Enum.map(fn pattern ->
          board
          |> Enum.with_index(fn ele, index ->
            if index in pattern do
              "X"
            else
              ele
            end
          end)
        end)

      assert true ==
               Enum.all?(boards_with_win_pattern, &TTT.Logic.has_winner?(&1, win_patterns))
    end
  end

  describe "update_board/3" do
    test "returns invalid position if position is negative", %{board: board} do
      assert {:error, :invalid_position} = TTT.Logic.update_board(board, -1, "X")
    end

    test "returns invalid position if position is out of board range", %{board: board} do
      assert {:error, :invalid_position} = TTT.Logic.update_board(board, length(board) + 1, "X")
    end

    test "returns invalid position if cell is not empty", %{board: board} do
      cell = 0
      updated = List.replace_at(board, cell, "X")

      assert {:error, :cell_not_empty} = TTT.Logic.update_board(updated, cell, "X")
    end

    test "returns the updated board if position is valid", %{board: board} do
      updated = List.replace_at(board, 0, "X")

      assert {:ok, ^updated} = TTT.Logic.update_board(board, 0, "X")
    end
  end
end
