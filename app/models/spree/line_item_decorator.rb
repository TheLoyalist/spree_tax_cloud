Spree::LineItem.class_eval do
  def tax_cloud_cache_key
    [
      "Spree::LineItem #{id}: #{quantity}x<#{variant.cache_key}>@#{price}#{currency}",
      "addressed_to<#{(order.ship_address || order.bill_address)&.cache_key}>",
      "packaged_in<#{shipment_ids.uniq.sort.join(',')}>",
      "pro_bono<#{order.pro_bono? ? 'y' : 'n'}>",
    ].join("+")
  end
end
