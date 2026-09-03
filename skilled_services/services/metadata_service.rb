# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module SkilledServices
  module Services
    # Owns the stable cabinet identity and searchable SketchUp attributes.
    module MetadataService
      DICTIONARY = "SKServices_EuroCabinetGenerator"
      SCHEMA_VERSION = 2

      module_function

      def write(entity, params, existing: nil)
        previous = existing || read(entity)
        now = Time.now.utc.iso8601
        metadata = {
          cabinet_id: previous[:cabinet_id] || SecureRandom.uuid,
          cabinet_code: params[:catalog_code] || params[:model_number],
          room: params[:room].to_s,
          width: params[:width_in].to_f,
          height: params[:height_in].to_f,
          depth: params[:depth_in].to_f,
          material: params[:mat_parts] || params[:material],
          hardware: params[:hardware],
          revision: previous.fetch(:revision, 0).to_i + 1,
          creation_date: previous[:creation_date] || now,
          modified_date: now
        }
        entity.set_attribute(DICTIONARY, "metadata_json", metadata.to_json)
        entity.set_attribute(DICTIONARY, "schema_version", SCHEMA_VERSION)
        metadata.each { |key, value| entity.set_attribute(DICTIONARY, key.to_s, value) unless value.nil? }
        metadata
      end

      def read(entity)
        raw = entity.get_attribute(DICTIONARY, "metadata_json")
        return {} unless raw.is_a?(String) && !raw.empty?
        JSON.parse(raw, symbolize_names: true)
      rescue JSON::ParserError
        {}
      end
    end
  end
end
