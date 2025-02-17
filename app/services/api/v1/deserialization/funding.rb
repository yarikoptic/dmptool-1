# frozen_string_literal: true

module Api
  module V1
    module Deserialization
      # Logic to deserialize RDA common standard to a Plan funder and grant infor
      class Funding
        class << self
          # Convert the funding information and attach to the Plan
          #    {
          #      "$ref": "SEE Org.deserialize! for details",
          #      "grant_id": {
          #        "$ref": "SEE Identifier.deserialize for details"
          #      },
          #      "funding_status": "granted"
          #    }
          def deserialize(plan:, json: {})
            return nil if plan.blank?
            return plan unless Api::V1::JsonValidationService.funding_valid?(json: json)

            # Attach the Funder
            plan.funder = Api::V1::Deserialization::Org.deserialize(json: json)
            return plan if json[:grant_id].blank?

            # Attach the grant Identifier to the Plan if present
            # Attach the identifier
            plan.grant = Api::V1::Deserialization::Identifier.deserialize(
              class_name: plan.class.name, json: json[:grant_id]
            )
            plan
          end
        end
      end
    end
  end
end
