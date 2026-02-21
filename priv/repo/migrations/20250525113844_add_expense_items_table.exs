defmodule Quenta.Repo.Migrations.AddExpenseItemsTable do
  use Ecto.Migration

  def change do
    create table(:expense_items) do
      # short description of the expense item
      add :description, :string

      # which expense this item is a part of
      add :expense_id, references(:expenses, on_delete: :delete_all)

      # which user this item belongs to
      add :user_id, references(:users, on_delete: :delete_all)

      # how much was paid for this item, in cents
      add :amount_cents, :integer

      timestamps()
    end

    create index(:expense_items, [:user_id])
    create index(:expense_items, [:expense_id])
  end
end
