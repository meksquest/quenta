defmodule QuentaWeb.CurrencySelectComponent do
  @moduledoc """
  Searchable currency select component.

  Expects `options` in the same format as `Phoenix.HTML.Form.options_for_select/2`,
  including optgroup-style tuples: `{"Recently used", [{"USD - United States Dollar", "USD"}]}`.
  """

  use QuentaWeb, :live_component

  import Phoenix.Component
  import QuentaWeb.CoreComponents, only: [error: 1, translate_error: 1]

  alias Phoenix.LiveView.JS

  @impl true
  def update(assigns, socket) do
    resolved = resolve_assigns(assigns)

    socket =
      socket
      |> assign(resolved)
      |> assign_new(:open, fn -> false end)
      |> assign_new(:highlighted_index, fn -> nil end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:searching, fn -> false end)
      |> sync_query_with_value()
      |> assign_filtered()

    {:ok, socket}
  end

  @impl true
  def handle_event("open", _params, socket) do
    socket =
      socket
      |> assign(:open, true)
      |> assign(:searching, false)
      |> assign_filtered()
      |> maybe_highlight_selected()

    {:noreply, socket}
  end

  @impl true
  def handle_event("close", _params, socket) do
    socket =
      socket
      |> assign(:open, false)
      |> assign(:searching, false)
      |> assign(:highlighted_index, nil)
      |> sync_query_with_value()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", params, socket) do
    query = Map.get(params, "query") || Map.get(params, "value")

    socket =
      socket
      |> assign(:query, query || "")
      |> assign(:open, true)
      |> assign(:searching, true)
      |> assign(:highlighted_index, initial_highlight(query, socket.assigns))
      |> assign_filtered()

    {:noreply, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => "ArrowDown"}, socket) do
    {:noreply, move_highlight(socket, 1)}
  end

  def handle_event("keydown", %{"key" => "ArrowUp"}, socket) do
    {:noreply, move_highlight(socket, -1)}
  end

  def handle_event("keydown", %{"key" => "Enter"}, socket) do
    {:noreply, select_highlighted(socket)}
  end

  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    socket =
      socket
      |> assign(:open, false)
      |> assign(:highlighted_index, nil)
      |> sync_query_with_value()

    {:noreply, socket}
  end

  def handle_event("keydown", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("select", %{"value" => value}, socket) do
    value = normalize_value(value)
    label = label_for_value(socket.assigns.options, value) || value

    socket =
      socket
      |> assign(:value, value)
      |> assign(:query, label)
      |> assign(:open, false)
      |> assign(:highlighted_index, nil)
      |> assign_filtered()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-click-away="close"
      phx-target={@myself}
      class="relative"
      role="combobox"
      aria-expanded={@open}
      aria-controls={listbox_id(@id)}
      aria-haspopup="listbox"
    >
      <input type="hidden" id={value_input_id(@id)} name={@name} value={@value} />

      <input
        id={input_id(@id)}
        type="text"
        name="query"
        value={@query}
        placeholder={@placeholder}
        autocomplete="off"
        class={[
          "block w-full rounded-lg bg-slate-700 border text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent sm:text-sm",
          @errors == [] && "border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        phx-input="search"
        phx-debounce="200"
        phx-target={@myself}
        phx-focus="open"
        phx-click="open"
        phx-keyup="search"
        phx-keydown="keydown"
        role="combobox"
        aria-autocomplete="list"
        aria-controls={listbox_id(@id)}
        aria-expanded={@open}
        aria-haspopup="listbox"
        aria-activedescendant={active_option_id(@id, @highlighted_index)}
        {@rest}
      />

      <div
        id={listbox_id(@id)}
        role="listbox"
        aria-labelledby={input_id(@id)}
        aria-live="polite"
        aria-hidden={!@open}
        class={[
          "absolute z-50 mt-2 w-full max-h-64 overflow-auto rounded-lg border border-slate-600 bg-slate-800 shadow-lg",
          !@open && "hidden"
        ]}
      >
        <ul class="py-1">
          <li :if={@flat_filtered_options == []} class="px-3 py-2 text-sm text-slate-300">
            No matches
          </li>

          <%= for option <- @filtered_options do %>
            <%= if is_list(elem(option, 1)) do %>
              <% {group_label, group_options} = option %>
              <li
                class="px-3 py-2 text-xs uppercase tracking-wide text-slate-400"
                role="presentation"
                aria-hidden="true"
              >
                {group_label}
              </li>
              <%= for {label, value} <- group_options do %>
                {option_item(assigns, label, value)}
              <% end %>
            <% else %>
              <% {label, value} = option %>
              {option_item(assigns, label, value)}
            <% end %>
          <% end %>
        </ul>
      </div>

      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp option_item(assigns, label, value) do
    index = Map.get(assigns.filtered_index_by_value, normalize_value(value))
    active = index == assigns.highlighted_index
    selected_value = assigns.value

    assigns =
      assign(assigns,
        label: label,
        value: value,
        index: index,
        active: active,
        selected_value: selected_value,
        selected: normalize_value(value) == normalize_value(selected_value)
      )

    ~H"""
    <li
      id={option_id(@id, @index)}
      role="option"
      aria-selected={normalize_value(@value) == normalize_value(@selected_value)}
      class={[
        "px-3 py-2 text-sm cursor-pointer",
        @active && "bg-blue-600 text-white",
        @selected && !@active && "bg-slate-700 text-white font-semibold",
        !@active && !@selected && "text-slate-200 hover:bg-slate-700"
      ]}
    >
      <button
        type="button"
        class="w-full text-left"
        phx-click={
          JS.push("select", target: @myself, value: %{value: @value})
          |> JS.dispatch("change", to: "form")
        }
      >
        {@label}
      </button>
    </li>
    """
  end

  defp resolve_assigns(assigns) do
    base = %{
      id: assigns[:id],
      name: assigns[:name],
      value: assigns[:value],
      options: normalize_options(assigns[:options]),
      errors: assigns[:errors] || [],
      placeholder: assigns[:placeholder] || "Search currency (e.g. USD)",
      rest: assigns[:rest] || %{}
    }

    case assigns[:field] do
      %Phoenix.HTML.FormField{} = field ->
        errors =
          if Phoenix.Component.used_input?(field) do
            Enum.map(field.errors, &translate_error/1)
          else
            []
          end

        base
        |> Map.put(:id, base.id || field.id)
        |> Map.put(:name, base.name || field.name)
        |> Map.put(:value, if(is_nil(base.value), do: field.value, else: base.value))
        |> Map.put(:errors, errors)

      _ ->
        base
    end
  end

  defp sync_query_with_value(socket) do
    if socket.assigns.open do
      socket
    else
      label =
        label_for_value(socket.assigns.options, socket.assigns.value) ||
          socket.assigns.query ||
          ""

      assign(socket, :query, label)
    end
  end

  defp assign_filtered(socket) do
    query = socket.assigns.query || ""
    options = normalize_options(socket.assigns.options)
    selected_label = label_for_value(options, socket.assigns.value)

    normalized_query = normalize_query(query || "")
    normalized_selected_label = normalize_query(selected_label || "")

    effective_query =
      if normalized_query != "" and normalized_query != normalized_selected_label do
        query
      else
        ""
      end

    filtered_options = filter_options(options, effective_query)
    flat_filtered = flatten_options(filtered_options)

    filtered_index_by_value =
      flat_filtered
      |> Enum.with_index()
      |> Map.new(fn {opt, idx} -> {opt.value, idx} end)

    highlighted_index =
      case socket.assigns.highlighted_index do
        nil ->
          nil

        idx when idx < length(flat_filtered) ->
          idx

        _ ->
          nil
      end

    socket
    |> assign(:filtered_options, filtered_options)
    |> assign(:flat_filtered_options, flat_filtered)
    |> assign(:filtered_index_by_value, filtered_index_by_value)
    |> assign(:highlighted_index, highlighted_index)
  end

  defp maybe_highlight_selected(socket) do
    selected_value = normalize_value(socket.assigns.value)

    case socket.assigns.filtered_index_by_value do
      %{} = index_by_value when selected_value != "" ->
        case Map.get(index_by_value, selected_value) do
          nil -> socket
          idx -> assign(socket, :highlighted_index, idx)
        end

      _ ->
        socket
    end
  end

  defp filter_options(options, query) do
    query = normalize_query(query)

    if query == "" do
      options
    else
      Enum.reduce(options, [], fn option, acc ->
        case option do
          {group_label, group_options} when is_list(group_options) ->
            filtered_group =
              Enum.filter(group_options, fn {label, value} ->
                matches_query?(label, value, query)
              end)

            if filtered_group == [] do
              acc
            else
              acc ++ [{group_label, filtered_group}]
            end

          {label, value} ->
            if matches_query?(label, value, query) do
              acc ++ [{label, value}]
            else
              acc
            end
        end
      end)
    end
  end

  defp matches_query?(label, value, query) do
    haystack = normalize_query("#{value} #{label}")

    String.contains?(haystack, query) or fuzzy_subsequence?(haystack, query)
  end

  defp fuzzy_subsequence?(_haystack, ""), do: true

  defp fuzzy_subsequence?(haystack, needle) do
    hay_chars = String.graphemes(haystack)
    needle_chars = String.graphemes(needle)

    do_fuzzy_subsequence?(hay_chars, needle_chars)
  end

  defp do_fuzzy_subsequence?(_haystack, []), do: true
  defp do_fuzzy_subsequence?([], _needle), do: false

  defp do_fuzzy_subsequence?([h | t], [n | nt]) do
    if h == n do
      do_fuzzy_subsequence?(t, nt)
    else
      do_fuzzy_subsequence?(t, [n | nt])
    end
  end

  defp flatten_options(options) do
    Enum.flat_map(options, fn
      {group_label, group_options} when is_list(group_options) ->
        Enum.map(group_options, fn {label, value} ->
          %{label: label, value: normalize_value(value), group: group_label}
        end)

      {label, value} ->
        [%{label: label, value: normalize_value(value), group: nil}]
    end)
  end

  defp label_for_value(options, value) do
    value = normalize_value(value)

    Enum.find_value(options, fn
      {_group_label, group_options} when is_list(group_options) ->
        Enum.find_value(group_options, fn {label, v} ->
          if normalize_value(v) == value, do: label, else: nil
        end)

      {label, v} ->
        if normalize_value(v) == value, do: label, else: nil
    end)
  end

  defp normalize_query(query) do
    query
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/i, "")
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value), do: value |> to_string()

  defp normalize_options(options) when is_list(options), do: options
  defp normalize_options(_options), do: []

  defp move_highlight(socket, delta) do
    socket =
      socket
      |> assign(:open, true)
      |> assign_filtered()

    size = length(socket.assigns.flat_filtered_options)

    highlighted_index =
      case socket.assigns.highlighted_index do
        nil ->
          if size == 0 do
            nil
          else
            if delta > 0, do: 0, else: size - 1
          end

        idx ->
          if size == 0 do
            nil
          else
            rem(idx + delta + size, size)
          end
      end

    assign(socket, :highlighted_index, highlighted_index)
  end

  defp select_highlighted(socket) do
    case socket.assigns.highlighted_index do
      nil ->
        socket

      idx ->
        case Enum.at(socket.assigns.flat_filtered_options, idx) do
          nil ->
            socket

          %{label: label, value: value} ->
            socket
            |> assign(:value, value)
            |> assign(:query, label)
            |> assign(:open, false)
            |> assign(:highlighted_index, nil)
            |> assign_filtered()
        end
    end
  end

  defp initial_highlight(query, assigns) do
    if normalize_query(query || "") == "" or assigns.flat_filtered_options == [], do: nil, else: 0
  end

  defp listbox_id(id), do: "#{id}-listbox"
  defp input_id(id), do: "#{id}-input"
  defp value_input_id(id), do: "#{id}-value"
  defp option_id(_id, nil), do: nil
  defp option_id(id, index), do: "#{id}-option-#{index}"

  defp active_option_id(_id, nil), do: nil
  defp active_option_id(id, index), do: option_id(id, index)
end
