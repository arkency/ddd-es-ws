# Co-work: a context map in code

A finished demo for the workshop. It turns the co-work context map (and the event storming
behind it) into one small Rails monolith, so you can show how each line of the diagram
looks in code.

```
cd demo
bundle install
bin/server            # http://localhost:3000  (PORT=… to change)
bin/reset             # wipe all events and read models
bundle exec ruby -Itest test/flows_test.rb
```

Pages:

- `/`: dashboard with one panel per bounded context except Availability. Each form calls `<Context>::Commands` of exactly one context. A banner names the next step of the demo flow, and the matching panel and submit button are highlighted.
- `/scenarios`: predefined runs (desk end to end, negotiated room, payment timeout, failing downstream, sync coupling) next to the dashboard. Each step is one `<Context>::Commands` call; the runner waits for the edges, tags the run with one correlation id, and the feed shows only that run.
- `/context_map`: the map drawn from `config/context_map.rb`, polled live. Events in transit run along their edge as orange dots, delivered ones flash red. It also shows counts, latency and the downstream file that handled each message.
- **Event feed** (right side, every page): the newest events. Each one is marked public or private, shows the event that caused it, and has one row per downstream context it is travelling to (in transit) or has reached (✓ + latency).
- **Slow motion** (top of the feed): delays every cross-context delivery by 1–5 s so the audience can watch an event travel from one context to the next. It is held in memory, so a server restart turns it off.
- `/res`: the RailsEventStore browser, with streams and correlation/causation chains.

## From the diagram to the code

| On the diagram | In the code |
|---|---|
| Bounded context | `contexts/<context>.rb` (namespace, private events) and `contexts/<context>/` |
| An edge | one `ContextMap::Edge` in `config/context_map.rb` |
| Upstream **OHS/PL** | public events in `contexts/<upstream>/public.rb` (`Inventory::Public::ResourceAdded`) delivered **async** |
| Upstream **OHS** only | a synchronous facade `contexts/availability/public.rb` (`Availability::Public`) with no events |
| Downstream **ACL** | `contexts/<downstream>/integrations/<upstream>_acl.rb` translates into the downstream's own commands and words |
| Downstream **Conformist** | `contexts/<downstream>/integrations/<upstream>_conformist.rb` takes the upstream's model as-is |

Public vs private:

- `Reservations::Public::ReservationConfirmed` is public. Other contexts may subscribe to it, and changing it breaks them.
- `Reservations::ReservationExpired` is private. It is defined in `contexts/reservations.rb`, only Reservations uses it, and you can change it freely.
- Reservations has no aggregate: the private events are facts of the process, not state of an aggregate.
- Contexts that are upstream of nobody (Invoicing, Facility Access, Negotiations) have no `Public` module.

Inside a context:

| File | Holds |
|---|---|
| `commands.rb` | the entry point used by the UI and by the context's own integrations |
| `internal/` | aggregates (`aggregate_root`) or internal tables (Reservations has none: its state is read models) |
| `read_models.rb` | tables the dashboard shows. Reservations' tables are written by its commands (and ACLs); Availability projects its own events into `availability_hours`. |

## Edges

| Upstream | Downstream | Transport | File |
|---|---|---|---|
| Contracts (OHS/PL) | Negotiations (Conformist) | async events | `negotiations/integrations/contracts_conformist.rb` |
| Contracts (OHS/PL) | Reservations (ACL) | async events | `reservations/integrations/contracts_acl.rb` |
| Contracts (OHS/PL) | Invoicing (ACL) | async events | `invoicing/integrations/contracts_acl.rb` |
| Inventory (OHS/PL) | Pricing (Conformist) | async events | `pricing/integrations/inventory_conformist.rb` |
| Inventory (OHS/PL) | Reservations (ACL) | async events | `reservations/integrations/inventory_acl.rb` |
| Inventory (OHS/PL) | Availability (ACL) | async events | `availability/integrations/inventory_acl.rb` |
| Pricing (OHS/PL) | Reservations (ACL) | async events | `reservations/integrations/pricing_acl.rb` |
| Availability (OHS) | Reservations (Conformist) | sync facade | `reservations/integrations/availability_conformist.rb` |
| Payments (OHS/PL) | Reservations (ACL) | async events | `reservations/integrations/payments_acl.rb` |
| Payments (OHS/PL) | Invoicing (ACL) | async events | `invoicing/integrations/payments_acl.rb` |
| Reservations (OHS/PL) | Invoicing (ACL) | async events | `invoicing/integrations/reservations_acl.rb` |
| Reservations (OHS/PL) | Facility Access (ACL) | async events | `facility_access/integrations/reservations_acl.rb` |

Availability hours are configured on the resource in Inventory, published as
`Inventory::Public::ResourceHoursAdded` with the resource's `resource_type`, and translated by
Availability's ACL. Ids are UUIDv7. The long line over the top of the diagram is read as Contracts → Invoicing.

## Mechanics worth pointing at

