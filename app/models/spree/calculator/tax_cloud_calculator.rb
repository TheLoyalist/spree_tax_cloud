module Spree
  class Calculator::TaxCloudCalculator < Calculator::DefaultTax
    def self.description
      Spree.t(:tax_cloud)
    end

    # Default tax calculator still needs to support orders for legacy reasons
    # Orders created before Spree 2.1 had tax adjustments applied to the order, as a whole.
    # Orders created with Spree 2.2 and after, have them applied to the line items individually.
    def compute_order(order)
      raise 'Spree::TaxCloud is designed to calculate taxes at the shipment and line-item levels.'
    end

    # When it comes to computing shipments or line items: same same.
    def compute_shipment_or_line_item(item)
      if rate.included_in_price
        raise 'TaxCloud cannot calculate inclusive sales taxes.'
      end

      round_to_two_places(tax_for_item(item))
      # TODO take discounted_amount into account. This is a problem because TaxCloud API does not take discounts nor does it return percentage rates.
    end
    alias_method :compute_shipment, :compute_shipment_or_line_item
    alias_method :compute_line_item, :compute_shipment_or_line_item

    def compute_shipping_rate(shipping_rate)
      if rate.included_in_price
        raise 'TaxCloud cannot calculate inclusive sales taxes.'
      end

      # Sales tax will be applied to the Shipment itself, rather than to the Shipping Rates.
      # Note that this method is called from ShippingRate.display_price, so if we returned
      # the shipping sales tax here, it would display as part of the display_price of the 
      # ShippingRate, which is not consistent with how US sales tax typically works -- i.e.,
      # it is an additional amount applied to a sale at the end, rather than being part of
      # the displayed cost of a good or service.
      0
    end

    private

    def tax_for_item(item)
      order = item.order
      address = order.ship_address || order.bill_address

      if !order.shopify? && address.present? && calculable.zone.include?(address)
        Spree::TaxCloud.lookup(item)
      else
        0
      end
    end
  end
end
