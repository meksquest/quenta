defmodule Quenta.PubSub do
  @moduledoc """
  A set of pub/sub-related functions for use by downstream modules.

  These functions are meant to be used in pairs.
  For example, if you want to be notified about expenses, use
  `subscribe_to_expense_added!/1`; if you want to notify
  others about them, use `broadcast_expense_added!/2`.
  """

  @doc """
  Broadcasts a given message to a topic or a given list of topics.
  """
  def broadcast!(topic, payload) do
    :ok = Phoenix.PubSub.broadcast!(Quenta.PubSub, topic, payload)
  end

  @doc """
  Subscribes the caller to the PubSub adapter's topic.
  """
  def subscribe!(topic) do
    :ok = Phoenix.PubSub.subscribe(Quenta.PubSub, topic)
  end

  ## Expenses

  @doc """
  Subscribes to `expense` added
  """
  def subscribe_to_expense_added do
    subscribe!("expense_added")
  end

  @doc """
  Broadcasts `expense` added
  """
  def broadcast_expense_added(expense) do
    payload = {:expense_added, expense}
    broadcast!("expense_added", payload)
  end

  @doc """
  Subscribes to `expense` updated
  """
  def subscribe_to_expense_updated do
    subscribe!("expense_updated")
  end

  @doc """
  Broadcasts `expense` updated
  """
  def broadcast_expense_updated(expense) do
    payload = {:expense_updated, expense}
    broadcast!("expense_updated", payload)
  end

  @doc """
  Subscribes to `expense` deleted
  """
  def subscribe_to_expense_deleted do
    subscribe!("expense_deleted")
  end

  @doc """
  Broadcasts `expense` deleted
  """
  def broadcast_expense_deleted(expense) do
    payload = {:expense_deleted, expense}
    broadcast!("expense_deleted", payload)
  end
end