- **One event store, async across contexts.** `RailsEventStore::JSONClient` dispatches cross-context subscribers through ActiveJob after the upstream transaction commits.
  - In the demo the adapter is `:async` (in-process threads, no Redis); tests use `:test`.
  - Every integration inherits from `lib/integration_job.rb`. It deserializes the event, keeps correlation/causation ids, and runs the translation in its own transaction.
- **A failing downstream never undoes the upstream.** See `test_failing_downstream_does_not_undo_upstream`: Invoicing blows up, `ReservationConfirmed` stays.
- **Async means any order.** `Reservations::Commands.set_rate` accepts a price before the resource row exists. `Invoicing::Commands.generate_invoice` falls back to direct billing when the contract terms have not arrived yet.
- **Async means redelivery.** Handlers are idempotent: upserts by natural key and "already exists → return".
- **Sync is coupled in time.** `Reservations::Commands.pre_reserve_desk` calls `Availability::Public` inside its own transaction. If Availability raises, the pre-reservation fails (try pre-reserving the same desk twice for the same day).
- **No Reservation aggregate.** A reservation has no invariant of its own: the only decision that must be serialized (is the slot free?) lives in `Availability::Internal::Resource`. The rest is projected data from Inventory and Pricing, so Reservations' commands move a read-model row (`reservations_reservations`) through its states and publish facts. Availability stays the event-sourced core.
- **Capability vs process.** Availability is a capability (opening hours, held slots) with no UI entry point and no `Commands` module. Its hours come from Inventory's events. Reservations is the process on top of it and the only caller of `Availability::Public`.
- **Event-sourced slots.** `Availability::Internal::Resource` is an aggregate with one stream per resource (`Availability::Resource$<id>`). Its behaviours are `temporarily_block` (an offer, inside opening hours), `block` (paid or agreed), `unblock` and `cancel_temporary_block`. A desk pre-reservation takes a temporary hold; payment converts it to a full hold; a timed-out payment cancels it. The store's stream-version check stops two bookings racing for the same slot. With no aggregate in Reservations, this is also the only place that can reject a double booking.

## Conformist vs ACL, side by side

Both of these consume `Inventory::Public::ResourceAdded`:

- **`Pricing::Integrations::InventoryConformist`** copies Inventory's shape: one `pricing_resources` table with `resource_id`, `resource_type`, `zone`/`capacity` and Inventory's status words. Its Published Language stays Pricing's own, though: one generic `PricingAssigned` carrying `resource_id`, `resource_type`, `price_cents` and `price_unit`.
- **`Reservations::Integrations::InventoryAcl`** routes on `resource_type` into two tables, `reservations_desks` and `reservations_conference_rooms`. "Removed" and "out of service" both become *withdrawn*. The PricingAcl translates Pricing's generic price into a *tariff* (`rate_cents`/`rate_unit`) on whichever table holds that resource.

`Reservations::Integrations::AvailabilityConformist` is the sync version. Reservations passes and receives `Availability::Public::Period`/`Answer` and lets `NotAvailable` through untouched.

## Presenter script (≈10 min)

1. Open the dashboard and the context map side by side. Set **slow motion** to 2–3 s in the event feed.
2. **Inventory:** add a desk and a room. On the map, Inventory → Pricing (Conformist) and Inventory → Reservations (ACL) light up. Compare the Pricing and Reservations tables.
3. **Inventory:** set hours on the desk and the room; Availability learns them through its ACL. **Pricing:** assign prices.
4. **Reservations:** pre-reserve the desk. The dashed Availability edge fires (sync: no event, no delay). The reservation is `awaiting_payment`.
5. Click **Pay → checkout**, then **Confirmed** in Payments. Payments fans out to Reservations and Invoicing. Reservations publishes `ReservationConfirmed`, which reaches Invoicing (invoice + mail) and Facility Access (QR code + mail). Scan the code.
6. **Contracts:** the client requests a quote for a room ("Client requests quote"). The manager prices it and creates the draft, then sends it. Negotiations opens with Contracts' keys verbatim.
   - Propose a price and **Accept**: Negotiations calls Contracts, and learns its proposal was accepted only when `AgreementTermsChanged` comes back.
   - Apply a discount, generate (DocuWare), sign. Pay for the room reservation; the invoice now uses the company's billing terms from the ContractsAcl.
7. Open `/res`, pick `ReservationConfirmed`, and follow the correlation stream across contexts.

## Not in this version: flipping upstream/downstream

The next step of the workshop is reversing an edge. The natural candidate is
**Contracts → Negotiations**. Today Negotiations is a Conformist downstream, so accepting a
proposal means:

1. `Negotiations::Commands.accept_proposal` calls `Contracts::Commands.change_price`.
2. Negotiations waits for Contracts' event to come back.
3. It matches the event to its own proposal by the `changed` flag.

That round trip is the smell. Flipped, Negotiations would publish `Negotiations::Public::PriceChangeAccepted` and Contracts would get an ACL (`contracts/integrations/negotiations_acl.rb`).

Everything that would change is in `config/context_map.rb` and the `integrations/` folders.
None of the aggregates should need to know.
