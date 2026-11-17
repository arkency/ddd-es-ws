# frozen_string_literal: true

require "minitest/autorun"
require "ruby_event_store"

class CatalogRebuildTest < Minitest::Test
  ProductRegistered = Class.new(RubyEventStore::Event)
  ProductRenamed = Class.new(RubyEventStore::Event)
  PriceChanged = Class.new(RubyEventStore::Event)
  ProductDiscontinued = Class.new(RubyEventStore::Event)
  StockReplenished = Class.new(RubyEventStore::Event)
  OrderPlaced = Class.new(RubyEventStore::Event)

  CATALOG_EVENTS = [ProductRegistered, ProductRenamed, PriceChanged, ProductDiscontinued].freeze

  EXPECTED_CATALOG = {
    "sku-1" => { name: "Mug", price_cents: 1_299 },
    "sku-2" => { name: "Desk Lamp", price_cents: 4_500 }
  }.freeze

  class ProductCatalog
    STREAM = "ProductCatalog"

    attr_reader :records

    def initialize(event_store)
      @event_store = event_store
      @records = {}
    end

    def call(event)
      apply(event)
    end

    def rebuild
      @records.clear
      @event_store.read.stream(STREAM).each { |event| apply(event) }
    end

    private

    def apply(event)
      sku = event.data[:sku]
      case event
      when ProductRegistered then @records[sku] = { name: event.data[:name], price_cents: nil }
      when ProductRenamed then @records[sku][:name] = event.data[:name]
      when PriceChanged then @records[sku][:price_cents] = event.data[:price_cents]
      when ProductDiscontinued then @records.delete(sku)
      end
    end
  end

  def setup
    @event_store = RubyEventStore::Client.new
    @catalog = ProductCatalog.new(@event_store)
    @event_store.subscribe(@catalog, to: CATALOG_EVENTS)

    publish ProductRegistered, "Product$sku-1", sku: "sku-1", name: "Mug"
    publish ProductRegistered, "Product$sku-2", sku: "sku-2", name: "Lamp"
    publish ProductRegistered, "Product$sku-3", sku: "sku-3", name: "Chair"
    publish PriceChanged, "Price$sku-1", sku: "sku-1", price_cents: 999
    publish PriceChanged, "Price$sku-2", sku: "sku-2", price_cents: 4_500
    publish StockReplenished, "Inventory$sku-1", sku: "sku-1", quantity: 40
    publish PriceChanged, "Price$sku-3", sku: "sku-3", price_cents: 12_000
    publish ProductRenamed, "Product$sku-2", sku: "sku-2", name: "Desk Lamp"
    publish OrderPlaced, "Order$ord-1", order_id: "ord-1", sku: "sku-2", quantity: 1
    publish ProductDiscontinued, "Product$sku-3", sku: "sku-3"
    publish PriceChanged, "Price$sku-1", sku: "sku-1", price_cents: 1_299
  end

  def test_catalog_rebuilt_from_its_own_stream_matches_the_live_one
    assert_equal EXPECTED_CATALOG, @catalog.records

    @catalog.rebuild

    assert_equal EXPECTED_CATALOG, @catalog.records,
                 "rebuilt catalog has #{@catalog.records.size} products, " \
                 "#{ProductCatalog::STREAM} stream has #{@event_store.read.stream(ProductCatalog::STREAM).count} events"
    assert_equal @event_store.read.of_type(CATALOG_EVENTS).map(&:event_id),
                 @event_store.read.stream(ProductCatalog::STREAM).map(&:event_id)
  end

  private

  def publish(event_class, stream_name, **data)
    @event_store.publish(event_class.new(data: data), stream_name: stream_name)
  end
end
