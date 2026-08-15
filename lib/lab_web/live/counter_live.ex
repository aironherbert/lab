defmodule LabWeb.CounterLive do
  use LabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Lab.Counter.subscribe()

    {:ok,
     assign(socket,
       page_title: "Laboratório GenServer",
       count: Lab.Counter.value(),
       last_action: :started
     )}
  end

  @impl true
  def handle_event("increment", _params, socket) do
    Lab.Counter.increment()
    {:noreply, socket}
  end

  def handle_event("decrement", _params, socket) do
    Lab.Counter.decrement()
    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    Lab.Counter.reset()
    {:noreply, socket}
  end

  @impl true
  def handle_info({:counter_updated, value, action}, socket) do
    {:noreply, assign(socket, count: value, last_action: action)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="genserver-lab" class="mx-auto max-w-5xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="max-w-3xl">
          <span class="inline-flex items-center rounded-full bg-violet-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.18em] text-violet-700 dark:bg-violet-500/15 dark:text-violet-300">
            Elixir • OTP
          </span>
          <h1 class="mt-5 text-4xl font-black tracking-tight text-slate-950 sm:text-6xl dark:text-white">
            GenServer na prática
          </h1>
          <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
            Este contador vive em um processo Elixir supervisionado. Abra outra aba e veja o mesmo estado aparecer nas duas.
          </p>
        </header>

        <div class="mt-10 grid gap-6 lg:grid-cols-2">
          <section class="overflow-hidden rounded-3xl bg-slate-950 p-6 text-white shadow-2xl shadow-violet-950/20 sm:p-8">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <span class="relative flex size-3">
                  <span class="absolute inline-flex size-full animate-ping rounded-full bg-emerald-400 opacity-60">
                  </span>
                  <span class="relative inline-flex size-3 rounded-full bg-emerald-400"></span>
                </span>
                <span class="font-mono text-sm text-slate-300">Lab.Counter está ativo</span>
              </div>
              <span class="rounded-lg bg-white/10 px-2.5 py-1 font-mono text-xs text-slate-300">
                PID registrado
              </span>
            </div>

            <div class="py-12 text-center">
              <p class="text-sm font-semibold uppercase tracking-[0.2em] text-violet-300">
                Estado atual
              </p>
              <output
                id="counter-value"
                class="mt-2 block font-mono text-8xl font-black tabular-nums tracking-tighter sm:text-9xl"
              >
                {@count}
              </output>
              <p id="last-action" class="mt-3 font-mono text-sm text-slate-400">
                última mensagem: {action_label(@last_action)}
              </p>
            </div>

            <div class="grid grid-cols-3 gap-3">
              <button
                id="decrement"
                phx-click="decrement"
                class="rounded-2xl bg-white/10 px-4 py-4 text-xl font-bold transition hover:-translate-y-0.5 hover:bg-white/20 focus:outline-none focus:ring-2 focus:ring-violet-400"
              >
                − 1
              </button>
              <button
                id="reset"
                phx-click="reset"
                class="rounded-2xl border border-white/15 px-4 py-4 text-sm font-bold transition hover:-translate-y-0.5 hover:bg-white/10 focus:outline-none focus:ring-2 focus:ring-violet-400"
              >
                Zerar
              </button>
              <button
                id="increment"
                phx-click="increment"
                class="rounded-2xl bg-violet-500 px-4 py-4 text-xl font-bold transition hover:-translate-y-0.5 hover:bg-violet-400 focus:outline-none focus:ring-2 focus:ring-violet-300"
              >
                + 1
              </button>
            </div>
          </section>

          <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8 dark:border-white/10 dark:bg-slate-900">
            <h2 class="text-xl font-bold text-slate-950 dark:text-white">O caminho de um clique</h2>
            <ol class="mt-6 space-y-5">
              <.step
                number="1"
                title="LiveView recebe o evento"
                code={~c"handle_event(\"increment\", ...)"}
              />
              <.step
                number="2"
                title="Uma mensagem é enviada"
                code="GenServer.cast(Lab.Counter, :increment)"
              />
              <.step
                number="3"
                title="O processo altera seu estado"
                code="handle_cast(:increment, value)"
              />
              <.step
                number="4"
                title="A interface é atualizada"
                code="{:counter_updated, value, action}"
              />
            </ol>

            <div class="mt-7 rounded-2xl bg-violet-50 p-4 text-sm leading-6 text-violet-950 dark:bg-violet-500/10 dark:text-violet-200">
              <strong>Experimente:</strong>
              recarregue a página. O número continua igual porque o estado pertence ao GenServer, não ao navegador.
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :code, :string, required: true

  defp step(assigns) do
    ~H"""
    <li class="flex gap-4">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-slate-950 font-mono text-sm font-bold text-white dark:bg-violet-500">
        {@number}
      </span>
      <div class="min-w-0">
        <p class="font-semibold text-slate-900 dark:text-white">{@title}</p>
        <code class="mt-1 block overflow-x-auto text-xs text-slate-500 dark:text-slate-400">
          {@code}
        </code>
      </div>
    </li>
    """
  end

  defp action_label(:started), do: "GenServer.call(:value)"
  defp action_label(:increment), do: "GenServer.cast(:increment)"
  defp action_label(:decrement), do: "GenServer.cast(:decrement)"
  defp action_label(:reset), do: "GenServer.cast(:reset)"
end
