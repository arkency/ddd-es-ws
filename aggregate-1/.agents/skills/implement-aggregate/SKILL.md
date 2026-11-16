---
name: implement-aggregate
description: Use when implementing or changing an event-sourced aggregate in aggregate-1 with RubyEventStore and tactical DDD. Covers AggregateRoot state rebuilt from events, behaviour-named methods that emit domain events, no exposed state, and no external dependencies.
---

# implement-aggregate

Event-sourced aggregate built on `AggregateRoot` (gem `aggregate_root`) and `RubyEventStore` events.

## Rules

1. **Aggregate root.** `include AggregateRoot`. A behaviour method decides and calls `apply(event)`. State changes only inside an `on <EventClass> do |event| ... end` block (aggregate_root 3.x DSL). Never assign state in a behaviour method.
2. **Behaviour names.** Public methods name a business behaviour in domain language: `place`, `cancel`, `ship_to`. Not `set_status`, `update`, `save`.
3. **Guard before emitting.** Check invariants in the behaviour method. On violation, raise a domain error and apply nothing.
4. **Events are the only output.** The aggregate communicates outward only by applying domain events. It does not call services, repositories, buses, or loggers.
5. **No external dependencies.** Do not accept collaborators in `initialize` or in method arguments: no repositories, services, gateways, or config. Clocks and id generators are allowed. Data the decision needs arrives as plain command arguments.
6. **No exposed state.** No `attr_reader`, getters, `to_h`, or serialization of internals. Internal state is private. Tests observe the aggregate through the events it applies and through behaviour (raises or not).
7. **High cohesion.** One aggregate guards one consistency boundary. Reference other aggregates by id only, never by object.
8. **Low coupling.** Event payloads hold plain data only: strings, numbers, booleans, arrays and hashes of those. Never domain objects.

## Shape

```ruby
OrderPlaced = Class.new(RubyEventStore::Event)

class Order
  include AggregateRoot

  class AlreadyPlaced < StandardError; end

  def initialize(id)
    @id = id
    @status = :new
  end

  def place(customer_id:, total_cents:)
    raise AlreadyPlaced unless @status == :new

    apply OrderPlaced.new(data: { order_id: @id, customer_id: customer_id, total_cents: total_cents })
  end

  private

  on OrderPlaced do |_event|
    @status = :placed
  end
end
```

Load and store through `AggregateRoot::Repository` outside the aggregate, not inside it.

## Done when

- Every public method is a behaviour name and either applies events or raises.
- `grep -n "attr_reader\|attr_accessor" <aggregate file>` returns nothing.
- The aggregate file has no `require` of a collaborator and no constructor or method parameter that is a collaborator other than a clock or id generator.
- Tests cover: the emitted event with its payload, the rejected case raising with no event applied, and rebuilding state from past events.
