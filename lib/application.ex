defmodule TTT.Application do
  use Application

  def start(_, _) do
    children = [
      TTT.Server,
      TTT.Client
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
