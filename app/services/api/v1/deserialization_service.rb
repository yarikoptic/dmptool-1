# frozen_string_literal: true

module Api
  module V1
    # Generic deserialization helper methods
    class DeserializationService
      class << self
        # Finds the object by the specified identifier
        def object_from_identifier(class_name:, json:)
          return nil unless class_name.present? && json.present? &&
                            json[:type].present? && json[:identifier].present?

          clazz = "::#{class_name.capitalize}".constantize
          return nil unless clazz.respond_to?(:from_identifiers)

          clazz.from_identifiers(
            array: [{ name: json[:type], value: json[:identifier] }]
          )
        rescue NameError
          nil
        end

        # Attach the identifier to the object if it does not already exist
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        def attach_identifier(object:, json:)
          return object unless object.present? && object.respond_to?(:identifiers) &&
                               json.present? &&
                               json[:type].present? && json[:identifier].present?

          existing = object.identifiers.select do |id|
            id.identifier_scheme&.name&.downcase == json[:type].downcase
          end
          return object if existing.present?

          object.identifiers << Api::V1::Deserialization::Identifier.deserialize(
            class_name: object.class.name, json: json
          )
          object
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        # Search for an in the Org and RegistryOrg tables
        # rubocop:disable Metrics/AbcSize
        def name_to_org(name:)
          return nil unless name.is_a?(String) && name.present?

          org = ::Org.where('LOWER(name) = ?', name.downcase)
                     .first
          return org if org.present?

          # External ROR search
          registry_org = ::RegistryOrg.includes(:org)
                                      .where('LOWER(name) = ?', name.downcase)
                                      .first
          # Return nil if no Registry Org was found
          return nil if registry_org.blank?

          # Return nil if we do not allow creating Orgs in this manner
          return nil if registry_org.org_id.nil? && Rails.configuration.x.application.restrict_orgs

          # return the related Org or initialize a new one
          registry_org.to_org
        end
        # rubocop:enable Metrics/AbcSize

        # Translates the role in the json to a Contributor role
        def translate_role(role:)
          default = ::Contributor.role_default
          return default if role.blank?

          role = role.to_s unless role.is_a?(String)

          # Strip off the URL if present
          url = ::Contributor::ONTOLOGY_BASE_URL
          role = role.gsub("#{url}/", '').downcase if role.include?(url)

          # Return the role if its a valid one otherwise defualt
          return role if ::Contributor.new.all_roles.include?(role.downcase.to_sym)

          default
        end

        # Retrieve any JSON schema extensions for this application
        def app_extensions(json: {})
          return {} unless json.present? && json[:extension].present?

          # Note the symbol of the dmproadmap json object
          # nested in extensions which is the container for the json template object, etc.
          ext = json[:extension].select { |item| item[:dmproadmap].present? }
          ext.first.present? ? ext.first[:dmproadmap] : {}
        end

        # Determines whether or not the value is a DOI/ARK
        def dmp_id?(value:)
          return false if value.blank?

          # The format must match a DOI or ARK and a DOI IdentifierScheme
          # must also be present!
          identifier = ::Identifier.new(value: value)
          scheme = DmpIdService.identifier_scheme
          %w[ark doi].include?(identifier.identifier_format) && scheme.present?
        end

        # Converts the string into a UTC Time string
        def safe_date(value:)
          return nil unless value.is_a?(String)

          Time.parse(value).utc
        rescue ArgumentError
          value.to_s
        end
      end
    end
  end
end
