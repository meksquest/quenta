defmodule Quenta.PubSubTest do
  use ExUnit.Case, async: true

  alias Quenta.PubSub

  describe "broadcast!/2" do
    test "broadcasts message to topic successfully" do
      topic = "test_topic"
      payload = {:test_message, "hello"}

      # Subscribe to the topic first
      :ok = PubSub.subscribe!(topic)

      # Broadcast the message
      :ok = PubSub.broadcast!(topic, payload)

      # Assert we received the message
      assert_receive {:test_message, "hello"}
    end

    test "broadcasts to multiple subscribers" do
      topic = "multi_subscriber_topic"
      payload = {:broadcast_test, "data"}

      # Subscribe from current process
      :ok = PubSub.subscribe!(topic)

      # Subscribe from another process
      parent = self()

      spawn(fn ->
        :ok = PubSub.subscribe!(topic)
        send(parent, :subscribed)

        receive do
          message -> send(parent, {:received_in_spawn, message})
        end
      end)

      # Wait for spawn process to subscribe
      assert_receive :subscribed

      # Broadcast the message
      :ok = PubSub.broadcast!(topic, payload)

      # Both processes should receive the message
      assert_receive {:broadcast_test, "data"}
      assert_receive {:received_in_spawn, {:broadcast_test, "data"}}
    end

    test "returns :ok when broadcasting to topic with no subscribers" do
      topic = "empty_topic"
      payload = {:empty_test, "no_subscribers"}

      # Should not raise an error
      assert :ok = PubSub.broadcast!(topic, payload)
    end
  end

  describe "subscribe!/1" do
    test "subscribes to topic successfully" do
      topic = "subscription_test"

      assert :ok = PubSub.subscribe!(topic)

      # Verify subscription by broadcasting a message
      payload = {:subscription_verify, "test"}
      :ok = PubSub.broadcast!(topic, payload)

      assert_receive {:subscription_verify, "test"}
    end

    test "subscribes to different topics independently" do
      topic_1 = "topic_one"
      topic_2 = "topic_two"

      :ok = PubSub.subscribe!(topic_1)
      :ok = PubSub.subscribe!(topic_2)

      # Broadcast to topic1
      :ok = PubSub.broadcast!(topic_1, {:topic_1_message, "first"})
      assert_receive {:topic_1_message, "first"}

      # Broadcast to topic2
      :ok = PubSub.broadcast!(topic_2, {:topic_2_message, "second"})
      assert_receive {:topic_2_message, "second"}
    end
  end

  describe "subscribe_to_expense_added/0" do
    test "subscribes to expense_added topic" do
      assert :ok = PubSub.subscribe_to_expense_added()

      # Verify subscription by broadcasting directly to the topic
      payload = {:expense_added, %{id: 1, description: "test"}}
      :ok = PubSub.broadcast!("expense_added", payload)

      assert_receive {:expense_added, %{id: 1, description: "test"}}
    end

    test "receives messages from broadcast_expense_added/1" do
      :ok = PubSub.subscribe_to_expense_added()

      expense = %{id: 123, description: "Coffee", amount_dollars: 5.50}
      :ok = PubSub.broadcast_expense_added(expense)

      assert_receive {:expense_added, ^expense}
    end
  end

  describe "broadcast_expense_added/1" do
    test "broadcasts expense with correct payload format" do
      :ok = PubSub.subscribe!("expense_added")

      expense = %{
        id: 456,
        description: "Lunch",
        amount_dollars: 12.99,
        date: ~D[2023-10-15],
        created_by_user_id: 1
      }

      assert :ok = PubSub.broadcast_expense_added(expense)

      # Should receive tuple with :expense_added atom and expense data
      assert_receive {:expense_added, received_expense}
      assert received_expense == expense
    end

    test "works with subscribe_to_expense_added/0" do
      :ok = PubSub.subscribe_to_expense_added()

      expense = %{id: 789, description: "Dinner", amount_dollars: 25.00}
      :ok = PubSub.broadcast_expense_added(expense)

      assert_receive {:expense_added, ^expense}
    end

    test "broadcasts to multiple subscribers" do
      # Subscribe from current process
      :ok = PubSub.subscribe_to_expense_added()

      # Subscribe from another process
      parent = self()

      spawn(fn ->
        :ok = PubSub.subscribe_to_expense_added()
        send(parent, :child_subscribed)

        receive do
          message -> send(parent, {:child_received, message})
        end
      end)

      # Wait for child process to subscribe
      assert_receive :child_subscribed

      expense = %{id: 999, description: "Shared expense", amount_dollars: 50.00}
      :ok = PubSub.broadcast_expense_added(expense)

      # Both processes should receive the message
      assert_receive {:expense_added, ^expense}
      assert_receive {:child_received, {:expense_added, ^expense}}
    end

    test "handles nil expense gracefully" do
      :ok = PubSub.subscribe_to_expense_added()

      # Should not crash when broadcasting nil
      assert :ok = PubSub.broadcast_expense_added(nil)
      assert_receive {:expense_added, nil}
    end

    test "handles expense with missing fields" do
      :ok = PubSub.subscribe_to_expense_added()

      incomplete_expense = %{id: 111}
      assert :ok = PubSub.broadcast_expense_added(incomplete_expense)

      assert_receive {:expense_added, %{id: 111}}
    end
  end

  describe "subscribe_to_expense_updated/0" do
    test "subscribes to expense_updated topic" do
      assert :ok = PubSub.subscribe_to_expense_updated()

      payload = {:expense_updated, %{id: 1, description: "test"}}
      :ok = PubSub.broadcast!("expense_updated", payload)

      assert_receive {:expense_updated, %{id: 1, description: "test"}}
    end

    test "receives messages from broadcast_expense_updated/1" do
      :ok = PubSub.subscribe_to_expense_updated()

      expense = %{id: 222, description: "Updated Coffee", amount_dollars: 4.25}
      :ok = PubSub.broadcast_expense_updated(expense)

      assert_receive {:expense_updated, ^expense}
    end
  end

  describe "broadcast_expense_updated/1" do
    test "broadcasts expense with correct payload format" do
      :ok = PubSub.subscribe!("expense_updated")

      expense = %{
        id: 333,
        description: "Updated Lunch",
        amount_dollars: 12.99,
        date: ~D[2023-10-15],
        created_by_user_id: 1
      }

      assert :ok = PubSub.broadcast_expense_updated(expense)

      assert_receive {:expense_updated, received_expense}
      assert received_expense == expense
    end

    test "broadcasts to multiple subscribers" do
      :ok = PubSub.subscribe_to_expense_updated()

      parent = self()

      spawn(fn ->
        :ok = PubSub.subscribe_to_expense_updated()
        send(parent, :child_subscribed)

        receive do
          message -> send(parent, {:child_received, message})
        end
      end)

      assert_receive :child_subscribed

      expense = %{id: 444, description: "Shared update", amount_dollars: 50.00}
      :ok = PubSub.broadcast_expense_updated(expense)

      assert_receive {:expense_updated, ^expense}
      assert_receive {:child_received, {:expense_updated, ^expense}}
    end

    test "handles nil expense gracefully" do
      :ok = PubSub.subscribe_to_expense_updated()

      assert :ok = PubSub.broadcast_expense_updated(nil)
      assert_receive {:expense_updated, nil}
    end

    test "handles expense with missing fields" do
      :ok = PubSub.subscribe_to_expense_updated()

      incomplete_expense = %{id: 555}
      assert :ok = PubSub.broadcast_expense_updated(incomplete_expense)

      assert_receive {:expense_updated, %{id: 555}}
    end
  end

  describe "subscribe_to_expense_deleted/0" do
    test "subscribes to expense_deleted topic" do
      assert :ok = PubSub.subscribe_to_expense_deleted()

      payload = {:expense_deleted, %{id: 1, description: "test"}}
      :ok = PubSub.broadcast!("expense_deleted", payload)

      assert_receive {:expense_deleted, %{id: 1, description: "test"}}
    end

    test "receives messages from broadcast_expense_deleted/1" do
      :ok = PubSub.subscribe_to_expense_deleted()

      expense = %{id: 222, description: "Deleted Coffee", amount_dollars: 4.25}
      :ok = PubSub.broadcast_expense_deleted(expense)

      assert_receive {:expense_deleted, ^expense}
    end
  end

  describe "broadcast_expense_deleted/1" do
    test "broadcasts expense with correct payload format" do
      :ok = PubSub.subscribe!("expense_deleted")

      expense = %{
        id: 333,
        description: "Removed Lunch",
        amount_dollars: 12.99,
        date: ~D[2023-10-15],
        created_by_user_id: 1
      }

      assert :ok = PubSub.broadcast_expense_deleted(expense)

      assert_receive {:expense_deleted, received_expense}
      assert received_expense == expense
    end

    test "broadcasts to multiple subscribers" do
      :ok = PubSub.subscribe_to_expense_deleted()

      parent = self()

      spawn(fn ->
        :ok = PubSub.subscribe_to_expense_deleted()
        send(parent, :child_subscribed)

        receive do
          message -> send(parent, {:child_received, message})
        end
      end)

      assert_receive :child_subscribed

      expense = %{id: 444, description: "Shared deletion", amount_dollars: 50.00}
      :ok = PubSub.broadcast_expense_deleted(expense)

      assert_receive {:expense_deleted, ^expense}
      assert_receive {:child_received, {:expense_deleted, ^expense}}
    end

    test "handles nil expense gracefully" do
      :ok = PubSub.subscribe_to_expense_deleted()

      assert :ok = PubSub.broadcast_expense_deleted(nil)
      assert_receive {:expense_deleted, nil}
    end

    test "handles expense with missing fields" do
      :ok = PubSub.subscribe_to_expense_deleted()

      incomplete_expense = %{id: 555}
      assert :ok = PubSub.broadcast_expense_deleted(incomplete_expense)

      assert_receive {:expense_deleted, %{id: 555}}
    end
  end
end
