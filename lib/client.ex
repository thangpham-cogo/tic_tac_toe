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
