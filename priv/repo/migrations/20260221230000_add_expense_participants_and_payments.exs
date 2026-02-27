defmodule Quenta.Repo.Migrations.AddExpenseParticipantsAndPayments do
  use Ecto.Migration

  def change do
    rename table(:expenses), :user_id, to: :created_by_user_id

    create table(:expense_participants) do
      add :expense_id, references(:expenses, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :share_cents, :integer, null: false

      timestamps()
    end

    create index(:expense_participants, [:expense_id])
    create index(:expense_participants, [:user_id])
    create unique_index(:expense_participants, [:expense_id, :user_id])

    create table(:expense_payments) do
      add :expense_id, references(:expenses, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :amount_cents, :integer, null: false

      timestamps()
    end

    create index(:expense_payments, [:expense_id])
    create index(:expense_payments, [:user_id])
  end
end
