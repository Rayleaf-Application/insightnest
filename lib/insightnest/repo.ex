defmodule Insightnest.Repo do
  use Ecto.Repo,
    otp_app: :insightnest,
    adapter: Ecto.Adapters.Postgres
end
