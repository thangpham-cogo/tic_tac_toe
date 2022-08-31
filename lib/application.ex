defmodule TTT.Application do
  def start(_, _) do
    server_pid = TTT.Server.start()
    TTT.Client.start(server_pid, 6000)
  end
end
