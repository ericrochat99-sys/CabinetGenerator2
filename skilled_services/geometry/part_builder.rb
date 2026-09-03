# frozen_string_literal: true

module SkilledServices
  module Geometry
    # Shared placement logic for sides, tops, bottoms, backs, shelves,
    # stretchers, toe kicks, and partitions represented by reusable components.
    module PartBuilder
      module_function

      def add(parent_entities, definition, name:, x:, y:, z:, tag: nil, material: nil)
        transform = Geom::Transformation.translation([x, y, z])
        instance = parent_entities.add_instance(definition, transform)
        instance.name = name
        instance.layer = tag if tag
        instance.material = material if material
        instance
      end
    end
  end
end
