# frozen_string_literal: true

require "csv"
require "json"

module SkilledServices
  module Reports
    # Produces normalized rows for all commercial reports and CSV exports.
    class ReportService
      REPORTS = %w[cabinet bill_of_materials material hardware door drawer room].freeze

      def initialize(model, dictionary: "SKServices_EuroCabinetGenerator")
        @model = model
        @dictionary = dictionary
      end

      def rows(kind)
        kind = kind.to_s
        raise ArgumentError, "Unknown report: #{kind}" unless REPORTS.include?(kind)
        return cabinet_rows if kind == "cabinet"
        return room_rows if kind == "room"

        part_rows(kind)
      end

      def to_csv(kind)
        data = rows(kind)
        headers = data.flat_map(&:keys).uniq
        CSV.generate do |csv|
          csv << headers.map { |key| title(key) }
          data.each { |row| csv << headers.map { |key| row[key] } }
        end
      end

      private

      def cabinets
        result = []
        walk(@model.entities, result)
        result
      end

      def walk(entities, result)
        entities.grep(Sketchup::Group).each do |group|
          raw = group.get_attribute(@dictionary, "params_json")
          if raw.is_a?(String) && !raw.empty?
            result << [group, JSON.parse(raw, symbolize_names: true)]
          else
            walk(group.entities, result)
          end
        rescue JSON::ParserError
          next
        end
      end

      def cabinet_rows
        cabinets.map do |group, params|
          {
            room: params[:room].to_s.empty? ? "Unassigned" : params[:room],
            cabinet_id: group.get_attribute(@dictionary, "cabinet_id"),
            code: params[:catalog_code] || group.get_attribute(@dictionary, "model_number"),
            name: group.name,
            width_in: params[:width_in], height_in: params[:height_in], depth_in: params[:depth_in],
            doors: params[:door_count], drawers: params[:drawer_count], shelves: params[:shelf_count],
            material: params[:mat_parts] || params[:material], revision: group.get_attribute(@dictionary, "revision")
          }
        end.sort_by { |row| [row[:room].to_s.downcase, row[:code].to_s] }
      end

      def room_rows
        cabinet_rows.group_by { |row| row[:room] }.map do |room, items|
          { room: room, cabinet_count: items.length, cabinet_codes: items.map { |item| item[:code] }.compact.join(", ") }
        end
      end

      def part_rows(kind)
        rows = []
        cabinets.each do |cabinet, params|
          cabinet.entities.grep(Sketchup::ComponentInstance).each do |part|
            name = part.definition.name.to_s
            next unless include_part?(kind, name)
            bounds = part.definition.bounds
            rows << {
              room: params[:room].to_s.empty? ? "Unassigned" : params[:room],
              cabinet: params[:catalog_code] || params[:model_number],
              part: name,
              material: part.material&.display_name || part.definition.material&.display_name,
              length_in: bounds.width.to_f.round(3),
              width_in: bounds.depth.to_f.round(3),
              thickness_in: bounds.height.to_f.round(3),
              quantity: 1
            }
          end
        end
        aggregate(rows)
      end

      def include_part?(kind, name)
        normalized = name.downcase
        case kind
        when "hardware" then normalized.match?(/hinge|pull|slide|bumper|support|lock|bracket/)
        when "door" then normalized.include?("door") && !normalized.include?("hardware")
        when "drawer" then normalized.include?("drawer")
        when "material", "bill_of_materials" then true
        else false
        end
      end

      def aggregate(rows)
        rows.group_by { |row| row.reject { |key, _value| key == :quantity } }.map do |signature, items|
          signature.merge(quantity: items.length)
        end
      end

      def title(key)
        key.to_s.split("_").map(&:capitalize).join(" ")
      end
    end
  end
end
