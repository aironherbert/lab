defmodule LabWeb.DynamicSupervisorLive do
  use LabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Lab.DynamicWorker.subscribe()

    socket =
      socket
      |> assign(
        page_title: "Laboratório DynamicSupervisor",
        worker_count: 0,
        pids: %{},
        restarts: %{}
      )
      |> stream(:workers, [])
      |> refresh_workers()

    {:ok, socket}
  end

  @impl true
  def handle_event("start-worker", _params, socket) do
    {:ok, _id, _pid} = Lab.DynamicWorkers.start_worker()
    {:noreply, refresh_workers(socket)}
  end

  def handle_event("work", %{"pid" => encoded_pid}, socket) do
    with {:ok, pid} <- find_pid(socket, encoded_pid) do
      Lab.DynamicWorker.work(pid)
    end

    {:noreply, socket}
  end

  def handle_event("crash", %{"pid" => encoded_pid}, socket) do
    with {:ok, pid} <- find_pid(socket, encoded_pid) do
      Lab.DynamicWorker.crash(pid)
    end

    {:noreply, socket}
  end

  def handle_event("stop", %{"pid" => encoded_pid}, socket) do
    with {:ok, pid} <- find_pid(socket, encoded_pid) do
      :ok = Lab.DynamicWorkers.stop_worker(pid)
    end

    {:noreply, refresh_workers(socket)}
  end

  @impl true
  def handle_info({:dynamic_worker_started, pid, state}, socket) do
    previous_pid = Map.get(socket.assigns.pids, state.id)

    restarts =
      if is_pid(previous_pid) and previous_pid != pid do
        Map.update(socket.assigns.restarts, state.id, 1, &(&1 + 1))
      else
        socket.assigns.restarts
      end

    {:noreply, socket |> assign(restarts: restarts) |> refresh_workers()}
  end

  def handle_info({:dynamic_worker_updated, _pid, _state}, socket) do
    {:noreply, refresh_workers(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="dynamic-supervisor-lab" class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="flex flex-col gap-6 sm:flex-row sm:items-end sm:justify-between">
          <div class="max-w-3xl">
            <.link
              navigate={~p"/supervisor"}
              class="text-sm font-semibold text-violet-600 hover:text-violet-500 dark:text-violet-300"
            >
              ← Supervisor estático
            </.link>
            <h1 class="mt-5 text-4xl font-black tracking-tight text-slate-950 sm:text-6xl dark:text-white">
              DynamicSupervisor
            </h1>
            <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
              Crie e remova processos durante a execução. Cada cartão abaixo representa um filho real e independente.
            </p>
            <.link
              navigate={~p"/registry"}
              class="mt-5 inline-flex items-center gap-2 font-semibold text-violet-600 hover:text-violet-500 dark:text-violet-300"
            >
              Nomear processos com Registry <span aria-hidden="true">→</span>
            </.link>
          </div>
          <button
            id="start-worker"
            phx-click="start-worker"
            class="shrink-0 rounded-2xl bg-violet-600 px-6 py-4 font-bold text-white shadow-lg shadow-violet-600/20 transition hover:-translate-y-0.5 hover:bg-violet-500 focus:outline-none focus:ring-2 focus:ring-violet-400"
          >
            <.icon name="hero-plus" class="mr-2 size-5" /> Novo worker
          </button>
        </header>

        <section class="mt-10 rounded-3xl bg-slate-950 p-5 text-white sm:p-7">
          <div class="flex flex-wrap items-center justify-between gap-4 border-b border-white/10 pb-5">
            <div>
              <p class="font-mono text-sm text-violet-300">Lab.DynamicSupervisor</p>
              <p class="mt-1 text-sm text-slate-400">
                strategy: :one_for_one • filhos iniciados sob demanda
              </p>
            </div>
            <span id="worker-count" class="rounded-full bg-white/10 px-4 py-2 font-mono text-sm">
              {@worker_count} {if @worker_count == 1, do: "filho", else: "filhos"}
            </span>
          </div>

          <div id="workers" phx-update="stream" class="mt-6 grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <article
              :for={{dom_id, worker} <- @streams.workers}
              id={dom_id}
              class="rounded-2xl border border-white/10 bg-white/5 p-5 transition hover:border-violet-400/40 hover:bg-white/[0.07]"
            >
              <div class="flex items-start justify-between gap-3">
                <div>
                  <p class="text-xs font-bold uppercase tracking-[0.18em] text-violet-300">
                    Worker #{worker.worker_id}
                  </p>
                  <p class="mt-2 font-mono text-xs text-slate-400">{worker.pid_label}</p>
                </div>
                <span class="inline-flex items-center gap-2 rounded-full bg-emerald-400/10 px-2.5 py-1 text-xs font-semibold text-emerald-300">
                  <span class="size-1.5 rounded-full bg-emerald-400"></span> ativo
                </span>
              </div>

              <div class="mt-6 grid grid-cols-2 gap-3">
                <div class="rounded-xl bg-black/20 p-3">
                  <p class="text-xs text-slate-500">Trabalhos</p>
                  <p class="mt-1 font-mono text-2xl font-black">{worker.jobs}</p>
                </div>
                <div class="rounded-xl bg-black/20 p-3">
                  <p class="text-xs text-slate-500">Reinícios</p>
                  <p class="mt-1 font-mono text-2xl font-black">{worker.restarts}</p>
                </div>
              </div>

              <div class="mt-4 grid grid-cols-3 gap-2">
                <button
                  phx-click="work"
                  phx-value-pid={worker.pid_label}
                  class="rounded-xl bg-violet-500 px-2 py-2.5 text-xs font-bold transition hover:bg-violet-400"
                >
                  Trabalhar
                </button>
                <button
                  phx-click="crash"
                  phx-value-pid={worker.pid_label}
                  class="rounded-xl bg-amber-400/15 px-2 py-2.5 text-xs font-bold text-amber-300 transition hover:bg-amber-400/25"
                >
                  Crash
                </button>
                <button
                  phx-click="stop"
                  phx-value-pid={worker.pid_label}
                  class="rounded-xl bg-rose-400/15 px-2 py-2.5 text-xs font-bold text-rose-300 transition hover:bg-rose-400/25"
                >
                  Encerrar
                </button>
              </div>
            </article>
          </div>

          <div :if={@worker_count == 0} id="empty-workers" class="py-16 text-center">
            <div class="mx-auto flex size-14 items-center justify-center rounded-2xl bg-white/5">
              <.icon name="hero-cube-transparent" class="size-7 text-slate-500" />
            </div>
            <p class="mt-4 font-semibold text-slate-300">Nenhum filho em execução</p>
            <p class="mt-1 text-sm text-slate-500">
              Crie um worker para alterar a árvore em tempo real.
            </p>
          </div>
        </section>

        <div class="mt-6 grid gap-4 md:grid-cols-3">
          <.concept
            title="Novo worker"
            code="DynamicSupervisor.start_child/2"
            text="Acrescenta um filho sem reiniciar o supervisor."
          />
          <.concept
            title="Crash isolado"
            code=":one_for_one"
            text="O filho falha e renasce; os demais mantêm PID e estado."
          />
          <.concept
            title="Encerramento"
            code="DynamicSupervisor.terminate_child/2"
            text="Remove o filho intencionalmente, sem reiniciá-lo."
          />
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  attr :code, :string, required: true
  attr :text, :string, required: true

  defp concept(assigns) do
    ~H"""
    <article class="rounded-2xl border border-slate-200 bg-white p-5 dark:border-white/10 dark:bg-slate-900">
      <h2 class="font-bold text-slate-950 dark:text-white">{@title}</h2>
      <code class="mt-2 block text-xs text-violet-600 dark:text-violet-300">{@code}</code>
      <p class="mt-3 text-sm leading-6 text-slate-500 dark:text-slate-400">{@text}</p>
    </article>
    """
  end

  defp refresh_workers(socket) do
    workers = Lab.DynamicWorkers.list_workers()
    pids = Map.new(workers, &{&1.id, &1.pid})

    rendered_workers =
      Enum.map(workers, fn worker ->
        %{
          id: "dynamic-worker-#{worker.id}",
          worker_id: worker.id,
          pid_label: inspect(worker.pid),
          jobs: worker.jobs,
          restarts: Map.get(socket.assigns.restarts, worker.id, 0)
        }
      end)

    socket
    |> assign(worker_count: length(workers), pids: pids)
    |> stream(:workers, rendered_workers, reset: true)
  end

  defp find_pid(socket, encoded_pid) do
    case Enum.find(socket.assigns.pids, fn {_id, pid} -> inspect(pid) == encoded_pid end) do
      {_id, pid} -> {:ok, pid}
      nil -> :error
    end
  end
end
