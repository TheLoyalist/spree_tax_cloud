Spree::Order.class_eval do
  # TaxRate.match is used here to check if the order is taxable by Tax Cloud.
  # It's not possible check against the order's tax adjustments because
  # an adjustment is not created for 0% rates. However, US orders must be
  # submitted to Tax Cloud even when the rate is 0%.
  def is_taxed_using_tax_cloud?
    # `shopify_derivative?` coming from our custom Spree installation, FYI.
    !shopify_derivative? && Spree::TaxRate.match(self.tax_zone).any? { |rate| rate.calculator_type == "Spree::Calculator::TaxCloudCalculator" }
  end

  def log_tax_cloud(response)
    # Implement into your own application.
    # You could create your own Log::TaxCloud model then use either HStore or
    # JSONB to store the response.
    # The response argument carries the response from an order transaction.
  end

  def tax_cloud_combined_items
    shipments.flat_map(&:tax_cloud_items).group_by(&:stock_location_id).values.flat_map do |group|
      # Sums quantities of items with the same `id` (line items) from all shipments.
      group.group_by(&:id).values.map do |items|
        item = items.first.dup
        item.quantity = items.sum(&:quantity)
        item
      end
    end
  end
end
