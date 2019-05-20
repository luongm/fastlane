require 'spaceship/tunes/iap_list'
require 'spaceship/tunes/iap_detail'
require 'spaceship/tunes/iap_status'
require 'spaceship/tunes/iap_type'
require 'spaceship/tunes/iap_family_list'
require 'spaceship/tunes/iap_families'
require 'spaceship/tunes/iap_family_details'
require 'spaceship/tunes/iap_families'
require 'spaceship/tunes/iap_subscription_pricing_tier'

module Spaceship
  module Tunes
    class IAP < TunesBase
      # @return (Spaceship::Tunes::Application) A reference to the application
      attr_accessor :application

      # @return (Spaceship::Tunes::IAPFamilies) A reference to the familie list
      def families
        attrs = {}
        attrs[:application] = self.application
        Tunes::IAPFamilies.new(attrs)
      end

      # Creates a new In-App-Purchese on iTunes Connect
      # if the In-App-Purchase already exists an exception is raised. Spaceship::TunesClient::ITunesConnectError
      # @param type (String): The Type of the in-app-purchase (Spaceship::Tunes::IAPType::CONSUMABLE,Spaceship::Tunes::IAPType::NON_CONSUMABLE,Spaceship::Tunes::IAPType::RECURRING,Spaceship::Tunes::IAPType::NON_RENEW_SUBSCRIPTION)
      # @param versions (Hash): a Hash of the languages
      # @example: {
      #   'de-DE': {
      #     name: "Name shown in AppStore",
      #     description: "Description of the In app Purchase"
      #
      #   }
      # }
      # @param reference_name (String): iTC Reference Name
      # @param product_id (String): A unique ID for your in-app-purchase
      # @param bundle_id (String): The bundle ID must match the one you used in Xcode. It
      # @param cleared_for_sale (Boolean): Is this In-App-Purchase Cleared for Sale
      # @param review_notes (String): Review Notes
      # @param review_screenshot (String): Path to the screenshot (should be 640x940 PNG)
      # @param pricing_intervals (Hash): a Hash of the languages
      # @example:
      #  [
      #    {
      #      country: "WW",
      #      begin_date: nil,
      #      end_date: nil,
      #      tier: 1
      #    }
      #  ]
      # @param family_id (String) Only used on RECURRING purchases, assigns the In-App-Purchase to a specific familie
      # @param subscription_free_trial (String) Free Trial duration (1w,1m,3m....)
      # @param subscription_duration (String) 1w,1m.....
      def create!(type: "consumable",
                  versions: nil,
                  reference_name: nil,
                  product_id: nil,
                  cleared_for_sale: true,
                  review_notes: nil,
                  review_screenshot: nil,
                  pricing_intervals: nil,
                  family_id: nil,
                  subscription_free_trial: nil,
                  subscription_free_trial_start_date: nil,
                  subscription_free_trial_end_date: nil,
                  subscription_duration: nil)

        response_datas = client.create_iap!(app_id: self.application.apple_id,
                           type: type,
                           versions: versions,
                           reference_name: reference_name,
                           product_id: product_id,
                           cleared_for_sale: cleared_for_sale,
                           review_notes: review_notes,
                           review_screenshot: review_screenshot,
                           pricing_intervals: pricing_intervals,
                           family_id: family_id,
                           subscription_duration: subscription_duration)

        if type == Spaceship::Tunes::IAPType::RECURRING
          # Update pricing for a recurring subscription.
          if pricing_intervals
            # There are cases where the product that was just created is not immediately found,
            # and in order to update its pricing the purchase_id is needed. Therefore polling is done
            # until it is found.
            product = find(product_id) until product
            client.update_recurring_iap_pricing!(app_id: self.application.apple_id,
                                                 purchase_id: product.purchase_id,
                                                 pricing_intervals: pricing_intervals)
          end

          # update free trial period
          if subscription_free_trial && subscription_free_trial_start_date
            if subscription_free_trial && subscription_free_trial_start_date
              language_codes = []
              pricing_calculator = client.iap_subscription_pricing_target(app_id: application.apple_id, purchase_id: purchase_id, currency: subscription_price_target[:currency], tier: subscription_price_target[:tier])
              pricing_calculator.each do |language_code, value|
                language_codes << language_code
              end

              intro_offers = language_codes.map do |language_code|
                {
                  value: {
                    country: language_code,
                    durationType: subscription_free_trial,
                    numOfPeriods: 1,
                    offerModeType: "FreeTrial",
                    startDate: subscription_free_trial_start_date,
                    endDate: subscription_free_trial_end_date || nil,
                  }
                }
              end
              if intro_offers.any?
                client.update_recurring_iap_intro_offers!(app_id: application.apple_id, purchase_id: self.purchase_id,
                                                          intro_offers: intro_offers)
              end
            end
          end
        end

        response_datas
      end

      # find a specific product
      # @param product_id (String) Product Id
      def find(product_id)
        all.each do |product|
          if product.product_id == product_id
            return product
          end
        end
        return nil
      end

      # return all available In-App-Purchase's of current app
      # this is not paged inside iTC-API so if you have a lot if IAP's (2k+)
      # it might take some time to load, same as it takes when you load the list via iTunes Connect
      def all(include_deleted: false)
        r = client.iaps(app_id: self.application.apple_id)
        return_iaps = []
        r.each do |product|
          attrs = product
          attrs[:application] = self.application
          loaded_iap = Tunes::IAPList.factory(attrs)
          next if loaded_iap.status == "deleted" && !include_deleted
          return_iaps << loaded_iap
        end
        return_iaps
      end
    end
  end
end
