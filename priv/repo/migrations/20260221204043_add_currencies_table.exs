defmodule Quenta.Repo.Migrations.AddCurrenciesTable do
  use Ecto.Migration

  def change do
    create table(:currencies, primary_key: false) do
      add :code, :string, primary_key: true, size: 3, null: false
      add :name, :string, null: false

      timestamps(null: false)
    end
  end
end
