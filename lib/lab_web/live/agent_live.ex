defmodule LabWeb.AgentLive do
  use LabWeb, :live_view

  @products [
    %{name: "Café especial", price: 1850, icon: "hero-beaker"},
    %{name: "Pão de queijo", price: 700, icon: "hero-fire"},
    %{name: "Bolo de cenoura", price: 1250, icon: "hero-cake"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Laboratório Agent", products: @products)
     |> refresh_cart()}
  end

  @impl true
  def handle_event("add", %{"index" => index}, socket) do
    product = Enum.at(@products, String.to_integer(index))
    Lab.Cart.add(product.name, product.price)

    {:noreply, refresh_cart(socket)}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    Lab.Cart.remove(String.to_integer(id))
    {:noreply, refresh_cart(socket)}
  end

  def handle_event("clear", _params, socket) do
    Lab.Cart.clear()
    {:noreply, refresh_cart(socket)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main id="agent-lab" class="mx-auto max-w-6xl px-4 py-10 sm:px-6 lg:py-16">
        <header class="max-w-3xl">
          <span class="inline-flex items-center rounded-full bg-emerald-100 px-3 py-1 text-xs font-bold uppercase tracking-[0.18em] text-emerald-700 dark:bg-emerald-500/15 dark:text-emerald-300">
            Elixir • OTP
          </span>
          <h1 class="mt-5 text-4xl font-black tracking-tight text-slate-950 sm:text-6xl dark:text-white">
            Agent na prática
          </h1>
          <p class="mt-4 max-w-2xl text-lg leading-8 text-slate-600 dark:text-slate-300">
            Um carrinho simples cujo estado vive em um processo supervisionado, e não na página.
          </p>
        </header>

        <div class="mt-10 grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
          <section aria-labelledby="products-title">
            <div class="flex items-end justify-between gap-4">
              <div>
                <p class="text-sm font-semibold text-emerald-600 dark:text-emerald-400">Cardápio</p>
                <h2 id="products-title" class="mt-1 text-2xl font-bold text-slate-950 dark:text-white">
                  Escolha um item
                </h2>
              </div>
              <span class="font-mono text-xs text-slate-500">Agent.update/2</span>
            </div>

            <div id="products" class="mt-5 grid gap-4 sm:grid-cols-3">
              <article
                :for={{product, index} <- Enum.with_index(@products)}
                id={"product-#{index}"}
                class="group rounded-3xl border border-slate-200 bg-white p-5 shadow-sm transition duration-200 hover:-translate-y-1 hover:border-emerald-300 hover:shadow-lg dark:border-white/10 dark:bg-slate-900 dark:hover:border-emerald-500/50"
              >
                <div class="flex size-11 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600 transition group-hover:bg-emerald-500 group-hover:text-white dark:bg-emerald-500/10 dark:text-emerald-300">
                  <.icon name={product.icon} class="size-5" />
                </div>
                <h3 class="mt-5 font-bold text-slate-900 dark:text-white">{product.name}</h3>
                <p class="mt-1 font-mono text-sm text-slate-500">{money(product.price)}</p>
                <button
                  id={"add-product-#{index}"}
                  type="button"
                  phx-click="add"
                  phx-value-index={index}
                  class="mt-5 w-full rounded-xl bg-slate-950 px-3 py-2.5 text-sm font-bold text-white transition hover:bg-emerald-600 focus:outline-none focus:ring-2 focus:ring-emerald-400 focus:ring-offset-2 dark:bg-white dark:text-slate-950 dark:hover:bg-emerald-300"
                >
                  Adicionar
                </button>
              </article>
            </div>

            <div class="mt-6 rounded-2xl border border-emerald-200 bg-emerald-50 p-5 text-sm leading-6 text-emerald-950 dark:border-emerald-500/20 dark:bg-emerald-500/10 dark:text-emerald-100">
              <strong>Experimente:</strong>
              adicione itens e recarregue a página. O carrinho permanece porque pertence ao processo <code class="font-mono">Lab.Cart</code>.
            </div>
          </section>

          <section class="overflow-hidden rounded-3xl bg-slate-950 text-white shadow-2xl shadow-emerald-950/20">
            <div class="flex items-center justify-between border-b border-white/10 px-6 py-5 sm:px-7">
              <div class="flex items-center gap-3">
                <span class="relative flex size-3">
                  <span class="absolute inline-flex size-full animate-ping rounded-full bg-emerald-400 opacity-60">
                  </span>
                  <span class="relative inline-flex size-3 rounded-full bg-emerald-400"></span>
                </span>
                <h2 class="font-bold">Estado do Agent</h2>
              </div>
              <span
                id="cart-count"
                class="rounded-full bg-white/10 px-3 py-1 font-mono text-xs text-slate-300"
              >
                {@item_count} {if @item_count == 1, do: "item", else: "itens"}
              </span>
            </div>

            <div id="cart-items" class="min-h-64 px-6 py-3 sm:px-7">
              <div
                :if={@items == []}
                id="empty-cart"
                class="flex min-h-56 flex-col items-center justify-center text-center"
              >
                <div class="flex size-14 items-center justify-center rounded-2xl bg-white/5 text-slate-400">
                  <.icon name="hero-shopping-bag" class="size-7" />
                </div>
                <p class="mt-4 font-semibold text-slate-300">O estado ainda é uma lista vazia</p>
                <code class="mt-2 text-xs text-slate-500">[]</code>
              </div>

              <div
                :for={item <- @items}
                id={"cart-item-#{item.id}"}
                class="flex items-center gap-4 border-b border-white/10 py-4 last:border-0"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate font-semibold">{item.product}</p>
                  <p class="mt-1 font-mono text-xs text-slate-400">{item_state(item)}</p>
                </div>
                <span class="font-mono text-sm text-emerald-300">{money(item.price)}</span>
                <button
                  id={"remove-item-#{item.id}"}
                  type="button"
                  phx-click="remove"
                  phx-value-id={item.id}
                  aria-label={"Remover #{item.product}"}
                  class="rounded-lg p-2 text-slate-500 transition hover:bg-white/10 hover:text-rose-300 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>
            </div>

            <footer class="border-t border-white/10 bg-white/[0.03] px-6 py-6 sm:px-7">
              <div class="flex items-end justify-between">
                <span class="text-sm text-slate-400">Agent.get/2 → total</span>
                <output id="cart-total" class="font-mono text-3xl font-black tracking-tight">
                  {money(@total)}
                </output>
              </div>
              <button
                id="clear-cart"
                type="button"
                phx-click="clear"
                disabled={@items == []}
                class="mt-5 w-full rounded-xl border border-white/15 px-4 py-3 text-sm font-bold transition hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-40"
              >
                Limpar carrinho
              </button>
            </footer>
          </section>
        </div>
      </main>
    </Layouts.app>
    """
  end

  defp refresh_cart(socket) do
    items = Lab.Cart.items()

    assign(socket,
      items: items,
      item_count: length(items),
      total: Lab.Cart.total()
    )
  end

  defp money(cents) do
    reais = div(cents, 100)
    centavos = cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")
    "R$ #{reais},#{centavos}"
  end

  defp item_state(item), do: "%{id: #{item.id}, price: #{item.price}}"
end
