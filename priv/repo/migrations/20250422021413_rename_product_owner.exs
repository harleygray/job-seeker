defmodule JobHunt.Repo.Migrations.RenameProductOwner do
  use Ecto.Migration

  def change do
    alter table(:jobs) do
      remove :product_owner
      add :product_owner_score, :integer
    end
  end
end
