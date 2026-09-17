defmodule Lab.ContactRateLimiter do
  use GenServer

  @window_ms :timer.minutes(10)
  @max_requests 5

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def allow?(key), do: GenServer.call(__MODULE__, {:allow?, key})

  @impl true
  def init(state) do
    Process.send_after(self(), :prune, @window_ms)
    {:ok, state}
  end

  @impl true
  def handle_call({:allow?, key}, _from, state) do
    now = System.monotonic_time(:millisecond)

    {count, expires_at} =
      case Map.get(state, key) do
        {count, expires_at} when now < expires_at -> {count, expires_at}
        _ -> {0, now + @window_ms}
      end

    if count < @max_requests do
      {:reply, true, Map.put(state, key, {count + 1, expires_at})}
    else
      {:reply, false, state}
    end
  end

  @impl true
  def handle_info(:prune, state) do
    now = System.monotonic_time(:millisecond)
    Process.send_after(self(), :prune, @window_ms)
    {:noreply, Map.reject(state, fn {_key, {_count, expires_at}} -> expires_at <= now end)}
  end
end
