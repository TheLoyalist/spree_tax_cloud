Spree::Shipment.class_eval do
  def tax_cloud_cache_key
    "#{self.cache_key}--from:#{self.stock_location.cache_key}--to:#{self.order.shipping_address.cache_key}"
  end

  def tax_cloud_items
    line_items.map do |line_item|
      Spree::TaxCloud::Item.new(
        line_item.id,
        line_item.class.name,
        stock_location_id,
        line_item.price,
        line_item.product&.tax_cloud_tic.presence || Spree::Config.taxcloud_default_product_tic,
        inventory_units_for_item(line_item).count,
      )
    end + [
      Spree::TaxCloud::Item.new(
        number,
        self.class.name,
        stock_location_id,
        cost,
        Spree::Config.taxcloud_shipping_tic,
        1,
      )
    ]
  end
end
