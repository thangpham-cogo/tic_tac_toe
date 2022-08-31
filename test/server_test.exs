defmodule TTT.ServerTest do
  use ExUnit.Case

  alias TTT.Server

  setup do
    {:ok, pid} = Server.start_link()
    board = List.duplicate(nil, 9)

    %{pid: pid, board: board}
  end

  describe "register" do
    test "works for 1st player", %{board: board} do
      p1 = fake_player()

      assert {^board, [^p1, nil], nil} = Server.register(p1)
    end

    test "works for 2nd player", %{board: board} do
      p1 = fake_player()
      p2 = fake_player()

      assert {^board, [^p1, nil], nil} = Server.register(p1)
      assert {^board, [^p1, ^p2], ^p1} = Server.register(p2)
    end

    # https://elixirforum.com/t/how-to-assert-some-process-received-some-message/1779/7 mindful of this (see last comment)
    test "asks 1st player to start after 2nd player is registered", %{board: board} do
      p1 = self()
      p2 = fake_player()

      Server.register(p1)
      Server.register(p2)

      assert_received {:your_turn, ^board}
    end

    test "returns error when game is full" do
      p1 = fake_player()
      p2 = fake_player()
      p3 = fake_player()

      Server.register(p1)
      Server.register(p2)
      assert {:error, :game_full} = Server.register(p3)
    end
  end

  def fake_player() do
    spawn(fn ->
      receive do
        _ -> :ok
      end
    end)
  end
end
