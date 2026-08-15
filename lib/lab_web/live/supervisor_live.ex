defmodule LabWeb.SupervisorLive do
  use LabWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Lab.ResilientWorker.subscribe()

    pid = Process.whereis(Lab.ResilientWorker)
    state = Lab.ResilientWorker.status()

    socket =
      socket
      |> assign(
        page_title: "Laboratório Supervisor",
        pid: pid,
        jobs: state.jobs,
        started_at: state.started_at,
        restart_count: 0,
        status: :running
      )
      |> monitor(pid)

    {:ok, socket}
  end

  @impl true
  def handle_event("work", _params, socket) do
    Lab.ResilientWorker.work()
    {:noreply, socket}
  end

  def handle_event("crash", _params, socket) do
    Lab.ResilientWorker.crash()
    {:noreply, assign(socket, status: :crashing)}
  end

  @impl true
  def handle_info({:worker_updated, pid, state}, socket) do
    {:noreply, assign(socket, pid: pid, jobs: state.jobs, started_at: state.started_at)}
  end

  def handle_info({:worker_started, pid, state}, socket) do
    socket =
      socket
      |> assign(
        pid: pid,
        jobs: state.jobs,
        started_at: state.started_at,
        restart_count: socket.assigns.restart_count + 1,
        status: :running
      )
      |> monitor(pid)

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{assigns: %{pid: pid}} = socket) do
    {:noreply, assign(socket, status: :restarting)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="supervisor-lab" class="mx-auto max-w-5xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="max-w-3xl">
          <.link
            navigate={~p"/"}
            class="text-sm font-semibold text-violet-600 hover:text-violet-500 dark:text-violet-300"
          >
            ← Laboratório GenServer
          </.link>
          <h1 class="mt-5 text-4xl font-black tracking-tight text-slate-950 sm:text-6xl dark:text-white">
            Supervisor em ação
          </h1>
          <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
            Provoque uma falha real e observe o supervisor substituir o processo por outro, sem derrubar a aplicação.
          </p>
          <.link
            navigate={~p"/dynamic-supervisor"}
            class="mt-5 inline-flex items-center gap-2 font-semibold text-violet-600 hover:text-violet-500 dark:text-violet-300"
          >
            Experimentar DynamicSupervisor <span aria-hidden="true">→</span>
          </.link>
        </header>

        <div class="mt-10 grid gap-6 lg:grid-cols-2">
          <section class="rounded-3xl bg-slate-950 p-6 text-white shadow-2xl shadow-violet-950/20 sm:p-8">
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-3">
                <span class={[
                  "size-3 rounded-full",
                  @status == :running && "bg-emerald-400",
                  @status != :running && "animate-pulse bg-amber-400"
                ]}>
                </span>
                <span id="worker-status" class="font-mono text-sm text-slate-300">
                  {status_label(@status)}
                </span>
              </div>
              <span id="restart-count" class="rounded-lg bg-white/10 px-3 py-1 font-mono text-xs">
                reinícios: {@restart_count}
              </span>
            </div>

            <dl class="mt-8 space-y-4 rounded-2xl border border-white/10 bg-white/5 p-5 font-mono text-sm">
              <div>
                <dt class="text-xs uppercase tracking-wider text-slate-500">PID atual</dt>
                <dd id="worker-pid" class="mt-1 break-all text-violet-300">{inspect(@pid)}</dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wider text-slate-500">Iniciado em</dt>
                <dd id="started-at" class="mt-1 text-slate-200">
                  {Calendar.strftime(@started_at, "%H:%M:%S.%f")}
                </dd>
              </div>
              <div>
                <dt class="text-xs uppercase tracking-wider text-slate-500">Estado na memória</dt>
                <dd id="job-count" class="mt-1 text-3xl font-black text-white">
                  {"%{jobs: #{@jobs}}"}
                </dd>
              </div>
            </dl>

            <div class="mt-5 grid gap-3 sm:grid-cols-2">
              <button
                id="do-work"
                phx-click="work"
                class="rounded-2xl bg-violet-500 px-5 py-4 font-bold transition hover:-translate-y-0.5 hover:bg-violet-400 focus:outline-none focus:ring-2 focus:ring-violet-300"
              >
                Simular trabalho
              </button>
              <button
                id="crash-worker"
                phx-click="crash"
                class="rounded-2xl bg-rose-500/15 px-5 py-4 font-bold text-rose-300 ring-1 ring-inset ring-rose-400/30 transition hover:-translate-y-0.5 hover:bg-rose-500/25 focus:outline-none focus:ring-2 focus:ring-rose-300"
              >
                Provocar crash
              </button>
            </div>
          </section>

          <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8 dark:border-white/10 dark:bg-slate-900">
            <h2 class="text-xl font-bold text-slate-950 dark:text-white">O que acontece no crash?</h2>
            <div class="mt-6 space-y-4">
              <.event
                label="1"
                title="O GenServer lança uma exceção"
                detail="O processo termina; os demais continuam funcionando."
              />
              <.event
                label="2"
                title="O Supervisor recebe o sinal EXIT"
                detail="A estratégia :one_for_one afeta somente este filho."
              />
              <.event
                label="3"
                title="Um novo processo é iniciado"
                detail="O PID muda e init/1 cria um estado novo."
              />
              <.event
                label="4"
                title="A interface acompanha o novo PID"
                detail="PubSub avisa a LiveView que o worker voltou."
              />
            </div>

            <div class="mt-7 rounded-2xl bg-amber-50 p-4 text-sm leading-6 text-amber-950 dark:bg-amber-500/10 dark:text-amber-100">
              Faça alguns trabalhos antes do crash. O contador volta a zero porque processos não persistem estado automaticamente.
            </div>

            <pre class="mt-5 overflow-x-auto rounded-2xl bg-slate-950 p-4 text-xs leading-6 text-slate-300"><code>children = [Lab.ResilientWorker]
    Supervisor.init(children, strategy: :one_for_one)</code></pre>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true

  defp event(assigns) do
    ~H"""
    <div class="flex gap-4">
      <span class="flex size-8 shrink-0 items-center justify-center rounded-full bg-slate-950 font-mono text-sm font-bold text-white dark:bg-violet-500">
        {@label}
      </span>
      <div>
        <p class="font-semibold text-slate-900 dark:text-white">{@title}</p>
        <p class="mt-1 text-sm leading-6 text-slate-500 dark:text-slate-400">{@detail}</p>
      </div>
    </div>
    """
  end

  defp monitor(socket, pid) when is_pid(pid) do
    Process.monitor(pid)
    socket
  end

  defp status_label(:running), do: "processo ativo"
  defp status_label(:crashing), do: "crash solicitado…"
  defp status_label(:restarting), do: "supervisor reiniciando…"
end
