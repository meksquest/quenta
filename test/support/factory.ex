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
      currency_code: "USD",
      created_by_user: build(:user)
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

  def expense_participant_factory do
    %Quenta.ExpenseParticipants.ExpenseParticipant{
      share_cents: 500,
      user: build(:user),
      expense: build(:expense)
    }
  end

  def expense_payment_factory do
    %Quenta.ExpensePayments.ExpensePayment{
      amount_cents: 500,
      user: build(:user),
      expense: build(:expense)
    }
  end

  def currency_factory do
    %Quenta.Currencies.Currency{
      code: sequence(:currency_code, &"C#{&1}") |> String.pad_leading(3, "0"),
      name: sequence(:currency_name, &"Currency #{&1}")
    }
  end
end
