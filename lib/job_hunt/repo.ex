defmodule JobHunt.Repo do
  use Ecto.Repo,
    otp_app: :job_hunt,
    adapter: Ecto.Adapters.Postgres
end
