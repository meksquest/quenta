defmodule Quenta.Repo.Migrations.AddExpensesTable do
  use Ecto.Migration

  def change do
    create table(:expenses) do
      # short description of the expense
      add :description, :string

      # the date of the expense
      add :date, :date

      # which user paid this expense
      add :user_id, references(:users, on_delete: :delete_all)

      # how much was paid, in cents
      add :amount_cents, :integer

      timestamps()
    end

    create index(:expenses, [:user_id])
  end
end
