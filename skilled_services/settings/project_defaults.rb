# frozen_string_literal: true

require "json"

module SkilledServices
  module Settings
    # Persists standards in the SketchUp model, with application preferences as fallback.
    module ProjectDefaults
      DICTIONARY = "SkilledServices_ProjectDefaults"
      KEY = "settings_json"

      DEFAULTS = {
        construction_type: "Frameless",
        cabinet_construction: "Frameless",
        base_cabinet_height_in: 34.5,
        wall_cabinet_height_in: 30.0,
        tall_cabinet_height_in: 84.0,
        base_cabinet_depth_in: 24.0,
        wall_cabinet_depth_in: 12.0,
        tall_cabinet_depth_in: 24.0,
        toe_kick_height_in: 4.0,
        countertop_thickness_in: 1.5,
        shelf_thickness_in: 0.75,
        back_thickness_in: 0.75,
        material_thickness_in: 0.75,
        door_style: "Slab",
        drawer_box_style: "Melamine",
        hardware_defaults: "Soft-close hinges; full-extension slides",
        default_material: "MELAMINE - White - Interior (PB Core)"
      }.freeze

      module_function

      def read(model = Sketchup.active_model)
        raw = model&.get_attribute(DICTIONARY, KEY)
        parsed = raw.is_a?(String) ? JSON.parse(raw, symbolize_names: true) : {}
        DEFAULTS.merge(parsed)
      rescue JSON::ParserError, StandardError
        DEFAULTS.dup
      end

      def write(values, model = Sketchup.active_model)
        clean = coerce(values)
        model.set_attribute(DICTIONARY, KEY, clean.to_json) if model
        clean
      end

      def cabinet_overrides(cabinet_type, model = Sketchup.active_model)
        settings = read(model)
        family = family_for(cabinet_type)
        {
          height_in: settings.fetch(:"#{family}_cabinet_height_in"),
          depth_in: settings.fetch(:"#{family}_cabinet_depth_in"),
          toe_height_in: family == "wall" ? 0.0 : settings[:toe_kick_height_in],
          countertop_thk_in: settings[:countertop_thickness_in],
          panel_thk_in: settings[:material_thickness_in],
          shelf_thk_in: settings[:shelf_thickness_in],
          back_thk_in: settings[:back_thickness_in],
          construction_type: settings[:construction_type],
          cabinet_construction: settings[:cabinet_construction],
          door_style: settings[:door_style],
          drawer_box_style: settings[:drawer_box_style],
          hardware: settings[:hardware_defaults],
          mat_parts: settings[:default_material]
        }
      end

      def coerce(values)
        source = values.respond_to?(:transform_keys) ? values.transform_keys(&:to_sym) : {}
        DEFAULTS.each_with_object({}) do |(key, fallback), result|
          raw = source.key?(key) ? source[key] : fallback
          result[key] = fallback.is_a?(Numeric) ? raw.to_f : raw.to_s
        end
      end
      private_class_method :coerce

      def family_for(cabinet_type)
        value = cabinet_type.to_s.downcase
        return "wall" if value.include?("wall")
        return "tall" if value.include?("tall") || value.include?("pantry")
        "base"
      end
      private_class_method :family_for
    end
  end
end
