defmodule Quenta.Repo.Migrations.AddCurrencyCodeToExpenses do
  use Ecto.Migration

  def up do
    alter table(:expenses) do
      add :currency_code, references(:currencies, column: :code, type: :string), null: true
    end

    execute "UPDATE expenses SET currency_code = 'USD' WHERE currency_code IS NULL"

    alter table(:expenses) do
      modify :currency_code, :string, null: false
    end

    create index(:expenses, [:currency_code])
  end

  def down do
    drop index(:expenses, [:currency_code])

    alter table(:expenses) do
      remove :currency_code
    end
  end
end
