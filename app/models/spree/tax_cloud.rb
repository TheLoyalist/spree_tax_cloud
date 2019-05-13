module Spree
  class TaxCloud
    Item = Struct.new(:id, :type, :stock_location_id, :price, :tic, :quantity)

    def self.reload_config
      ::TaxCloud.configure do |config|
        config.api_login_id = Spree::Config.taxcloud_api_login_id
        config.api_key = Spree::Config.taxcloud_api_key
        config.usps_username = Spree::Config.taxcloud_usps_user_id
      end
    end

    # Note that this method can take either a Spree::StockLocation (which has address
    # attributes directly on it) or a Spree::Address object
    def self.address_from_spree_address(address)
      ::TaxCloud::Address.new(
        address1: address.address1,
        address2: address.address2,
        city:     address.city,
        state:    address&.state&.abbr,
        zip5:     address.zipcode.try(:[], 0...5)
      )
    end

    def self.each_transaction(order)
      Enumerator.new do |y|
        item_groups = order.tax_cloud_combined_items.group_by(&:stock_location_id).values

        transactions = item_groups.each do |items|
          stock_location = Spree::StockLocation.find(items.first.stock_location_id)

          transaction = ::TaxCloud::Transaction.new(
            customer_id: order.user_id || order.email,
            order_id: order.number,
            cart_id: "#{order.number}/#{stock_location.id}",
            origin: address_from_spree_address(stock_location),
            destination: address_from_spree_address(order.ship_address || order.bill_address)
          )

          transaction.cart_items = items.map.with_index do |item, index|
            ::TaxCloud::CartItem.new({
              index: index,
              item_id: item.id,
              tic: item.tic,
              price: item.price,
              quantity: item.quantity,
            })
          end

          y << [transaction, items]
        end
      end
    end

    def self.lookup(item)
      # Sometimes (lol) shipments get updated "between the lines" and item instance isn't the
      # same as the one returned by `find`. We need reload to get the recent `cache_key`.
      item.reload if item.is_a?(Spree::Shipment)

      # Cache will expire if the order, any of its line items, or any of its shipments change.
      # When the cache expires, we will need to make another API call to TaxCloud.
      Rails.cache.fetch(['TaxCloudRatesForItem', item.tax_cloud_cache_key], time_to_idle: 5.minutes) do
        # In the case of a cache miss, we recompute the amounts for _all_ the LineItems and Shipments for this Order.

        tax_amounts = each_transaction(item.order).reduce({
          'Spree::LineItem' => {},
          'Spree::Shipment' => {},
        }) do |memo, (transaction, items)|
          cart_items = transaction.lookup.cart_items

          items.each_with_index do |item, index|
            memo[item.type][item.id] ||= 0
            memo[item.type][item.id] += cart_items[index].tax_amount
          end

          memo
        end

        tax_amounts['Spree::LineItem'].each do |id, tax_amount|
          Rails.cache.write(['TaxCloudRatesForItem', Spree::LineItem.find(id).tax_cloud_cache_key], tax_amount, time_to_idle: 5.minutes)
        end

        tax_amounts['Spree::Shipment'].each do |number, tax_amount|
          Rails.cache.write(['TaxCloudRatesForItem', Spree::Shipment.find_by!(number: number).tax_cloud_cache_key], tax_amount, time_to_idle: 5.minutes)
        end

        Rails.cache.read(['TaxCloudRatesForItem', item.tax_cloud_cache_key])
      end
    end
  end
end
