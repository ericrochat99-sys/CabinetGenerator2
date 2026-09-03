# frozen_string_literal: true

require "json"

module SkilledServices
  module Catalog
    # Loads cabinet families from JSON so catalog additions never require Ruby edits.
    module Loader
      ROOT = File.expand_path(__dir__).freeze
      FILES = %w[base wall tall pantry sink vanity corner accessories].freeze

      module_function

      def all
        @all ||= FILES.flat_map { |family| load_file(family) }.freeze
      end

      def categories
        all.map { |item| item.fetch("category") }.uniq.sort
      end

      def find(code)
        wanted = code.to_s.strip.downcase
        all.find { |item| item.fetch("code").downcase == wanted }
      end

      def for_category(category)
        all.select { |item| item.fetch("category").casecmp(category.to_s).zero? }
      end

      def placement_params(code)
        item = find(code)
        return nil unless item

        {
          catalog_code: item["code"],
          cabinet_type: item["cabinet_type"],
          width_in: item["default_width"],
          height_in: item["default_height"],
          depth_in: item["default_depth"],
          min_width_in: item["minimum_width"],
          max_width_in: item["maximum_width"],
          width_increment_in: item["width_increment"],
          door_count: item["door_count"],
          show_doors: item["door_count"].to_i > 0,
          drawer_count: item["drawer_count"],
          shelf_count: item["shelf_count"],
          toe_height_in: item["toe_kick"],
          construction_type: item["construction_type"],
          notes: item["notes"]
        }.reject { |_key, value| value.nil? }
      end

      def reload!
        remove_instance_variable(:@all) if instance_variable_defined?(:@all)
        all
      end

      def load_file(family)
        path = File.join(ROOT, "#{family}.json")
        payload = JSON.parse(File.read(path, encoding: "UTF-8"))
        raise ArgumentError, "Catalog #{family}.json must contain an array" unless payload.is_a?(Array)

        payload.each { |item| validate!(item, path) }
      end
      private_class_method :load_file

      REQUIRED_KEYS = %w[
        code name category cabinet_type default_width default_height default_depth
        minimum_width maximum_width width_increment door_count drawer_count shelf_count
        toe_kick construction_type notes
      ].freeze

      def validate!(item, path)
        missing = REQUIRED_KEYS.reject { |key| item.key?(key) }
        raise ArgumentError, "#{path}: #{item.inspect} is missing #{missing.join(', ')}" unless missing.empty?
        item.freeze
      end
      private_class_method :validate!
    end
  end
end
