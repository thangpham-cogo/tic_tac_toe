defmodule TTT.Application do
  use Application

  def start(_, _) do
    TTT.Server.start_link(name: TTT.Server)
    TTT.Client.start(6000)
  end
end
