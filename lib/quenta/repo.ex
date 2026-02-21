defmodule Quenta.Repo do
  use Ecto.Repo,
    otp_app: :quenta,
    adapter: Ecto.Adapters.Postgres
end
