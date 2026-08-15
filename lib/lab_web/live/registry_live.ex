defmodule LabWeb.RegistryLive do
  use LabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Lab.RegistryWorker.subscribe()

    socket =
      socket
      |> assign(
        page_title: "Laboratório Registry",
        form: to_form(%{"name" => ""}, as: :worker),
        error: nil,
        worker_count: 0,
        pids: %{},
        restarts: %{}
      )
      |> stream(:workers, [])
      |> refresh_workers()

    {:ok, socket}
  end

  @impl true
  def handle_event("start-worker", %{"worker" => %{"name" => name}}, socket) do
    case Lab.RegistryWorkers.start_worker(name) do
      {:ok, _pid} ->
        {:noreply,
         socket
         |> assign(form: to_form(%{"name" => ""}, as: :worker), error: nil)
         |> refresh_workers()}

      {:error, {:already_started, _pid}} ->
        {:noreply, assign(socket, error: "Esse nome já está registrado.")}

      {:error, :blank_name} ->
        {:noreply, assign(socket, error: "Digite um nome para o processo.")}

      {:error, _reason} ->
        {:noreply, assign(socket, error: "Não foi possível iniciar o processo.")}
    end
  end

  def handle_event("increment", %{"name" => name}, socket) do
    _count = Lab.RegistryWorkers.increment(name)
    {:noreply, refresh_workers(socket)}
  end

  def handle_event("crash", %{"name" => name}, socket) do
    Lab.RegistryWorkers.crash(name)
    {:noreply, socket}
  end

  def handle_event("stop", %{"name" => name}, socket) do
    _result = Lab.RegistryWorkers.stop_worker(name)
    {:noreply, refresh_workers(socket)}
  end

  @impl true
  def handle_info({:registry_worker_started, pid, state}, socket) do
    previous_pid = Map.get(socket.assigns.pids, state.name)

    restarts =
      if is_pid(previous_pid) and previous_pid != pid do
        Map.update(socket.assigns.restarts, state.name, 1, &(&1 + 1))
      else
        socket.assigns.restarts
      end

    {:noreply, socket |> assign(restarts: restarts) |> refresh_workers()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="registry-lab" class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="max-w-3xl">
          <.link
            navigate={~p"/dynamic-supervisor"}
            class="text-sm font-semibold text-violet-600 hover:text-violet-500 dark:text-violet-300"
          >
            ← DynamicSupervisor
          </.link>
          <h1 class="mt-5 text-4xl font-black tracking-tight text-slate-950 sm:text-6xl dark:text-white">
            Registry por nome
          </h1>
          <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
            Dê um nome a cada contador. O Registry conecta esse nome a um PID, então todo acesso pode usar uma identidade estável e legível.
          </p>
        </header>

        <div class="mt-10 grid gap-6 lg:grid-cols-[0.8fr_1.2fr]">
          <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8 dark:border-white/10 dark:bg-slate-900">
            <p class="text-xs font-bold uppercase tracking-[0.18em] text-violet-600 dark:text-violet-300">
              Novo processo
            </p>
            <h2 class="mt-2 text-2xl font-black text-slate-950 dark:text-white">
              Registre um contador
            </h2>

            <.form for={@form} id="registry-form" phx-submit="start-worker" class="mt-6 space-y-4">
              <.input
                field={@form[:name]}
                type="text"
                label="Nome único"
                placeholder="ex.: pagamentos"
                autocomplete="off"
              />
              <p
                :if={@error}
                id="registry-error"
                class="text-sm font-semibold text-rose-600 dark:text-rose-300"
              >
                {@error}
              </p>
              <button
                id="register-worker"
                type="submit"
                class="w-full rounded-2xl bg-violet-600 px-5 py-3.5 font-bold text-white shadow-lg shadow-violet-600/20 transition hover:-translate-y-0.5 hover:bg-violet-500 focus:outline-none focus:ring-2 focus:ring-violet-400"
              >
                Registrar processo
              </button>
            </.form>

            <div
              class="mt-6 rounded-2xl bg-slate-950 p-4 font-mono text-xs leading-6 text-slate-300"
              phx-no-curly-interpolation
            >
              <p class="text-violet-300">{:via, Registry,</p>
              <p class="pl-4">{Lab.ProcessRegistry, "nome"}}</p>
            </div>
          </section>

          <section class="rounded-3xl bg-slate-950 p-6 text-white sm:p-8">
            <div class="flex items-center justify-between border-b border-white/10 pb-5">
              <div>
                <p class="font-mono text-sm text-violet-300">Lab.ProcessRegistry</p>
                <p class="mt-1 text-sm text-slate-400">keys: :unique</p>
              </div>
              <span id="registry-count" class="rounded-full bg-white/10 px-4 py-2 font-mono text-sm">
                {@worker_count} {if @worker_count == 1, do: "registro", else: "registros"}
              </span>
            </div>

            <div id="registry-workers" phx-update="stream" class="mt-5 space-y-3">
              <article
                :for={{dom_id, worker} <- @streams.workers}
                id={dom_id}
                class="grid gap-4 rounded-2xl border border-white/10 bg-white/5 p-5 sm:grid-cols-[1fr_auto] sm:items-center"
              >
                <div class="min-w-0">
                  <div class="flex items-center gap-2">
                    <span class="size-2 rounded-full bg-emerald-400"></span>
                    <h3 class="truncate font-bold">{worker.name}</h3>
                  </div>
                  <p class="mt-2 truncate font-mono text-xs text-slate-400">{worker.pid_label}</p>
                  <div class="mt-3 flex gap-6">
                    <div>
                      <p class="text-xs text-slate-500">Contagem</p>
                      <p class="font-mono text-3xl font-black">{worker.count}</p>
                    </div>
                    <div>
                      <p class="text-xs text-slate-500">Reinícios</p>
                      <p
                        id={"registry-restarts-#{worker.name}"}
                        class="font-mono text-3xl font-black"
                      >
                        {worker.restarts}
                      </p>
                    </div>
                  </div>
                </div>
                <div class="flex gap-2">
                  <button
                    phx-click="increment"
                    phx-value-name={worker.name}
                    class="rounded-xl bg-violet-500 px-4 py-2.5 text-sm font-bold transition hover:bg-violet-400"
                  >
                    + 1
                  </button>
                  <button
                    phx-click="crash"
                    phx-value-name={worker.name}
                    class="rounded-xl bg-amber-400/15 px-4 py-2.5 text-sm font-bold text-amber-300 transition hover:bg-amber-400/25"
                  >
                    Crash
                  </button>
                  <button
                    phx-click="stop"
                    phx-value-name={worker.name}
                    class="rounded-xl bg-rose-400/15 px-4 py-2.5 text-sm font-bold text-rose-300 transition hover:bg-rose-400/25"
                  >
                    Remover
                  </button>
                </div>
              </article>
            </div>

            <div :if={@worker_count == 0} id="empty-registry" class="py-14 text-center">
              <.icon name="hero-identification" class="mx-auto size-8 text-slate-500" />
              <p class="mt-3 font-semibold text-slate-300">Nenhum nome registrado</p>
            </div>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp refresh_workers(socket) do
    registry_workers = Lab.RegistryWorkers.list_workers()
    pids = Map.new(registry_workers, &{&1.name, &1.pid})

    workers =
      Enum.map(registry_workers, fn worker ->
        %{
          id: "registry-worker-#{worker.name}",
          name: worker.name,
          count: worker.count,
          restarts: Map.get(socket.assigns.restarts, worker.name, 0),
          pid_label: inspect(worker.pid)
        }
      end)

    socket
    |> assign(worker_count: length(workers), pids: pids)
    |> stream(:workers, workers, reset: true)
  end
end
