defmodule LabWeb.ContactLive do
  use LabWeb, :live_view

  alias Lab.{Contact, ContactMessage}

  @impl true
  def mount(_params, _session, socket) do
    peer_data = get_connect_info(socket, :peer_data)
    rate_key = {:demo, peer_data && peer_data.address}

    {:ok,
     socket
     |> assign(:page_title, "Contato")
     |> assign(:rate_key, rate_key)
     |> assign(:sent?, false)
     |> assign(:form, empty_form())}
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    form =
      params
      |> ContactMessage.changeset()
      |> Map.put(:action, :validate)
      |> to_form(as: :contact)

    {:noreply, assign(socket, form: form, sent?: false)}
  end

  @impl true
  def handle_event("send", %{"contact" => params}, socket) do
    case Contact.send_message(params, socket.assigns.rate_key) do
      {:ok, _} ->
        {:noreply, assign(socket, form: empty_form(), sent?: true)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(%{changeset | action: :insert}, as: :contact))}

      {:error, :rate_limited} ->
        {:noreply,
         put_flash(socket, :error, "Limite de envios atingido. Tente novamente mais tarde.")}

      {:error, :delivery_failed} ->
        {:noreply, put_flash(socket, :error, "Não foi possível enviar agora. Tente novamente.")}
    end
  end

  defp empty_form do
    ContactMessage.changeset(%{}) |> to_form(as: :contact)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="contact-demo" class="mx-auto max-w-5xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="max-w-2xl">
          <p class="text-xs font-bold uppercase text-emerald-700 dark:text-emerald-400">
            Exemplo Phoenix
          </p>
          <h1 class="mt-3 text-3xl font-bold text-slate-950 sm:text-4xl dark:text-white">
            Envie uma mensagem
          </h1>
          <p class="mt-3 text-base leading-7 text-slate-600 dark:text-slate-300">
            Preencha o formulário para entrar em contato.
          </p>
        </header>

        <div class="mt-8 grid gap-10 lg:grid-cols-[minmax(0,1.3fr)_minmax(220px,0.7fr)]">
          <section class="rounded-md border border-slate-200 bg-white p-6 shadow-sm sm:p-8 dark:border-slate-700 dark:bg-slate-900">
            <div
              :if={@sent?}
              id="contact-success"
              role="status"
              class="mb-6 flex items-start gap-3 rounded-md border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900 dark:border-emerald-900 dark:bg-emerald-950 dark:text-emerald-200"
            >
              <.icon name="hero-check-circle" class="size-5 shrink-0" />
              <span>Mensagem recebida. Obrigado pelo contato.</span>
            </div>

            <.form
              for={@form}
              id="contact-form"
              phx-change="validate"
              phx-submit="send"
              class="space-y-4"
            >
              <div class="grid gap-4 sm:grid-cols-2">
                <.input
                  field={@form[:name]}
                  type="text"
                  label="Nome"
                  autocomplete="name"
                  maxlength="120"
                  required
                />
                <.input
                  field={@form[:email]}
                  type="email"
                  label="E-mail"
                  autocomplete="email"
                  maxlength="254"
                  required
                />
              </div>
              <.input field={@form[:subject]} type="text" label="Assunto" maxlength="150" required />
              <.input
                field={@form[:message]}
                type="textarea"
                label="Mensagem"
                rows="7"
                maxlength="5000"
                required
              />

              <div class="sr-only" aria-hidden="true">
                <.input
                  field={@form[:website]}
                  type="text"
                  label="Site"
                  autocomplete="off"
                  tabindex="-1"
                />
              </div>

              <button
                id="contact-submit"
                type="submit"
                phx-disable-with="Enviando..."
                class="inline-flex min-h-11 items-center gap-2 rounded-md bg-emerald-700 px-5 py-2.5 font-semibold text-white transition hover:bg-emerald-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-emerald-600 disabled:opacity-60"
              >
                <.icon name="hero-paper-airplane" class="size-4" /> Enviar mensagem
              </button>
            </.form>
          </section>

          <aside class="self-start border-t border-slate-200 pt-6 text-sm leading-6 text-slate-600 lg:border-t-0 lg:border-l lg:pt-0 lg:pl-8 dark:border-slate-700 dark:text-slate-300">
            <h2 class="font-semibold text-slate-900 dark:text-white">Envio privado</h2>
            <p class="mt-2">
              A mensagem é entregue ao endereço configurado no servidor. Seu e-mail é usado apenas
              para responder a este contato.
            </p>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
