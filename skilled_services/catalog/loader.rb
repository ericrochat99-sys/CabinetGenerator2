# frozen_string_literal: true

require "json"

module SkilledServices
  module Catalog
    # Loads cabinet families from JSON so catalog additions never require Ruby edits.
    module Loader
      ROOT = File.expand_path(__dir__).freeze
      FILES = %w[base wall tall pantry sink vanity corner accessories].freeze

      # Full ForgeCase item numbers use CODE-H/D/W. Accept the typographic dash
      # produced by the dialog as well as keyboard-friendly hyphens/underscores.
      MODEL_NUMBER_PATTERN = /\A([A-Z][A-Z0-9]*?)(P?)[\u2013\u2014\-_](\d+(?:\.\d+)?)\/(\d+(?:\.\d+)?)\/(\d+(?:\.\d+)?)\z/i.freeze
      MODEL_FAMILIES = {
        "B10" => ["Base", 0, 0, 1],
        "B14" => ["Base", 0, 0, 1],
        "B60" => ["Base", 0, 0, 1],
        "B12" => ["Base", 1, 2, 1],
        "B64" => ["Base", 1, 2, 1],
        "D30" => ["Base", 3, 0, 0],
        "D40" => ["Base", 4, 0, 0],
        "D50" => ["Base", 5, 0, 0],
        "SB60" => ["Sink Base", 0, 2, 0],
        "SB64" => ["Sink Base", 0, 2, 0],
        "KB00" => ["ADA Sink", 0, 0, 0],
        "KB10" => ["ADA Sink", 0, 0, 0],
        "BCB" => ["Pie-Cut Corner Base", 0, 1, 1],
        "BDC" => ["Diagonal Corner Base", 0, 1, 1],
        "W10" => ["Wall", 0, 1, 2],
        "W12" => ["Wall", 0, 2, 2],
        "WCB" => ["Wall", 0, 1, 1],
        "WDC" => ["Wall", 0, 1, 1],
        "WO" => ["Wall", 0, 0, 2],
        "T10" => ["Tall", 0, 1, 5],
        "T12" => ["Tall", 0, 2, 5],
        "TU" => ["Tall", 0, 2, 5],
        "TUL" => ["Tall", 0, 2, 5]
      }.freeze

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
        return model_number_params(code) unless item

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

      def model_number_params(value)
        match = MODEL_NUMBER_PATTERN.match(value.to_s.strip.upcase)
        return nil unless match

        family_code = match[1]
        partitioned = !match[2].to_s.empty?
        family = MODEL_FAMILIES[family_code]
        return nil unless family

        cabinet_type, drawer_count, door_count, shelf_count = family
        height = match[3].to_f
        depth = match[4].to_f
        width = match[5].to_f
        # Base-family item numbers store carcass height; the dialog stores the
        # finished cabinet/counter height used by the model-number generator.
        height = 34.5 if %w[Base Sink\ Base ADA\ Sink].include?(cabinet_type) && (height - 32.0).abs < 0.001
        height = 26.5 if %w[Base Sink\ Base ADA\ Sink].include?(cabinet_type) && (height - 24.0).abs < 0.001

        {
          catalog_code: "#{family_code}#{partitioned ? 'P' : ''}",
          cabinet_type: cabinet_type,
          width_in: width,
          height_in: height,
          depth_in: depth,
          drawer_count: drawer_count,
          door_count: door_count,
          show_doors: door_count.positive?,
          shelf_count: shelf_count,
          partition_count: partitioned ? 1 : 0
        }
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
