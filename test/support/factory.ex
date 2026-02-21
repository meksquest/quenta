defmodule Quenta.Factory do
  use ExMachina.Ecto, repo: Quenta.Repo

  def user_factory do
    %Quenta.Users.User{
      name: sequence(:name, &"User #{&1}")
    }
  end

  def expense_factory do
    %Quenta.Expenses.Expense{
      description: sequence(:description, &"Expense #{&1}"),
      date: ~D[2023-10-01],
      amount_cents: 1500,
      user: build(:user)
    }
  end

  def expense_item_factory do
    %Quenta.ExpenseItems.ExpenseItem{
      description: sequence(:description, &"Item #{&1}"),
      amount_cents: 500,
      user: build(:user),
      expense: build(:expense)
    }
  end
end
