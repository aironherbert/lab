defmodule LabWeb.CheckoutCartLive do
  use LabWeb, :live_view

  @products [
    %{name: "Teclado mecânico", price: 32_990},
    %{name: "Mouse sem fio", price: 18_490},
    %{name: "Suporte para notebook", price: 12_900}
  ]

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Lab.CheckoutCart.subscribe()

    {:ok,
     assign(socket,
       page_title: "Carrinho com GenServer",
       products: @products,
       cart: Lab.CheckoutCart.snapshot()
     )}
  end

  @impl true
  def handle_event("add", %{"index" => index}, socket) do
    product = Enum.at(@products, String.to_integer(index))
    _result = Lab.CheckoutCart.add(product.name, product.price)
    {:noreply, assign(socket, cart: Lab.CheckoutCart.snapshot())}
  end

  def handle_event("checkout", _params, socket) do
    _result = Lab.CheckoutCart.checkout()
    {:noreply, assign(socket, cart: Lab.CheckoutCart.snapshot())}
  end

  def handle_event("clear", _params, socket) do
    _result = Lab.CheckoutCart.clear()
    {:noreply, assign(socket, cart: Lab.CheckoutCart.snapshot())}
  end

  @impl true
  def handle_info({:checkout_cart_updated, cart}, socket),
    do: {:noreply, assign(socket, cart: cart)}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main id="checkout-cart-lab" class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="max-w-3xl">
          <span class="inline-flex rounded-full bg-amber-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.18em] text-amber-800 dark:bg-amber-500/15 dark:text-amber-300">
            GenServer + Task
          </span>
          <h1 class="mt-5 text-4xl font-black tracking-tight text-slate-950 sm:text-6xl dark:text-white">
            Checkout sem bloquear
          </h1>
          <p class="mt-4 text-lg leading-8 text-slate-600 dark:text-slate-300">
            Reserva de estoque e pagamento são demorados. Uma Task faz o trabalho; o GenServer coordena cada etapa por mensagens.
          </p>
          <.link
            navigate={~p"/agent"}
            class="mt-4 inline-flex font-semibold text-amber-700 hover:text-amber-600 dark:text-amber-300"
          >
            Comparar com o carrinho usando Agent →
          </.link>
        </header>

        <div class="mt-10 grid gap-6 lg:grid-cols-[1fr_1.05fr]">
          <section id="checkout-products" class="grid gap-4 sm:grid-cols-3 lg:grid-cols-1">
            <article
              :for={{product, index} <- Enum.with_index(@products)}
              id={"checkout-product-#{index}"}
              class="flex items-center gap-4 rounded-2xl border border-slate-200 bg-white p-4 shadow-sm dark:border-white/10 dark:bg-slate-900"
            >
              <div class="flex size-11 shrink-0 items-center justify-center rounded-xl bg-amber-100 text-amber-700 dark:bg-amber-500/10 dark:text-amber-300">
                <.icon name="hero-cube" class="size-5" />
              </div>
              <div class="min-w-0 flex-1">
                <h2 class="font-bold text-slate-900 dark:text-white">{product.name}</h2>
                <p class="font-mono text-sm text-slate-500">{money(product.price)}</p>
              </div>
              <button
                id={"checkout-add-#{index}"}
                phx-click="add"
                phx-value-index={index}
                disabled={processing?(@cart.status)}
                class="rounded-xl bg-slate-950 px-4 py-2 text-sm font-bold text-white transition hover:-translate-y-0.5 hover:bg-amber-600 disabled:cursor-not-allowed disabled:opacity-40 dark:bg-white dark:text-slate-950"
              >
                Adicionar
              </button>
            </article>
          </section>

          <section class="overflow-hidden rounded-3xl bg-slate-950 text-white shadow-2xl shadow-amber-950/20">
            <header class="flex items-center justify-between border-b border-white/10 px-6 py-5">
              <h2 class="font-bold">Máquina de estados</h2>
              <span id="checkout-status" class={status_class(@cart.status)}>
                {status_label(@cart.status)}
              </span>
            </header>

            <div class="grid grid-cols-3 border-b border-white/10 px-6 py-5 text-center text-xs">
              <.stage
                label="1. Estoque"
                active={@cart.status == :reserving_stock}
                done={@cart.status in [:charging_payment, :completed]}
              />
              <.stage
                label="2. Pagamento"
                active={@cart.status == :charging_payment}
                done={@cart.status == :completed}
              />
              <.stage label="3. Conclusão" active={@cart.status == :completed} done={false} />
            </div>

            <div id="checkout-items" class="min-h-48 px-6 py-4">
              <p
                :if={@cart.items == [] && is_nil(@cart.order)}
                id="checkout-empty"
                class="py-14 text-center text-slate-500"
              >
                Adicione produtos para iniciar.
              </p>
              <div
                :for={item <- @cart.items}
                id={"checkout-item-#{item.id}"}
                class="flex justify-between border-b border-white/10 py-3 last:border-0"
              >
                <span>{item.product}</span><span class="font-mono text-amber-300">{money(item.price)}</span>
              </div>
              <div :if={@cart.order} id="checkout-order" class="py-8 text-center">
                <.icon name="hero-check-circle" class="mx-auto size-12 text-emerald-400" />
                <p class="mt-3 text-xl font-black">Pedido aprovado</p>
                <p class="mt-1 font-mono text-sm text-slate-400">{@cart.order.id}</p>
              </div>
            </div>

            <footer class="border-t border-white/10 bg-white/[0.03] px-6 py-5">
              <div class="flex items-center justify-between">
                <span class="text-sm text-slate-400">Total</span>
                <output id="checkout-total" class="font-mono text-2xl font-black">
                  {money(total(@cart))}
                </output>
              </div>
              <div class="mt-4 grid grid-cols-[auto_1fr] gap-3">
                <button
                  id="checkout-clear"
                  phx-click="clear"
                  disabled={processing?(@cart.status)}
                  class="rounded-xl border border-white/15 px-4 py-3 text-sm font-bold transition hover:bg-white/10 disabled:opacity-40"
                >
                  Limpar
                </button>
                <button
                  id="start-checkout"
                  phx-click="checkout"
                  disabled={@cart.items == [] || processing?(@cart.status)}
                  class="rounded-xl bg-amber-500 px-4 py-3 font-bold text-slate-950 transition hover:bg-amber-400 disabled:cursor-not-allowed disabled:opacity-40"
                >
                  {if processing?(@cart.status), do: "Processando…", else: "Finalizar compra"}
                </button>
              </div>
              <p id="server-responsive" class="mt-4 text-center font-mono text-xs text-slate-500">
                GenServer.call(:snapshot) continua respondendo durante o checkout
              </p>
            </footer>
          </section>
        </div>
      </main>
    </Layouts.app>
    """
  end

  attr :label, :string, required: true
  attr :active, :boolean, required: true
  attr :done, :boolean, required: true

  defp stage(assigns) do
    ~H"""
    <div class="flex flex-col items-center gap-2 text-slate-500">
      <span class={[
        "size-2.5 rounded-full transition",
        @active && "animate-pulse bg-amber-400 ring-4 ring-amber-400/20",
        @done && "bg-emerald-400",
        !@active && !@done && "bg-slate-700"
      ]}>
      </span>
      <span class={[@active && "font-bold text-amber-300", @done && "text-emerald-300"]}>
        {@label}
      </span>
    </div>
    """
  end

  defp processing?(status), do: status in [:starting, :reserving_stock, :charging_payment]
  defp total(%{order: order}) when not is_nil(order), do: order.total
  defp total(cart), do: Enum.sum_by(cart.items, & &1.price)

  defp money(cents),
    do:
      "R$ #{div(cents, 100)},#{cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")}"

  defp status_label(:open), do: "Aberto"
  defp status_label(:starting), do: "Iniciando"
  defp status_label(:reserving_stock), do: "Reservando estoque"
  defp status_label(:charging_payment), do: "Processando pagamento"
  defp status_label(:completed), do: "Concluído"

  defp status_class(status),
    do: [
      "rounded-full px-3 py-1 text-xs font-bold",
      if(processing?(status),
        do: "bg-amber-400/15 text-amber-300",
        else: "bg-emerald-400/15 text-emerald-300"
      )
    ]
end
