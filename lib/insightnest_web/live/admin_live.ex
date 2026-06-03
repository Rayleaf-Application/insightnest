defmodule InsightnestWeb.AdminLive do
  use InsightnestWeb, :live_view

  alias Insightnest.Accounts
  alias Insightnest.Waitlist

  @impl true
  def mount(_params, %{"admin_authenticated" => true}, socket) do
    {:ok,
     socket
     |> assign(page_title: "Admin")
     |> assign(tab: :dashboard)
     |> assign(member_search: "")
     |> assign(waitlist_search: "")
     |> assign(notice: nil)
     |> load_data(),
     layout: false}
  end

  def mount(_params, _session, socket) do
    {:ok, push_navigate(socket, to: "/admin/login")}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) do
    {:noreply, assign(socket, tab: tab_atom(tab))}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: "/admin?tab=#{tab}")}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  def handle_event("grant_founder", %{"id" => id}, socket) do
    member = Accounts.get_member!(id)

    case Accounts.grant_founder_badge(member) do
      {:ok, _} ->
        {:noreply, socket |> load_data() |> set_notice(:ok, "Founder badge granted.")}

      {:error, _} ->
        {:noreply, set_notice(socket, :err, "Failed to grant founder badge.")}
    end
  end

  def handle_event("revoke_founder", %{"id" => id}, socket) do
    member = Accounts.get_member!(id)

    case Accounts.revoke_founder_badge(member) do
      {:ok, _} ->
        {:noreply, socket |> load_data() |> set_notice(:ok, "Founder badge revoked.")}

      {:error, _} ->
        {:noreply, set_notice(socket, :err, "Failed to revoke founder badge.")}
    end
  end

  def handle_event("waitlist_status", %{"id" => id, "status" => status}, socket) do
    case Waitlist.update_status(id, status) do
      {:ok, _} ->
        {:noreply, socket |> load_data() |> set_notice(:ok, "Marked #{status}.")}

      {:error, _} ->
        {:noreply, set_notice(socket, :err, "Failed to update status.")}
    end
  end

  def handle_event("waitlist_delete", %{"id" => id}, socket) do
    case Waitlist.delete(id) do
      {:ok, _} ->
        {:noreply, socket |> load_data() |> set_notice(:ok, "Entry deleted.")}

      {:error, _} ->
        {:noreply, set_notice(socket, :err, "Failed to delete entry.")}
    end
  end

  def handle_event("search_members", %{"value" => q}, socket) do
    {:noreply, assign(socket, member_search: q)}
  end

  def handle_event("search_waitlist", %{"value" => q}, socket) do
    {:noreply, assign(socket, waitlist_search: q)}
  end

  @impl true
  def handle_info(:clear_notice, socket) do
    {:noreply, assign(socket, notice: nil)}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp load_data(socket) do
    members = Accounts.list_members()
    waitlist = Waitlist.list()

    now = DateTime.utc_now()
    week_ago = DateTime.add(now, -7 * 86_400, :second)
    month_ago = DateTime.add(now, -30 * 86_400, :second)

    member_stats = %{
      total: length(members),
      founders: Enum.count(members, & &1.founder),
      wallet_auth: Enum.count(members, & &1.wallet_address),
      email_auth: Enum.count(members, &(is_nil(&1.wallet_address) && &1.email)),
      new_week: count_since(members, week_ago),
      new_month: count_since(members, month_ago)
    }

    waitlist_stats = %{
      total: length(waitlist),
      pending: Enum.count(waitlist, &(&1.status == "pending")),
      approved: Enum.count(waitlist, &(&1.status == "approved")),
      rejected: Enum.count(waitlist, &(&1.status == "rejected")),
      new_week: count_since(waitlist, week_ago)
    }

    growth = daily_counts(members, 14)
    waitlist_growth = daily_counts(waitlist, 14)

    assign(socket,
      members: members,
      waitlist: waitlist,
      member_stats: member_stats,
      waitlist_stats: waitlist_stats,
      growth: growth,
      waitlist_growth: waitlist_growth
    )
  end

  defp to_naive(%DateTime{} = dt), do: DateTime.to_naive(dt)
  defp to_naive(%NaiveDateTime{} = ndt), do: ndt

  defp to_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp to_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)

  defp count_since(items, cutoff) do
    cutoff_naive = DateTime.to_naive(cutoff)

    Enum.count(items, fn item ->
      NaiveDateTime.compare(to_naive(item.inserted_at), cutoff_naive) == :gt
    end)
  end

  defp daily_counts(items, days) do
    today = Date.utc_today()
    cutoff = Date.add(today, -days + 1)

    by_day =
      items
      |> Enum.filter(fn item ->
        Date.compare(to_date(item.inserted_at), cutoff) != :lt
      end)
      |> Enum.group_by(fn item -> to_date(item.inserted_at) end)
      |> Map.new(fn {date, list} -> {date, length(list)} end)

    Enum.map(0..(days - 1), fn offset ->
      date = Date.add(today, -offset)
      {date, Map.get(by_day, date, 0)}
    end)
  end

  defp tab_atom("waitlist"), do: :waitlist
  defp tab_atom("members"), do: :members
  defp tab_atom(_), do: :dashboard

  defp set_notice(socket, type, msg) do
    Process.send_after(self(), :clear_notice, 4000)
    assign(socket, notice: {type, msg})
  end

  defp filter_members(members, ""), do: members

  defp filter_members(members, q) do
    q = String.downcase(q)

    Enum.filter(members, fn m ->
      String.contains?(String.downcase(m.username || ""), q) ||
        String.contains?(String.downcase(m.email || ""), q) ||
        String.contains?(String.downcase(m.wallet_address || ""), q)
    end)
  end

  defp filter_waitlist(entries, ""), do: entries

  defp filter_waitlist(entries, q) do
    q = String.downcase(q)

    Enum.filter(entries, fn e ->
      String.contains?(String.downcase(e.email || ""), q) ||
        String.contains?(String.downcase(e.name || ""), q)
    end)
  end

  defp fmt_date(nil), do: "—"

  defp fmt_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%-d %b %Y")
  end

  defp fmt_date(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%-d %b %Y")
  end

  defp fmt_short_date(%Date{} = d) do
    Calendar.strftime(d, "%-d %b")
  end

  defp truncate_address(nil), do: "—"

  defp truncate_address(addr) when byte_size(addr) >= 10 do
    String.slice(addr, 0, 6) <> "…" <> String.slice(addr, -4, 4)
  end

  defp truncate_address(addr), do: addr

  # ── Render ────────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div style="background:#0c0a09;min-height:100vh;font-family:'DM Sans',system-ui,sans-serif;color:#d6d3d1;padding:2rem 1rem;">
      <div style="max-width:1000px;margin:0 auto;">

        <%!-- Header --%>
        <header style="display:flex;align-items:center;justify-content:space-between;margin-bottom:2rem;padding-bottom:1rem;border-bottom:1px solid #292524;">
          <div>
            <h1 style="font-size:1.25rem;font-weight:500;color:#f5f5f4;letter-spacing:-0.01em;">InsightNest — Admin</h1>
            <p style="font-size:0.72rem;color:#57534e;margin-top:0.2rem;">Management panel</p>
          </div>
          <div style="display:flex;gap:0.5rem;align-items:center;">
            <nav style="display:flex;gap:0.25rem;">
              <button phx-click="switch_tab" phx-value-tab="dashboard" style={nav_style(@tab == :dashboard)}>
                Dashboard
              </button>
              <button phx-click="switch_tab" phx-value-tab="waitlist" style={nav_style(@tab == :waitlist)}>
                Waitlist
                <span :if={@waitlist_stats.pending > 0} style="margin-left:0.35rem;background:#292524;color:#C9913A;border-radius:4px;padding:0.1rem 0.4rem;font-size:0.68rem;">
                  <%= @waitlist_stats.pending %>
                </span>
              </button>
              <button phx-click="switch_tab" phx-value-tab="members" style={nav_style(@tab == :members)}>
                Members
              </button>
            </nav>
            <button
              phx-click="refresh"
              style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;cursor:pointer;border:1px solid #292524;background:#1c1917;color:#78716c;font-family:inherit;"
            >
              ↺
            </button>
            <a
              href="/admin/logout"
              style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;text-decoration:none;border:1px solid #292524;color:#57534e;"
            >
              Sign out
            </a>
          </div>
        </header>

        <%!-- Notice --%>
        <%= if @notice do %>
          <% {type, msg} = @notice %>
          <div style={"padding:0.65rem 1rem;border-radius:8px;font-size:0.8rem;margin-bottom:1rem;#{notice_style(type)}"}>
            <%= msg %>
          </div>
        <% end %>

        <%!-- Dashboard --%>
        <div :if={@tab == :dashboard}>
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:1rem;margin-bottom:1.5rem;">
            <.stat_card label="Total Members" value={@member_stats.total} />
            <.stat_card label="Founders" value={@member_stats.founders} accent={true} />
            <.stat_card label="New (7 days)" value={@member_stats.new_week} />
            <.stat_card label="New (30 days)" value={@member_stats.new_month} />
          </div>

          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:1rem;margin-bottom:2rem;">
            <.stat_card label="Waitlist Total" value={@waitlist_stats.total} />
            <.stat_card label="Pending" value={@waitlist_stats.pending} />
            <.stat_card label="Approved" value={@waitlist_stats.approved} />
            <.stat_card label="Rejected" value={@waitlist_stats.rejected} />
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin-bottom:2rem;">
            <div style={card_style()}>
              <h2 style={section_heading_style()}>Auth Method</h2>
              <%= if @member_stats.total > 0 do %>
                <% wallet_pct = Float.round(@member_stats.wallet_auth / @member_stats.total * 100, 1) %>
                <% email_pct = Float.round(@member_stats.email_auth / @member_stats.total * 100, 1) %>
                <div style="display:flex;flex-direction:column;gap:0.75rem;">
                  <div>
                    <div style="display:flex;justify-content:space-between;font-size:0.8rem;margin-bottom:0.3rem;">
                      <span>Wallet (crypto)</span>
                      <span style="color:#f5f5f4;font-weight:500;"><%= @member_stats.wallet_auth %> (<%= wallet_pct %>%)</span>
                    </div>
                    <div style="height:6px;background:#292524;border-radius:3px;overflow:hidden;">
                      <div style={"height:100%;background:#C9913A;border-radius:3px;width:#{wallet_pct}%;"} />
                    </div>
                  </div>
                  <div>
                    <div style="display:flex;justify-content:space-between;font-size:0.8rem;margin-bottom:0.3rem;">
                      <span>Email</span>
                      <span style="color:#f5f5f4;font-weight:500;"><%= @member_stats.email_auth %> (<%= email_pct %>%)</span>
                    </div>
                    <div style="height:6px;background:#292524;border-radius:3px;overflow:hidden;">
                      <div style={"height:100%;background:#78716c;border-radius:3px;width:#{email_pct}%;"} />
                    </div>
                  </div>
                </div>
              <% else %>
                <p style="font-size:0.8rem;color:#57534e;">No members yet.</p>
              <% end %>
            </div>

            <div style={card_style()}>
              <h2 style={section_heading_style()}>Waitlist Funnel</h2>
              <%= if @waitlist_stats.total > 0 do %>
                <% conv = Float.round(@waitlist_stats.approved / @waitlist_stats.total * 100, 1) %>
                <div style="font-size:0.8rem;display:flex;flex-direction:column;gap:0.6rem;">
                  <div style="display:flex;justify-content:space-between;">
                    <span style="color:#78716c;">Total signups</span>
                    <span style="color:#f5f5f4;font-weight:500;"><%= @waitlist_stats.total %></span>
                  </div>
                  <div style="display:flex;justify-content:space-between;">
                    <span style="color:#78716c;">Approved</span>
                    <span style="color:#4ade80;font-weight:500;"><%= @waitlist_stats.approved %></span>
                  </div>
                  <div style="display:flex;justify-content:space-between;">
                    <span style="color:#78716c;">Conversion rate</span>
                    <span style="color:#C9913A;font-weight:500;"><%= conv %>%</span>
                  </div>
                  <div style="display:flex;justify-content:space-between;">
                    <span style="color:#78716c;">New this week</span>
                    <span style="color:#f5f5f4;font-weight:500;">+<%= @waitlist_stats.new_week %></span>
                  </div>
                </div>
              <% else %>
                <p style="font-size:0.8rem;color:#57534e;">No waitlist entries yet.</p>
              <% end %>
            </div>
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;margin-bottom:2rem;">
            <.growth_chart title="Member Signups — Last 14 Days" data={@growth} />
            <.growth_chart title="Waitlist Signups — Last 14 Days" data={@waitlist_growth} />
          </div>

          <div style="display:grid;grid-template-columns:1fr 1fr;gap:1rem;">
            <div style={card_style()}>
              <h2 style={section_heading_style()}>Recent Members</h2>
              <%= if Enum.empty?(@members) do %>
                <p style="font-size:0.8rem;color:#57534e;">No members yet.</p>
              <% else %>
                <div style="display:flex;flex-direction:column;gap:0.6rem;">
                  <%= for m <- Enum.take(Enum.sort_by(@members, & &1.inserted_at, {:desc, DateTime}), 5) do %>
                    <div style="display:flex;justify-content:space-between;align-items:center;font-size:0.8rem;">
                      <span style="font-family:'DM Mono',monospace;color:#e7e5e4;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:65%;">
                        <%= if m.username, do: "@#{m.username}", else: truncate_address(m.wallet_address || m.email) %>
                      </span>
                      <span style="font-size:0.72rem;color:#57534e;flex-shrink:0;"><%= fmt_date(m.inserted_at) %></span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>

            <div style={card_style()}>
              <h2 style={section_heading_style()}>Recent Waitlist</h2>
              <%= if Enum.empty?(@waitlist) do %>
                <p style="font-size:0.8rem;color:#57534e;">No waitlist entries yet.</p>
              <% else %>
                <div style="display:flex;flex-direction:column;gap:0.6rem;">
                  <%= for e <- Enum.take(@waitlist, 5) do %>
                    <div style="display:flex;justify-content:space-between;align-items:center;font-size:0.8rem;">
                      <span style="font-family:'DM Mono',monospace;color:#e7e5e4;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:65%;"><%= e.email %></span>
                      <span style={"font-size:0.7rem;padding:0.15rem 0.45rem;border-radius:5px;font-weight:500;#{chip_style(e.status)}"}>
                        <%= e.status %>
                      </span>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <%!-- Waitlist tab --%>
        <div :if={@tab == :waitlist}>
          <div style="display:flex;gap:0.5rem;margin-bottom:1rem;align-items:center;">
            <input
              type="text"
              placeholder="Filter by email or name…"
              value={@waitlist_search}
              phx-keyup="search_waitlist"
              id="waitlist-search"
              style="flex:1;background:#1c1917;border:1px solid #292524;border-radius:8px;padding:0.45rem 0.75rem;color:#e7e5e4;font-size:0.8rem;font-family:inherit;outline:none;"
            />
            <span style="font-size:0.75rem;color:#57534e;white-space:nowrap;">
              <%= length(filter_waitlist(@waitlist, @waitlist_search)) %> / <%= @waitlist_stats.total %>
            </span>
          </div>

          <div style="border:1px solid #292524;border-radius:12px;overflow:hidden;">
            <table style="width:100%;border-collapse:collapse;font-size:0.8rem;">
              <thead style="background:#1c1917;">
                <tr>
                  <th style={th_style()}>Email</th>
                  <th style={th_style()}>Name</th>
                  <th style={th_style()}>Reason</th>
                  <th style={th_style()}>Status</th>
                  <th style={th_style()}>Joined</th>
                  <th style={th_style()}></th>
                </tr>
              </thead>
              <tbody>
                <%= if Enum.empty?(filter_waitlist(@waitlist, @waitlist_search)) do %>
                  <tr>
                    <td colspan="6" style="text-align:center;padding:3rem;color:#57534e;font-size:0.85rem;">
                      <%= if @waitlist == [], do: "No waitlist entries yet.", else: "No entries match your filter." %>
                    </td>
                  </tr>
                <% else %>
                  <%= for e <- filter_waitlist(@waitlist, @waitlist_search) do %>
                    <tr style="border-bottom:1px solid #1c1917;">
                      <td style="padding:0.75rem 1rem;font-family:'DM Mono',monospace;font-size:0.75rem;color:#e7e5e4;"><%= e.email %></td>
                      <td style="padding:0.75rem 1rem;color:#d6d3d1;"><%= e.name || "—" %></td>
                      <td style="padding:0.75rem 1rem;color:#78716c;font-size:0.75rem;max-width:180px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;" title={e.reason || ""}><%= e.reason || "—" %></td>
                      <td style="padding:0.75rem 1rem;">
                        <span style={"display:inline-flex;align-items:center;padding:0.2rem 0.55rem;border-radius:6px;font-size:0.7rem;font-weight:500;#{chip_style(e.status)}"}>
                          <%= e.status %>
                        </span>
                      </td>
                      <td style="padding:0.75rem 1rem;font-size:0.72rem;color:#57534e;"><%= fmt_date(e.inserted_at) %></td>
                      <td style="padding:0.75rem 1rem;">
                        <div style="display:flex;gap:0.4rem;">
                          <%= if e.status != "approved" do %>
                            <button
                              phx-click="waitlist_status"
                              phx-value-id={e.id}
                              phx-value-status="approved"
                              style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;cursor:pointer;background:#052e16;border:1px solid #14532d;color:#4ade80;font-family:inherit;"
                            >
                              Approve
                            </button>
                          <% end %>
                          <%= if e.status != "rejected" do %>
                            <button
                              phx-click="waitlist_status"
                              phx-value-id={e.id}
                              phx-value-status="rejected"
                              style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;cursor:pointer;background:#1c0a0a;border:1px solid #7f1d1d;color:#f87171;font-family:inherit;"
                            >
                              Reject
                            </button>
                          <% end %>
                          <button
                            phx-click="waitlist_delete"
                            phx-value-id={e.id}
                            data-confirm="Remove this entry?"
                            style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;cursor:pointer;background:transparent;border:1px solid #292524;color:#57534e;font-family:inherit;"
                          >
                            ✕
                          </button>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Members tab --%>
        <div :if={@tab == :members}>
          <div style="display:flex;gap:0.5rem;margin-bottom:1rem;align-items:center;">
            <input
              type="text"
              placeholder="Filter by username, email, or wallet…"
              value={@member_search}
              phx-keyup="search_members"
              id="members-search"
              style="flex:1;background:#1c1917;border:1px solid #292524;border-radius:8px;padding:0.45rem 0.75rem;color:#e7e5e4;font-size:0.8rem;font-family:inherit;outline:none;"
            />
            <span style="font-size:0.75rem;color:#57534e;white-space:nowrap;">
              {length(filter_members(@members, @member_search))} / {@member_stats.total}
            </span>
          </div>

          <div style="border:1px solid #292524;border-radius:12px;overflow:hidden;">
            <table style="width:100%;border-collapse:collapse;font-size:0.8rem;">
              <thead style="background:#1c1917;">
                <tr>
                  <th style={th_style()}>Username</th>
                  <th style={th_style()}>Identity</th>
                  <th style={th_style()}>Badge</th>
                  <th style={th_style()}>Joined</th>
                  <th style={th_style()}></th>
                </tr>
              </thead>
              <tbody>
                <%= if Enum.empty?(filter_members(@members, @member_search)) do %>
                  <tr>
                    <td
                      colspan="5"
                      style="text-align:center;padding:3rem;color:#57534e;font-size:0.85rem;"
                    >
                      {if @members == [], do: "No members yet.", else: "No members match your filter."}
                    </td>
                  </tr>
                <% else %>
                  <%= for m <- filter_members(@members, @member_search) do %>
                    <tr style="border-bottom:1px solid #1c1917;">
                      <td style="padding:0.75rem 1rem;font-family:'DM Mono',monospace;color:#e7e5e4;">
                        <%= if m.username do %>
                          @{m.username}
                        <% else %>
                          <span style="color:#44403c;font-size:0.72rem;">no username</span>
                        <% end %>
                      </td>
                      <td style="padding:0.75rem 1rem;font-family:'DM Mono',monospace;font-size:0.75rem;color:#57534e;">
                        {truncate_address(m.wallet_address || m.email)}
                      </td>
                      <td style="padding:0.75rem 1rem;">
                        <%= if m.founder do %>
                          <span style="display:inline-flex;align-items:center;gap:0.25rem;padding:0.2rem 0.55rem;border-radius:6px;font-size:0.7rem;font-weight:500;background:rgba(201,145,58,0.12);color:#C9913A;border:1px solid rgba(201,145,58,0.35);">
                            ✦ Founder
                          </span>
                        <% else %>
                          <span style="font-size:0.72rem;color:#44403c;">—</span>
                        <% end %>
                      </td>
                      <td style="padding:0.75rem 1rem;font-size:0.72rem;color:#57534e;">
                        {fmt_date(m.inserted_at)}
                      </td>
                      <td style="padding:0.75rem 1rem;">
                        <%= if m.founder do %>
                          <button
                            phx-click="revoke_founder"
                            phx-value-id={m.id}
                            style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;cursor:pointer;background:#1c1917;border:1px solid #292524;color:#78716c;font-family:inherit;"
                          >
                            Revoke
                          </button>
                        <% else %>
                          <button
                            phx-click="grant_founder"
                            phx-value-id={m.id}
                            style="padding:0.3rem 0.65rem;border-radius:7px;font-size:0.72rem;cursor:pointer;background:rgba(201,145,58,0.1);border:1px solid rgba(201,145,58,0.35);color:#C9913A;font-family:inherit;"
                          >
                            Grant Founder
                          </button>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>

      </div>
    </div>
    """
  end

  # ── Private function components ───────────────────────────────────────────────

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :accent, :boolean, default: false

  defp stat_card(assigns) do
    ~H"""
    <div style="background:#1c1917;border:1px solid #292524;border-radius:12px;padding:1.25rem 1.5rem;">
      <p style="font-size:0.72rem;font-weight:500;color:#78716c;text-transform:uppercase;letter-spacing:0.08em;margin-bottom:0.5rem;">
        {@label}
      </p>
      <p style={"font-size:1.75rem;font-weight:500;letter-spacing:-0.02em;#{if @accent, do: "color:#C9913A;", else: "color:#f5f5f4;"}"}>
        {@value}
      </p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :data, :list, required: true

  defp growth_chart(assigns) do
    ~H"""
    <div style="background:#1c1917;border:1px solid #292524;border-radius:12px;padding:1.25rem 1.5rem;">
      <h2 style="font-size:0.72rem;font-weight:500;color:#78716c;text-transform:uppercase;letter-spacing:0.08em;margin-bottom:1rem;">
        {@title}
      </h2>
      <%= if Enum.all?(@data, fn {_, n} -> n == 0 end) do %>
        <p style="font-size:0.8rem;color:#57534e;">No activity in this period.</p>
      <% else %>
        <% max_val = @data |> Enum.map(fn {_, n} -> n end) |> Enum.max() |> max(1) %>
        <div style="display:flex;flex-direction:column;gap:0.3rem;">
          <%= for {date, count} <- Enum.take(@data, 7) do %>
            <div style="display:flex;align-items:center;gap:0.5rem;font-size:0.72rem;">
              <span style="width:3.25rem;color:#57534e;flex-shrink:0;text-align:right;font-family:'DM Mono',monospace;">
                {fmt_short_date(date)}
              </span>
              <div style="flex:1;height:8px;background:#292524;border-radius:4px;overflow:hidden;">
                <div style={"height:100%;background:#C9913A;border-radius:4px;width:#{Float.round(count / max_val * 100, 1)}%;min-width:#{if count > 0, do: "3px", else: "0"};"} />
              </div>
              <span style="width:1.5rem;color:#78716c;flex-shrink:0;text-align:right;">{count}</span>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Style helpers ─────────────────────────────────────────────────────────────

  defp nav_style(active) do
    base =
      "padding:0.35rem 0.85rem;border-radius:8px;font-size:0.8rem;cursor:pointer;border:1px solid transparent;font-family:inherit;background:none;"

    if active do
      base <> "border-color:#292524;color:#f5f5f4;background:#1c1917;"
    else
      base <> "color:#78716c;"
    end
  end

  defp card_style do
    "background:#1c1917;border:1px solid #292524;border-radius:12px;padding:1.25rem 1.5rem;"
  end

  defp section_heading_style do
    "font-size:0.72rem;font-weight:500;color:#78716c;text-transform:uppercase;letter-spacing:0.08em;margin-bottom:1rem;"
  end

  defp th_style do
    "padding:0.7rem 1rem;text-align:left;color:#78716c;font-weight:500;font-size:0.72rem;text-transform:uppercase;letter-spacing:0.06em;border-bottom:1px solid #292524;"
  end

  defp chip_style("approved"), do: "background:#052e16;color:#4ade80;border:1px solid #14532d;"
  defp chip_style("rejected"), do: "background:#1c0a0a;color:#f87171;border:1px solid #7f1d1d;"
  defp chip_style(_), do: "background:#292524;color:#78716c;border:1px solid #44403c;"

  defp notice_style(:ok), do: "background:#052e16;border:1px solid #14532d;color:#4ade80;"
  defp notice_style(:err), do: "background:#1c0a0a;border:1px solid #7f1d1d;color:#f87171;"
end
