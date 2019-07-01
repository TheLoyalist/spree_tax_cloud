Spree::Shipment.class_eval do
  def tax_cloud_cache_key
    "#{cache_key}--from:#{stock_location.cache_key}--to:#{order.shipping_address.cache_key}--probono:#{order.pro_bono? ? 'y' : 'n'}"
  end

  def tax_cloud_items
    # pro_bono means the order total is zero. It's an edge case we introduced to
    # deal with 100% off coupons applied by Customer Service.
    pro_bono = order.pro_bono?

    line_items.map do |line_item|
      Spree::TaxCloud::Item.new(
        line_item.id,
        line_item.class.name,
        stock_location_id,
        (line_item.price unless pro_bono).to_f,
        line_item.product&.tax_cloud_tic,
        inventory_units_for_item(line_item).count,
      )
    end + [
      Spree::TaxCloud::Item.new(
        number,
        self.class.name,
        stock_location_id,
        (cost unless pro_bono).to_f,
        Spree::Config.taxcloud_shipping_tic,
        1,
      )
    ]
  end
end
