# frozen_string_literal: true

module SolidusDrip
  module ShopperActivity
    class Order < SolidusDrip::Base
      attr_accessor :order

      ##
      # ShopperActivity::Order relies on order data to be useful. We call super
      # to initialize the client and then we set the order attribute to be used
      # in the API calls.
      #
      # @param order [Spree::Order] the order to be recorded
      #
      def initialize(order)
        super
        @order = order
      end

      ##
      # Cart Activity helps identify cart abandonment.
      #
      # @param action [String] the cart action, `created` or `updated`
      # @see https://developer.drip.com/#cart-activity
      #
      def cart_activity(action)
        response = client.create_cart_activity_event(cart_data(action))
        handle_error_response(response) if !response.success?

        response.success?
      end

      ##
      # Order Activity helps identify a user's lifetime value by tracking the values
      #
      # @param action [String] the cart action, `placed`, `updated`, `paid`,
      #   `fulfilled`, `refunded`, or `canceled`
      # @see https://developer.drip.com/#order-activity
      #
      def order_activity(action)
        response = client.create_order_activity_event(order_data(action))
        handle_error_response(response) if !response.success?

        response.success?
      end

      private

      ##
      # Formats data to be used in Drip cart calls
      #
      def cart_data(action)
        {
          provider: 'solidus',
          email: order.email,
          person_id: order.email.nil? ? order.guest_token : nil,
          action: action,
          occurred_at: order.updated_at.iso8601,
          cart_id: order.id.to_s,
          cart_public_id: order.number,
          grand_total: order.total.to_f,
          total_discounts: order.promo_total.to_f,
          currency: order.currency,
          cart_url: cart_url,
          items: order.line_items.map do |line_item|
            {
              product_id: line_item.product.id.to_s,
              product_variant_id: line_item.variant_id.to_s,
              sku: line_item.sku,
              name: line_item.name,
              categories: line_item.product.taxons.pluck(:name),
              price: line_item.price.to_f,
              quantity: line_item.quantity,
              discounts: line_item.promo_total.to_f,
              total: line_item.total.to_f,
              product_url: product_url(line_item.product)
            }.compact
          end
        }.compact
      end

      ##
      # Formats data to be used in Drip order calls
      #
      def order_data(action)
        {
          provider: 'solidus',
          email: order.email,
          action: action,
          occurred_at: order.updated_at.iso8601,
          order_id: order.id.to_s,
          order_public_id: order.number,
          grand_total: order.total.to_f,
          total_taxes: order.tax_total.to_f,
          total_discounts: order.promo_total.to_f,
          currency: order.currency,
          order_url: order_url(order),
          items: order.line_items.map do |line_item|
            {
              product_id: line_item.product.id.to_s,
              product_variant_id: line_item.variant_id.to_s,
              sku: line_item.sku,
              name: line_item.name,
              categories: line_item.product.taxons.pluck(:name),
              price: line_item.price.to_f,
              quantity: line_item.quantity,
              discounts: line_item.promo_total.to_f,
              taxes: line_item.additional_tax_total.to_f,
              total: line_item.total.to_f,
              product_url: product_url(line_item.product)
            }.compact
          end,
          billing_address: {
            company: order.billing_address.company,
            address_1: order.billing_address.address1,
            address_2: order.billing_address.address2,
            city: order.billing_address.city,
            state: order.billing_address.state&.abbr || order.billing_address.state_name,
            postal_code: order.billing_address.zipcode,
            country: order.billing_address.country&.name,
            phone: order.billing_address.phone
          }.merge(address_attributes(order.billing_address)).compact,
          shipping_address: {
            company: order.shipping_address.company,
            address_1: order.shipping_address.address1,
            address_2: order.shipping_address.address2,
            city: order.shipping_address.city,
            state: order.shipping_address.state&.abbr || order.shipping_address.state_name,
            postal_code: order.shipping_address.zipcode,
            country: order.shipping_address.country&.name,
            phone: order.shipping_address.phone
          }.merge(address_attributes(order.shipping_address)).compact
        }.compact
      end

      def address_attributes(address)
        if SolidusSupport.combined_first_and_last_name_in_address?
          name = ::Spree::Address::Name.new(address.name)

          {
            first_name: name.first_name,
            last_name: name.last_name,
          }
        else
          {
            first_name: order.shipping_address.firstname,
            last_name: order.shipping_address.lastname,
          }
        end
      end
    end
  end
end
