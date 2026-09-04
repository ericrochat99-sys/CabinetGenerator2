# frozen_string_literal: true

require "json"
require "digest"
require "sketchup.rb"
require_relative "version"
require_relative "ui/dialog"
require_relative "ui/cabinet_edit_tool"
require_relative "services/update_checker"
require_relative "catalog/loader"
require_relative "settings/project_defaults"
require_relative "services/metadata_service"
require_relative "reports/report_service"
require_relative "geometry/part_builder"



module SkilledServices
end

# -------------------------------------------------------------------------
# Cabinet model numbering / catalog
# -------------------------------------------------------------------------
# Provides the model-number logic used to tag generated cabinets.
# Output convention used by this generator: CODE–H/D/W (no spaces).
# frozen_string_literal: true

module SkilledServices::CabinetModelCatalog
  # -------------------------
  # Universal width rule
  # -------------------------
  WIDTHS = (10..48).to_a.freeze
  PARTITION_MIN_W = 37

  # -------------------------
  # Base cabinets
  # -------------------------
  # 32" carcass = 34.5" overall
  # 24" carcass = 26.5" overall
  BASE_HEIGHTS = [32, 24].freeze
  BASE_DEPTHS  = [16, 24, 30].freeze

  # -------------------------
  # Wall cabinets
  # -------------------------
  WALL_HEIGHTS = [12, 15, 18, 24, 30, 36, 42].freeze
  WALL_DEPTHS  = [12, 14, 16, 24].freeze

  # -------------------------
  # Tall cabinets
  # -------------------------
  TALL_HEIGHTS = [84, 90, 96].freeze
  TALL_DEPTHS  = [12, 16, 24, 30].freeze

  # -------------------------
  # Lockers (model code logic)
  # -------------------------
  # Code structure: L[U][C][H][D]
  LOCKER_UNITS_WIDE   = [1, 2, 3].freeze
  LOCKER_CLASS_DIGIT  = [2, 6].freeze
  LOCKER_HEIGHT_DIGIT = [4, 6].freeze
  LOCKER_DOOR_TYPES   = [0, 1, 2, 3, 4, 5, "Z"].freeze

  # -------------------------
  # Cabinet code definitions
  # -------------------------
  DEFINITIONS = [
    # Base cabinets
    { code_base: "B10",  category: :base, partition: :never },
    { code_base: "B14",  category: :base, partition: :never },
    { code_base: "B60",  category: :base, partition: :never },
    { code_base: "B12",  category: :base, partition: :required_by_width },
    { code_base: "B64",  category: :base, partition: :required_by_width },

    # Drawer bases
    { code_base: "D30",  category: :base, partition: :required_by_width },
    { code_base: "D40",  category: :base, partition: :required_by_width },
    { code_base: "D50",  category: :base, partition: :required_by_width },

    # Sink bases
    { code_base: "SB60", category: :base, partition: :never },
    { code_base: "SB64", category: :base, partition: :required_by_width },

    # ADA / knee-space bases
    { code_base: "KB00", category: :base, partition: :never },
    { code_base: "KB10", category: :base, partition: :never },

    # Corner bases
    { code_base: "BCB",  category: :base, partition: :never },
    { code_base: "BDC",  category: :base, partition: :never },

    # Wall cabinets
    { code_base: "W10",  category: :wall, partition: :never },
    { code_base: "W12",  category: :wall, partition: :required_by_width },

    # Wall corner cabinets
    { code_base: "WCB",  category: :wall, partition: :never },
    { code_base: "WDC",  category: :wall, partition: :never },

    # Open uppers
    { code_base: "WO",   category: :wall, partition: :never },

    # Tall cabinets
    { code_base: "T10",  category: :tall, partition: :never },
    { code_base: "T12",  category: :tall, partition: :required_by_width },

    # Tall utility / janitor
    { code_base: "TU",   category: :tall, partition: :never },
    { code_base: "TUL",  category: :tall, partition: :never }
  ].freeze

  # -------------------------
  # Helpers
  # -------------------------
  def self.partition_suffix(defn, w)
    return "" unless defn[:partition] == :required_by_width
    w >= PARTITION_MIN_W ? "P" : ""
  end

  # -------------------------
  # Locker model codes only
  # -------------------------
  def self.all_locker_model_codes
    LOCKER_UNITS_WIDE.flat_map do |u|
      LOCKER_CLASS_DIGIT.flat_map do |c|
        LOCKER_HEIGHT_DIGIT.flat_map do |h|
          LOCKER_DOOR_TYPES.map do |d|
            "L#{u}#{c}#{h}#{d}"
          end
        end
      end
    end
  end

  # -------------------------
  # Schedule generation
  # -------------------------
  # Output format: CODE–H/D/W (no spaces)
  def self.all_schedule_lines
    lines = []

    DEFINITIONS.each do |defn|
      case defn[:category]
      when :base
        BASE_HEIGHTS.each do |h|
          BASE_DEPTHS.each do |d|
            WIDTHS.each do |w|
              code = defn[:code_base] + partition_suffix(defn, w)
              lines << "#{code}–#{h}/#{d}/#{w}"
            end
          end
        end

      when :wall
        WALL_HEIGHTS.each do |h|
          WALL_DEPTHS.each do |d|
            WIDTHS.each do |w|
              code = defn[:code_base] + partition_suffix(defn, w)
              lines << "#{code}–#{h}/#{d}/#{w}"
            end
          end
        end

      when :tall
        TALL_HEIGHTS.each do |h|
          TALL_DEPTHS.each do |d|
            WIDTHS.each do |w|
              code = defn[:code_base] + partition_suffix(defn, w)
              lines << "#{code}–#{h}/#{d}/#{w}"
            end
          end
        end
      end
    end

    lines
  end

  # -------------------------
  # Model codes only (no dimensions)
  # -------------------------
  def self.all_model_codes
    cabinet_codes =
      DEFINITIONS.flat_map do |defn|
        defn[:partition] == :required_by_width ?
          [defn[:code_base], "#{defn[:code_base]}P"] :
          [defn[:code_base]]
      end

    (cabinet_codes + all_locker_model_codes).uniq
  end

end

module SkilledServices
  # Defined at root scope as well for legacy references in menu/loader code
  PLUGIN_NAME = "ForgeCase" unless const_defined?(:PLUGIN_NAME)
  module EuroCabinetGenerator


  # --- Panel finish material names (canonical) ---
  WHITE_INTERIOR_MELAMINE = 'MELAMINE - White - Interior (PB Core)'.freeze
  EXTERIOR_MELAMINE       = 'MELAMINE - Exterior (PB Core)'.freeze
  EXTERIOR_HPL            = 'HPL - Exterior (PB Core)'.freeze
  TOE_KICK_MATERIAL      = 'PLYWOOD - Unfinished'.freeze
  TOE_KICK_SKU           = 'PANEL_PLY_UNFIN_UNFIN_750'.freeze



    # ---------------------
    # Color helpers
    # ---------------------
    # Accepts "#RRGGBB" (or "RRGGBB"). Returns [r,g,b] integers 0..255.
    # Defined as a module_function so it can be called as `hex_to_rgb(...)`
    # within module methods and as `EuroCabinetGenerator.hex_to_rgb(...)`.
    def hex_to_rgb(hex)
      s = (hex || "").to_s.strip
      s = s[1..] if s.start_with?("#")
      s = "aaaaaa" if s.empty?
      s = s[0,6].ljust(6, "0")
      r = s[0,2].to_i(16)
      g = s[2,2].to_i(16)
      b = s[4,2].to_i(16)
      [r, g, b]
    end
    module_function :hex_to_rgb

    extend self

    # Ensure cabinets face SketchUp's native Front view.
    # SketchUp "Front" camera looks from +Y toward -Y, so the cabinet "front" must face -Y.
    # We bake a 180° rotation about Z into the *geometry* (not the group transform) so the group axes remain world-aligned.
    def orient_cabinet_geometry_for_native_front!(root, w, d, params = nil)
      return unless root && root.respond_to?(:entities)

      # Prevent double-application on edit/regenerate flows
      if params && params[:_native_front_oriented]
        return
      end

      ents = root.entities
      items = ents.to_a
      return if items.empty?

      # SketchUp native Front view looks from +Y toward -Y.
      # We want the cabinet FRONT to face -Y so the native "Front" view looks at the cabinet front.
      # We bake this into the GEOMETRY (not the group transform) to keep group axes world-aligned.
      rot   = Geom::Transformation.rotation(ORIGIN, Z_AXIS, Math::PI)
      move  = Geom::Transformation.translation([w, d, 0.to_l])
      xform = move * rot
      ents.transform_entities(xform, items)

      # Ensure the cabinet's bottom-back-left corner sits at the group's local origin.
      # With the cabinet front facing -Y, the BACK is at the maximum Y extent.
      bb = root.bounds
      if bb && bb.min
        offset = Geom::Vector3d.new(-bb.min.x, -bb.max.y, -bb.min.z)
        ents.transform_entities(Geom::Transformation.translation(offset), items)
      end

      params[:_native_front_oriented] = true if params
    end


    PLUGIN_NAME = "ForgeCase"
    # NOTE: Preferences are stored via SketchUp's read_default/write_default.
    # Some earlier plugin versions wrote values that SketchUp later attempts to
    # eval() while reading, which can raise SyntaxError and prevent the
    # extension from loading. We bump the pref key to start clean, and we also
    # defensively rescue SyntaxError when reading legacy prefs.
    PREF_KEY    = "SKServices_EuroCabinetGenerator_Preview_v2"

    # -------------------------------------------------------------------------
    # Global Settings (shop standards)
    # -------------------------------------------------------------------------
    GLOBAL_DEFAULTS = {
      # Construction
      panel_thk_in: 0.75,
      back_thk_in: 0.75,

      # Carcass construction modes
      base_top_mode: "Stretchers",
      tall_top_mode: "Full Top",
      back_mode: "Full Back",
      door_thk_in: 0.75,
      drawer_front_thk_in: 0.75,

      box_thk_in: 0.75,
      stretcher_width_in: 5.0,
      reveal_center_in: 0.125,
      automatic_double_door_threshold_in: 24.0,
      automatic_drawer_bank_split_threshold_in: 37.0,
      trash_drawer_box_bottom_offset_in: 0.5,
      aep_front_return_width_in: 1.5,
      aep_front_return_thk_in: 0.75,
      front_color_hex: "#aaaaaa",
      carcass_color_hex: "#dcceaa",
      edgeband_color_hex: "#c88c28",

      # Toe kick
      toe_kick_h_in: 4.0,
      toe_kick_recess_in: 3.0,

      # Fronts & gaps
      reveal_in: 0.0625,

      # Hardware toggles
      add_wire_pulls: true,
      pull_kind: "wire_pull",
      drawer_pull_centered: false,
      add_hinges: true,
      add_door_bumpers: true,
      add_shelf_supports: true,
      add_cam_lock: true,
      add_countertop_brackets: true
    }.freeze

    def parse_pref_hash(raw)
      return nil unless raw.is_a?(String) && !raw.strip.empty?
      s = raw.strip

      begin
        return JSON.parse(s, symbolize_names: true)
      rescue
        # fall through
      end

      # Legacy Ruby-hash-like prefs (no eval)
      begin
        t = s.dup
        t.gsub!(/:(\w+)\s*=>/, '"\1":')
        t.gsub!(/"([^"]+)"\s*=>/, '"\1":')
        t.gsub!(/=>/, ':')
        t = "{#{t}}" unless t.lstrip.start_with?("{")
        JSON.parse(t, symbolize_names: true)
      rescue
        nil
      end
    end

    def read_global_settings
      raw = Sketchup.read_default(PREF_KEY, "global_settings", nil)
      parse_pref_hash(raw)
    rescue SyntaxError, ScriptError
      # Some SketchUp versions may raise while reading malformed legacy prefs.
      nil
    rescue StandardError
      nil
    end

    def write_global_settings(settings_hash)
      Sketchup.write_default(PREF_KEY, "global_settings", settings_hash.to_json)
    rescue StandardError
      nil
    end

    def merged_global_settings
      saved = read_global_settings
      merged = GLOBAL_DEFAULTS.dup
      merged.merge!(saved) if saved.is_a?(Hash)
      merged
    end

    def show_global_settings_dialog
      settings = merged_global_settings
      project_settings = SkilledServices::Settings::ProjectDefaults.read

      @global_dialog ||= UI::HtmlDialog.new(
        dialog_title: "#{PLUGIN_NAME} — Global Settings",
        preferences_key: "#{PREF_KEY}_global_settings_dialog",
        scrollable: true,
        resizable: true,
        width: 520,
        height: 640
      )

      html = SkilledServices::DialogTemplate.render(
        "global_settings",
        "DEFAULTS_JSON" => GLOBAL_DEFAULTS.to_json,
        "SETTINGS_JSON" => settings.to_json,
        "PROJECT_DEFAULTS_JSON" => SkilledServices::Settings::ProjectDefaults::DEFAULTS.to_json,
        "PROJECT_SETTINGS_JSON" => project_settings.to_json
      )

      @global_dialog.set_html(html)

      @global_dialog.add_action_callback("save_global_settings") do |_ctx, json_str|
        begin
          data = JSON.parse(json_str)
          clean = {}
          GLOBAL_DEFAULTS.each do |k, v|
            clean[k] =
              if v == true || v == false
                !!data[k.to_s]
              elsif v.is_a?(Numeric)
                (data[k.to_s].nil? ? v : data[k.to_s].to_f)
              else
                (data[k.to_s].nil? ? v : data[k.to_s].to_s)
              end
          end
          write_global_settings(clean)
          project_values = data.select { |key, _value| SkilledServices::Settings::ProjectDefaults::DEFAULTS.key?(key.to_sym) }
          SkilledServices::Settings::ProjectDefaults.write(project_values)
          # If main dialog is open, re-load current type so defaults update immediately.
          if defined?(@dialog) && @dialog && @dialog.visible?
            @dialog.execute_script("if (window.refresh_from_globals) refresh_from_globals();")
          end
        rescue => e
          UI.messagebox("Failed to save Global Settings: #{e.class}: #{e.message}")
        end
      end

      @global_dialog.show
    end



    CABINET_ATTR_DICT          = "SKServices_EuroCabinetGenerator"
    CABINET_ATTR_SCHEMA        = "schema_version"
    CABINET_ATTR_PARAMS_JSON   = "params_json"
    CABINET_ATTR_GENERATED_BY  = "generated_by"
    CABINET_ATTR_GENERATED_AT  = "generated_at"
    CABINET_ATTR_MODEL_NUMBER   = "model_number"

    # ----------------------------
    # Units / helpers
    # ----------------------------
    def in_to_length(inches)
      inches.to_f
    end


# Countertop depth helpers (carcass depth + door/drawer-front thickness + front reveal)
def cabinet_front_thickness_in(params)
  return DEFAULT_DOOR_THK_IN if params.nil?
  v = params[:door_thk_in] || params[:drawer_front_thk_in] || params[:front_thk_in]
  v = v.nil? ? DEFAULT_DOOR_THK_IN : v.to_f
  v <= 0.0 ? DEFAULT_DOOR_THK_IN : v
end

def countertop_front_overhang_length(inst)
  params = _cabinet_params_from_instance(inst) || {}
  in_to_length(cabinet_front_thickness_in(params) + COUNTERTOP_FRONT_REVEAL_IN)
end


# ----------------------------
# Model numbering (Catalog)
# ----------------------------
# Computes a model number string for the current cabinet params.
# Format: CODE–H/D/W (no spaces)
#
# This generator does not currently expose every catalog subtype in the UI.
# The mapping below is deterministic and is designed to be expanded as you add
# additional cabinet types/options to the generator.
def self.compute_model_number(params)
  p = (params || {}).dup
  type = p[:cabinet_type].to_s

  # Door count is displayed in the UI as a computed (disabled) field, but is still
  # submitted with params in most cases. Support a few key names defensively.
  door_count = (p[:door_count] || p["door_count"] || p[:doors] || p["doors"] || 0).to_i

  w = (p[:width_in]  || 0).to_f
  d = (p[:depth_in]  || 0).to_f
  h = (p[:height_in] || 0).to_f

  # JSON catalog codes are authoritative. Legacy type-derived numbering remains
  # below only for cabinets created before the catalog migration.
  catalog_code = (p[:catalog_code] || p["catalog_code"]).to_s.strip
  unless catalog_code.empty?
    fmt = lambda do |value|
      number = value.to_f
      (number - number.round).abs < 0.0005 ? number.round.to_i.to_s : ("%.3f" % number).sub(/0+$/, "").sub(/\.$/, "")
    end
    return "#{catalog_code}–#{fmt.call(h)}/#{fmt.call(d)}/#{fmt.call(w)}"
  end

  # Choose a catalog base code from generator intent.
  code_base, category =
    case type
    when "Wall"
      # 1 door => W10, 2 doors => W12 (partition handled via suffix)
      [door_count == 2 ? "W12" : "W10", :wall]
    when "Tall"
      # 1 door => T10, 2 doors => T12 (partition handled via suffix)
      [door_count == 2 ? "T12" : "T10", :tall]
    when "Cubbies"
      # Tall carcass without doors; model family code for cubbies
      ["CUB", :tall]
    when "Sink Base"
      # If width is in the partition-required range, prefer the SB64 family.
      w >= CabinetModelCatalog::PARTITION_MIN_W ? ["SB64", :base] : ["SB60", :base]
    when "ADA Sink"
      ["10580", :base]
    when "Pie-Cut Corner Base"
      ["BCB", :base]
    when "Diagonal Corner Base"
      ["BDC", :base]
    when "Blind Corner Base"
      ["BCB", :base]
    else # "Base" and any unrecognized types default to Base logic
      dc = (p[:drawer_count] || 0).to_i
      if dc >= 4
        ["D40", :base]
      elsif dc == 5
        ["D50", :base]
      elsif dc >= 2
        ["D30", :base]
      elsif dc == 1
        ["B12", :base]
      else
        ["B10", :base]
      end
    end


  # Normalize to catalog dimensions when the generator is using "finished" sizes.
  # Base cabinets in the catalog use carcass heights (32 or 24). The generator UI
  # often uses overall heights (34.5 or 26.5). Map those back to carcass heights.
  if category == :base
    if (h - 34.5).abs < 0.76
      h = 32.0
    elsif (h - 26.5).abs < 0.76
      h = 24.0
    end
  end

  # Snap close-to-integer values to integers to keep model numbers clean.
  h = h.round if (h - h.round).abs < 0.02
  d = d.round if (d - d.round).abs < 0.02
  w = w.round if (w - w.round).abs < 0.02

  defn = CabinetModelCatalog::DEFINITIONS.find { |x| x[:code_base] == code_base } ||
         { code_base: code_base, category: category, partition: :never }

  code = defn[:code_base] + CabinetModelCatalog.partition_suffix(defn, w)

  # Dimension formatting: prefer integers when possible (catalog uses whole inches).
  fmt = lambda do |x|
    xf = x.to_f
    return "0" if xf.nan? || xf.infinite?
    (xf - xf.round).abs < 0.0005 ? xf.round.to_i.to_s : ("%.3f" % xf).sub(/0+$/, "").sub(/\.$/, "")
  end

  "#{code}–#{fmt.call(h)}/#{fmt.call(d)}/#{fmt.call(w)}"
rescue
  ""
end
    # SketchUp UI calls these "Tags". Ruby API uses model.layers.
    def ensure_tag(model, name)
      tags = model.layers
      tag = tags[name]
      tag = tags.add(name) unless tag
      tag
	      end

	      # ----------------------------
    # Internal caches / edit-support
    # ----------------------------

    def part_def_cache_for(model)
      @part_def_cache ||= {}
      @part_def_cache[model.object_id] ||= {}
    end

    def wedge_def_cache_for(model)
      @wedge_def_cache ||= {}
      @wedge_def_cache[model.object_id] ||= {}
    end

    def definition_belongs_to_model?(defn, model)
      return true unless defn.respond_to?(:model)
      defn.model == model
    end

    def clear_group_entities(group)
      ents = group.entities
      items = ents.to_a
      ents.erase_entities(items) unless items.empty?
      nil
    end

    def write_cabinet_attributes(group, params)
      dict = CABINET_ATTR_DICT
      group.set_attribute(dict, CABINET_ATTR_SCHEMA, 1)
      group.set_attribute(dict, CABINET_ATTR_GENERATED_BY, PLUGIN_NAME)
      group.set_attribute(dict, CABINET_ATTR_GENERATED_AT, Time.now.to_s)
      group.set_attribute(dict, CABINET_ATTR_PARAMS_JSON, params.to_json)
      mn = (params[:model_number] || params["model_number"]).to_s
      group.set_attribute(dict, CABINET_ATTR_MODEL_NUMBER, mn) unless mn.empty?
      SkilledServices::Services::MetadataService.write(group, params)
      nil
    end

    def read_cabinet_attributes(group)
      json = group.get_attribute(CABINET_ATTR_DICT, CABINET_ATTR_PARAMS_JSON)
      return nil unless json.is_a?(String) && !json.empty?
      JSON.parse(json, symbolize_names: true)
    rescue JSON::ParserError
      nil
    end

    
    def ensure_default_scenes(model)
      return nil unless model && model.respond_to?(:pages) && model.respond_to?(:active_view)

      # Only create once per model
      already = model.get_attribute(CABINET_ATTR_DICT, "scenes_created")
      return nil if already

      pages = model.pages
      view  = model.active_view

      # Compute a sensible target based on current model bounds
      bb = model.bounds
      if bb.nil? || bb.empty?
        center = Geom::Point3d.new(0, 0, 0)
        radius = in_to_length(48.0)
      else
        center = bb.center
        radius = bb.diagonal * 0.5
        radius = in_to_length(48.0) if radius.to_f <= 0.0
      end

      # Preserve current camera so we don't disturb user view
      cam0 = view.camera
      persp0 = cam0.perspective?

      begin
        # FRONT scene: look along -Y, Z up
        front_page = pages.find { |p| p.name.to_s.strip.casecmp("Front").zero? } || pages.add("Front")

        # FRONT scene: look at the cabinet front (doors/drawer fronts).
        # Cabinet depth is modeled along +Y in this generator, so the cabinet front is at bb.max.y.
        front_y = bb.max.y
        dist    = radius * 3.0

        eye    = Geom::Point3d.new(center.x, front_y + dist, center.z)
        target = Geom::Point3d.new(center.x, front_y,       center.z)

        cam = Sketchup::Camera.new(eye, target, Z_AXIS)
        cam.perspective = false

        # Temporarily apply, then capture into the scene
        view.camera = cam
        view.zoom_extents

        # Capture the camera into the "Front" scene (update if it already exists)
        begin
          pages.selected_page = front_page if pages.respond_to?(:selected_page=)
        rescue
          # ignore (older SU versions)
        end

        begin
          # Newer SketchUp supports selective update flags
          front_page.update(camera: true)
        rescue
          # Fallback: update without flags
          front_page.update if front_page.respond_to?(:update)
        end


        # TOP scene: look down -Z, Y up (so "up" on screen is +Y)
        unless pages.any? { |p| p.name.to_s.strip.casecmp("Top").zero? }
          eye = Geom::Point3d.new(center.x, center.y, center.z + radius * 3.0)
          cam = Sketchup::Camera.new(eye, center, Y_AXIS)
          cam.perspective = false
          view.camera = cam
          view.zoom_extents
          pages.add("Top")
        end
      ensure
        # Restore camera
        view.camera = cam0
        cam0.perspective = persp0 if cam0.respond_to?(:perspective=)
      end

      model.set_attribute(CABINET_ATTR_DICT, "scenes_created", true)
      nil
    end

def cabinet_group?(entity)
      return false unless entity.is_a?(Sketchup::Group)
      json = entity.get_attribute(CABINET_ATTR_DICT, CABINET_ATTR_PARAMS_JSON)
      json.is_a?(String) && !json.empty?
    end

    # Returns the cabinet Group even if the user selected a nested entity
    # (e.g., a door face while editing the cabinet group).
    def selected_cabinet_group(model)
      return nil unless model

      # If the user is inside a group/component editing context, prefer that path.
      begin
        if model.respond_to?(:active_path) && model.active_path
          model.active_path.reverse_each do |inst|
            return inst if cabinet_group?(inst)
          end
        end
      rescue
        # ignore
      end

      # Direct selection of the group
      model.selection.each do |ent|
        return ent if cabinet_group?(ent)
      end

      # Nested selections: walk up parents from any selected entity.
      model.selection.each do |ent|
        cur = ent
        20.times do
          break if cur.nil?
          return cur if cabinet_group?(cur)

          # Entities -> parent, Entity -> parent (Entities)
          if cur.respond_to?(:parent)
            cur = cur.parent
          else
            cur = nil
          end

          # If we landed on an Entities collection, step up to its parent instance.
          if cur.is_a?(Sketchup::Entities) && cur.respond_to?(:parent)
            cur = cur.parent
          end
        end
      end

      nil
    end

    def find_entity_by_pid(model, pid)
      pid = pid.to_i
      return nil if pid <= 0
      return model.find_entity_by_persistent_id(pid) if model.respond_to?(:find_entity_by_persistent_id)
      nil
    end

    def load_selected_into_dialog
      model = Sketchup.active_model
      unless model
        UI.messagebox("No active model.")
        return nil
      end

      grp = selected_cabinet_group(model)
      unless grp && grp.valid?
        UI.messagebox("Select a cabinet group generated by ForgeCase, then try again.")
        init = merged_params_for_type("Base")
        @dialog.execute_script("set_form(#{init.to_json})")
        return nil
      end

      params = read_cabinet_attributes(grp)
      unless params
        UI.messagebox("Selected cabinet does not contain editable parameters.")
        init = merged_params_for_type("Base")
        @dialog.execute_script("set_form(#{init.to_json})")
        return nil
      end

      type = params[:cabinet_type].to_s

# Cubbies: Tall cabinet carcass without doors; shelves/partitions auto-computed from target cubby size.
if type == "Cubbies"
  h_in = params[:height_in].to_f
  w_in = params[:width_in].to_f
  raise ArgumentError, "Cubbies height must be between 24\" and 90\". Provided: #{h_in}\"" if h_in < 24.0 || h_in > 90.0
  raise ArgumentError, "Cubbies width must be between 12\" and 48\". Provided: #{w_in}\"" if w_in < 12.0 || w_in > 48.0
  params[:show_doors] = false
  params[:drawer_count] = 0
  params[:door_count] = 0
end


      # ADA applies ONLY to the ADA Sink cabinet type
      is_ada_sink = (type == "ADA Sink")
      merged = defaults_for(type).merge(params)

      label = grp.name.to_s.strip.empty? ? "ForgeCase Cabinet" : grp.name.to_s.strip
      pid = grp.respond_to?(:persistent_id) ? grp.persistent_id : 0

      @dialog.execute_script("load_selected_cabinet(#{merged.to_json}, #{pid.to_i}, #{label.to_json})")
      grp
    end

# ----------------------------
# OpenCutList material typing
# ----------------------------
# OpenCutList stores extra properties for SketchUp materials in the attribute dictionary
# named 'ladb_opencutlist'. The 'type' attribute is an integer enum.
# NOTE: OpenCutList has evolved over time; if you ever need to verify the enum values for
# your installed version, create one material of each type inside OpenCutList and inspect
# its 'ladb_opencutlist' -> 'type' with an attribute inspector.
OCL_ATTR_DICT = 'ladb_opencutlist'.freeze

# Default enum mapping (Solid Wood, Sheet Goods, Dimensional, Edge Banding, Hardware, Veneer)
# If your OpenCutList version uses a different mapping, adjust these integers.
OCL_MATERIAL_TYPE = {
  none:        0,
  solid_wood:  1,
  sheet_goods: 2,
  dimensional: 3,
  edge_banding: 4,
  hardware:    5,
  veneer:      6
}.freeze

def set_opencutlist_material_type(material, type_sym)
  return material if material.nil?
  return material if type_sym.nil?

  key = type_sym.to_sym
  type_val = OCL_MATERIAL_TYPE[key]
  return material if type_val.nil?

  # SketchUp materials support attribute dictionaries.
  material.set_attribute(OCL_ATTR_DICT, 'type', type_val)
  material
end

def ensure_material(model, name, rgb = nil, force_update: false, ocl_type: nil)
  # Guard against nil/blank material names
  return nil if name.nil? || name.to_s.strip.empty?

  mats = model.materials
  m = mats[name]
  unless m
    m = mats.add(name)
  end

  # Update or seed color
  if rgb.is_a?(Array) && rgb.length == 3
    if force_update
      m.color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2])
    elsif m.color.nil?
      m.color = Sketchup::Color.new(rgb[0], rgb[1], rgb[2])
    end
  end

  # If no explicit OpenCutList type was provided, infer it from the name.
  inferred =
    if ocl_type
      ocl_type
    else
      n = name.to_s
      if n.start_with?("EB_")
        :edge_banding
      elsif n =~ /hardware/i
        :hardware
      elsif n =~ /\b(veneer)\b/i
        :veneer
      elsif n =~ /\b(solid\s*wood|hardwood|maple|oak|walnut)\b/i
        :solid_wood
      else
        # Default all panel/finish stock (MELAMINE/HPL/PLYWOOD/PANEL_*) to sheet goods.
        :sheet_goods
      end
    end

  set_opencutlist_material_type(m, inferred)
  m
end

# Convert "#RRGGBB" or "RRGGBB" to [r,g,b] array (0-255). Returns nil if invalid.
def self.hex_to_rgb(hex)
  return nil if hex.nil?
  h = hex.to_s.strip
  h = h[1..-1] if h.start_with?('#')
  return nil unless h.match?(/\A[0-9a-fA-F]{6}\z/)
  [h[0, 2].to_i(16), h[2, 2].to_i(16), h[4, 2].to_i(16)]
end

# ----------------------------
    # Materials (thickness-based)
    # Panels of similar thickness share the same material name.
    # This helps OpenCutList aggregate parts by sheet stock.
    # ----------------------------
        def thickness_key(thk_in)
      (thk_in.to_f * 1000.0).round.to_s
    end

    def panel_material_name_from_thickness(thk_in)
      case thk_in.to_f.round(3)
      when 0.75 then "MAT_Panel_750"
      when 0.50 then "MAT_Panel_500"
      when 0.25 then "MAT_Panel_250"
      else
        "MAT_Panel_#{(thk_in.to_f * 1000.0).round}"
      end
    end

    def edge_band_material_name_from_thickness(thk_in)
      case thk_in.to_f.round(3)
      when 0.75 then "EB_750"
      when 0.50 then "EB_500"
      when 0.25 then "EB_250"
      else
        "EB_#{(thk_in.to_f * 1000.0).round}"
      end
    end

    # Single base material name for all parts, derived from user-selected panel thickness.
    def base_panel_material_name(panel_thk_in)
      panel_material_name_from_thickness(panel_thk_in)
    end

    def edge_band_material_name(panel_thk_in)
      edge_band_material_name_from_thickness(panel_thk_in)
    end

def thickness_material_name(thk_in)
      # Normalize to thousandths of an inch to avoid floating noise.
      mil = (thk_in.to_f * 1000.0).round
      "MAT_T#{mil}" # e.g., 0.75in -> MAT_T750
    end

    def ensure_thickness_material(model, thk_in, rgb: [220, 206, 170])
      name = thickness_material_name(thk_in)
      ensure_material(model, name, rgb, ocl_type: :sheet_goods)
    end

    def safe_positive!(value, label)
      raise ArgumentError, "#{label} must be > 0" unless value.to_f > 0
    end

    # Parse drawer front heights for multi-drawer base cabinets.
    # Accepts Array (numbers/strings) or String like "6, 8, 10".
    # Values are in inches, ordered top-to-bottom.
    def parse_drawer_front_heights_in(raw)
      return [] if raw.nil?
    
      tokens =
        if raw.is_a?(Array)
          raw
        else
          s = raw.to_s.strip
          return [] if s.empty?
          s.split(/[;,\s]+/)
        end
    
      vals = []
      tokens.each do |t|
        next if t.nil?
        tok = t.to_s.strip
        next if tok.empty?
        next if tok == "?"
        tok = tok.gsub(/["']/, "")
        tok = tok.strip
        next if tok == "?"
        tok = tok.gsub(/\bin\b\.?\z/i, "")
        tok = tok.strip
    
        unless tok.match?(/\A-?\d+(?:\.\d+)?\z/)
          raise ArgumentError, "Invalid drawer front height value: #{t.inspect}"
        end
    
        vals << tok.to_f
      end
      vals
    end
    
    # For drawer_count >= 2, returns an Array of drawer front heights (inches) top-to-bottom.
    #
    # Behavior:
    # - If no custom heights are provided, drawers are equal-height.
    # - If N-1 heights are provided, the bottom drawer is auto-calculated to fit.
    # - If N heights are provided and their sum is short, the remainder is added to the bottom drawer.
    # - If N heights exceed available height, an error is raised.
    def compute_drawer_front_heights(drawer_count, box_h, reveal_edge, drawer_gap, raw_heights)
      n = drawer_count.to_i
      return [] if n < 2

      raise ArgumentError, "Drawer gap must be >= 0" if drawer_gap.to_f < 0.0

      usable_h = (box_h - (2.0 * reveal_edge)) - (drawer_gap * (n - 1))
      raise ArgumentError, "Not enough height for #{n} drawers with current gaps/reveals" if usable_h <= (n * 2.0)

      heights = parse_drawer_front_heights_in(raw_heights)
      if heights.empty?
        each_h = usable_h / n.to_f
        return Array.new(n, each_h)
      end

      # Custom sizing:
      # - If the user provides N values, we treat them as the exact drawer heights (top-to-bottom).
      #   If their sum is short, the remainder is added to the last drawer.
      # - If the user provides N-1 values, the last drawer is auto-calculated.
      # - If fewer than N-1 values are provided, it is an error.
      if heights.length < (n - 1)
        raise ArgumentError, "For #{n} drawers, provide at least #{n - 1} heights (top drawers), or provide all #{n} heights."
      end

      if heights.length >= n
        use = heights[0, n]
        sum = use.reduce(0.0, :+)
        if sum > usable_h + (1.0 / 64.0)
          raise ArgumentError, "Drawer front heights exceed available height (sum #{sum.round(3)}\" vs #{usable_h.round(3)}\")."
        end
        # If short, add remainder to the last drawer.
        use[-1] += (usable_h - sum)
        heights = use
      else
        top_heights = heights[0, (n - 1)]
        sum_top = top_heights.reduce(0.0, :+)
        bottom = usable_h - sum_top

        tol = (1.0 / 64.0)
        if bottom <= tol
          raise ArgumentError, "Drawer front heights do not leave a positive height for the bottom drawer. Available: #{usable_h.round(3)}\", top sum: #{sum_top.round(3)}\"."
        end

        heights = top_heights + [bottom]
      end

      heights.each_with_index do |h, idx|
        raise ArgumentError, "Drawer front height ##{idx + 1} must be > 0" unless h.to_f > 0.0
        raise ArgumentError, "Drawer front height ##{idx + 1} too small (#{h.round(3)}\"). Minimum is 2.0\"." if h.to_f < 2.0
      end

      sum_final = heights.reduce(0.0, :+)
      tol = (1.0 / 64.0)
      if (sum_final - usable_h).abs > tol
        raise ArgumentError, "Drawer front heights do not fit available height (sum #{sum_final.round(3)}\" vs #{usable_h.round(3)}\")."
      end

      heights
    end

    def clamp(v, lo, hi)
	      v  = v.to_f
	      lo = lo.to_f
	      hi = hi.to_f
	      [[v, lo].max, hi].min
    end

    # ----------------------------
    # OpenCutList compatibility:
    # Leaf parts must be COMPONENT INSTANCES (solid geometry + meaningful names).
    # Assemblies may remain groups.
    # ----------------------------

    def part_def_key(name, *dims)
      parts = [name]
      dims.each do |d|
        parts << (d.is_a?(Numeric) ? d.round(4) : d.to_s)
      end
      parts.join("|")
    end

    def edge_band_cache_key(edge_band, edge_material)
      directions = Array(edge_band).map(&:to_s).sort.join(",")
      material_name = edge_material && edge_material.respond_to?(:name) ? edge_material.name.to_s : ""
      "EB[#{directions}]|MAT[#{material_name}]"
    end

    def ensure_part_definition(model, name:, lx:, ly:, lz:, edge_band: nil, edge_material: nil)
      cache = part_def_cache_for(model)
      band_key = edge_band_cache_key(edge_band, edge_material)
      key = part_def_key(name, lx, ly, lz, band_key)

      if (cached = cache[key]) && cached.valid? && definition_belongs_to_model?(cached, model)
        return cached
      end

      band_digest = Digest::SHA1.hexdigest(band_key)[0, 10]
      defn_name = "PART__#{name}__#{lx.round(3)}x#{ly.round(3)}x#{lz.round(3)}__#{band_digest}"
      defs = model.definitions
      existing = defs[defn_name]
      if existing && existing.valid?
        cache[key] = existing
        return existing
      end

      defn = defs.add(defn_name)
      e = defn.entities

      o = Geom::Point3d.new(0, 0, 0)
      pts = [
        o,
        o.offset([lx, 0, 0]),
        o.offset([lx, ly, 0]),
        o.offset([0,  ly, 0])
      ]
      face = e.add_face(pts)
      raise "Failed to create part face for #{name}" unless face && face.valid?
      face.reverse! if face.normal.z < 0
      face.pushpull(lz)
      # Apply edge-banding material on selected "thin" faces so OpenCutList can detect banding.
      # edge_band: Array of symbols :xp,:xn,:yp,:yn,:zp,:zn (normals in definition space).
      if edge_material && edge_band && !edge_band.empty?
        faces = defn.entities.grep(Sketchup::Face)
        edge_band.each do |dir|
          target = case dir
                   when :xp then X_AXIS
                   when :xn then X_AXIS.reverse
                   when :yp then Y_AXIS
                   when :yn then Y_AXIS.reverse
                   when :zp then Z_AXIS
                   when :zn then Z_AXIS.reverse
                   else nil
                   end
          next unless target
          f = faces.find { |fc| fc.normal.samedirection?(target) }
          next unless f
          f.material = edge_material
          f.back_material = edge_material
        end
      end


      cache[key] = defn
      defn
    end


    

    # Creates (and caches) a notched side panel definition (integral toe notch).
    # Geometry: panel thickness = thk (X), depth = depth (Y), height = box_h + toe_h (Z),
    # with a toe notch removed at the bottom-front: z in [0,toe_h], y in [platform_depth, depth].
    def ensure_notched_side_definition(model, name:, thk:, depth:, box_h:, toe_h:, toe_recess:, edge_band: nil, edge_material: nil)
      cache = part_def_cache_for(model)
      platform_depth = depth - toe_recess
      band_key = edge_band_cache_key(edge_band, edge_material)
      key = part_def_key("#{name}__NOTCHED", thk, depth, box_h, toe_h, toe_recess, band_key)

      if (cached = cache[key]) && cached.valid? && definition_belongs_to_model?(cached, model)
        return cached
      end

      band_digest = Digest::SHA1.hexdigest(band_key)[0, 10]
      defn_name = "PART__#{name}__NOTCHED__#{thk.round(3)}x#{depth.round(3)}x#{(box_h + toe_h).round(3)}__R#{toe_recess.round(3)}__#{band_digest}"
      defs = model.definitions
      existing = defs[defn_name]
      if existing && existing.valid?
        cache[key] = existing
        return existing
      end

      defn = defs.add(defn_name)

      # Lower back section (toe platform zone)
      if toe_h > 0.0 && platform_depth > 0.0
        pts_low = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(thk, 0, 0),
          Geom::Point3d.new(thk, platform_depth, 0),
          Geom::Point3d.new(0, platform_depth, 0),
        ]
        f_low = defn.entities.add_face(pts_low)
        f_low.reverse! if f_low && f_low.normal.z < 0
        f_low.pushpull(toe_h) if f_low
      end

      # Upper full-depth section (carcass zone)
      pts_up = [
        Geom::Point3d.new(0, 0, toe_h),
        Geom::Point3d.new(thk, 0, toe_h),
        Geom::Point3d.new(thk, depth, toe_h),
        Geom::Point3d.new(0, depth, toe_h),
      ]
      f_up = defn.entities.add_face(pts_up)
      f_up.reverse! if f_up && f_up.normal.z < 0
      f_up.pushpull(box_h) if f_up

      # Apply edge-banding materials similarly to ensure_part_definition.
      if edge_material && edge_band && !edge_band.empty?
        faces = defn.entities.grep(Sketchup::Face)
        edge_band.each do |dir|
          target = case dir
                   when :xp then X_AXIS
                   when :xn then X_AXIS.reverse
                   when :yp then Y_AXIS
                   when :yn then Y_AXIS.reverse
                   when :zp then Z_AXIS
                   when :zn then Z_AXIS.reverse
                   else nil
                   end
          next unless target

          faces.each do |fa|
            n = fa.normal
            next unless n && n.parallel?(target)
            fa.material = edge_material
            fa.back_material = edge_material
          end
        end
      end

      cache[key] = defn
      defn
    end

    def add_notched_side_component(parent_ents, model, name:, x:, y:, z:, thk:, depth:, box_h:, toe_h:, toe_recess:, tag: nil, material: nil, edge_band: nil, edge_material: nil)
      defn = ensure_notched_side_definition(model,
        name: name, thk: thk, depth: depth, box_h: box_h, toe_h: toe_h, toe_recess: toe_recess,
        edge_band: edge_band, edge_material: edge_material
      )
      tr = Geom::Transformation.translation([x, y, z])
      inst = parent_ents.add_instance(defn, tr)
      inst.name = name
      inst.layer = tag if tag
      inst.material = material if material
      inst
    end

def add_part_component(parent_ents, model, name:, x:, y:, z:, lx:, ly:, lz:, tag: nil, material: nil, edge_band: nil, edge_material: nil)
      defn = ensure_part_definition(model, name: name, lx: lx, ly: ly, lz: lz, edge_band: edge_band, edge_material: edge_material)
      SkilledServices::Geometry::PartBuilder.add(parent_ents, defn,
        name: name, x: x, y: y, z: z, tag: tag, material: material)
    end

    # Creates a reusable component from an arbitrary plan polygon extruded in Z.
    # Points are local [x, y] pairs and should describe a non-self-intersecting loop.
    def add_polygon_part_component(parent_ents, model, name:, points:, x:, y:, z:, lz:, tag: nil, material: nil)
      point_key = points.map { |px, py| "#{px.to_f.round(4)},#{py.to_f.round(4)}" }.join(";")
      key = part_def_key("#{name}__POLYGON", point_key, lz)
      cache = part_def_cache_for(model)
      defn = cache[key]

      unless defn && defn.valid? && definition_belongs_to_model?(defn, model)
        digest = Digest::SHA1.hexdigest(key)[0, 12]
        defn_name = "PART__#{name}__POLYGON__#{digest}"
        defn = model.definitions[defn_name]
        unless defn && defn.valid?
          defn = model.definitions.add(defn_name)
          face = defn.entities.add_face(points.map { |px, py| Geom::Point3d.new(px, py, 0) })
          raise "Failed to create polygon part #{name}" unless face && face.valid?
          face.reverse! if face.normal.z < 0
          face.pushpull(lz)
        end
        cache[key] = defn
      end

      inst = parent_ents.add_instance(defn, Geom::Transformation.translation([x, y, z]))
      inst.name = name
      inst.layer = tag if tag
      inst.material = material if material
      inst
    end

    # ----------------------------
    # Hardware components
    # ----------------------------

    def hardware_def_cache_for(model)
      @hardware_def_cache ||= {}
      @hardware_def_cache[model.object_id] ||= {}
    end

    # Stable cache key for hardware definitions.
    # Accepts Numeric/String/Array/Hash and normalizes recursively.
    def hardware_def_key(name, dims = nil, detail = nil)
      norm = lambda do |v|
        case v
        when NilClass
          nil
        when Numeric
          v.to_f.round(4)
        when String
          v
        when Array
          v.map { |x| norm.call(x) }
        when Hash
          v.keys.sort_by(&:to_s).map { |k| [k.to_s, norm.call(v[k])] }
        else
          v.to_s
        end
      end

      payload = [name.to_s, norm.call(dims), norm.call(detail)]
      Digest::MD5.hexdigest(payload.to_json)
    end


    def ensure_hardware_definition(model, name:, kind:, dims: {}, detail: {})
      cache = hardware_def_cache_for(model)
      key = hardware_def_key("#{kind}::#{name}", dims, detail)

      if (cached = cache[key]) && cached.valid? && definition_belongs_to_model?(cached, model)
        return cached
      end

      defn_name = "HW__#{kind}__#{name.gsub(/[^A-Za-z0-9_\-]+/, '_')}__#{dims.values.map { |v| v.to_f.round(3) }.join('x')}"
      defs = model.definitions
      existing = defs[defn_name]
      if existing && existing.valid?
        cache[key] = existing
        return existing
      end

      defn = defs.add(defn_name)
      e = defn.entities

      case kind.to_s
      when "bumper"
        # Simple cylinder to represent clear rubber bumper.
        dia = dims[:dia].to_f
        depth = dims[:depth].to_f
        r = dia / 2.0
        circle = e.add_circle(Geom::Point3d.new(0, 0, 0), Y_AXIS, r, 18)
        face = e.add_face(circle)
        face.reverse! if face.normal.y < 0
        face.pushpull(depth)
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      when "wire_pull"
        # Approximated 4" CTC wire pull: bar + two legs (three cylinders).
        ctc = detail[:ctc].to_f
        bar_dia = detail[:bar_dia].to_f
        stand_off = detail[:stand_off].to_f
        leg_len = detail[:leg_len].to_f
        r = bar_dia / 2.0

        # Bar runs along X. Offset it away from the mounting surface (Y=0)
        # so the pull sits "on" the front of the door/drawer.
        bar_circle = e.add_circle(Geom::Point3d.new(0, stand_off, 0), X_AXIS, r, 18)
        bar_face = e.add_face(bar_circle)
        bar_face.reverse! if bar_face.normal.x < 0
        bar_face.pushpull(ctc)

        # Two legs run along Y (mounting toward cabinet).
        [0.0, ctc].each do |x0|
          leg_circle = e.add_circle(Geom::Point3d.new(x0, stand_off, 0), Y_AXIS, r, 18)
          leg_face = e.add_face(leg_circle)
          leg_face.reverse! if leg_face.normal.y < 0
          leg_face.pushpull(-leg_len)
        end
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      
      when "bar_pull"
        # Approximate bar pull as bar + two posts (same geometry strategy as wire_pull).
        ctc = detail[:ctc].to_f
        bar_dia = detail[:bar_dia].to_f
        stand_off = detail[:stand_off].to_f
        leg_len = detail[:leg_len].to_f
        r = bar_dia / 2.0

        # Bar runs along X at y = stand_off
        bar_y = stand_off
        bar_z = 0.0
        bar_len = ctc

        # Main bar
        add_cylinder(e, Geom::Point3d.new(-bar_len / 2.0, bar_y, bar_z),
                        Geom::Vector3d.new(1, 0, 0), bar_len, r, 18)

        # Two posts (legs) at bar ends down to mounting plane (y=0)
        [-bar_len / 2.0, bar_len / 2.0].each do |x|
          # post from y=0 to y=bar_y
          add_cylinder(e, Geom::Point3d.new(x, 0.0, bar_z),
                          Geom::Vector3d.new(0, 1, 0), bar_y, r, 18)
          # short leg into the mounting surface (towards -Y) to suggest through-hole
          add_cylinder(e, Geom::Point3d.new(x, 0.0, bar_z),
                          Geom::Vector3d.new(0, -1, 0), leg_len, r * 0.85, 18)
        end
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      when "knob"
        dia = detail[:dia].to_f
        proj = detail[:proj].to_f
        r = dia / 2.0

        # Simple knob: cylinder projecting out +Y from the mounting plane at y=0.
        add_cylinder(e, Geom::Point3d.new(0.0, 0.0, 0.0),
                        Geom::Vector3d.new(0, 1, 0), proj, r, 18)
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

when "hinge"
        # Simplified concealed hinge: barrel (cylinder) + mounting plate.
        #
        # Local hardware axes (matches cabinet local axes):
        #   X = into cabinet opening (interior)
        #   Y = cabinet depth
        #   Z = up
        #
        # Hinge origin is located on the *interior face of the side panel*.
        # Geometry is built entirely on +X so it will never protrude through the panel.
        cup_dia   = detail[:cup_dia].to_f
        cup_len   = detail[:cup_depth].to_f   # reuse "cup_depth" as barrel length into opening
        plate_wy  = detail[:plate_lx].to_f    # along Y (depth)
        plate_hz  = detail[:plate_ly].to_f    # along Z (height)
        plate_thk = detail[:plate_lz].to_f    # along X (thickness)
        r = cup_dia / 2.0

        # Barrel: cylinder along +X
        circ = e.add_circle(Geom::Point3d.new(0, 0, 0), X_AXIS, r, 18)
        face = e.add_face(circ)
        face.reverse! if face.normal.x < 0
        face.pushpull(cup_len)

        # Plate: rectangular prism on +X, centered on origin in Y/Z
        y0 = -plate_wy / 2.0
        y1 =  plate_wy / 2.0
        z0 = -plate_hz / 2.0
        z1 =  plate_hz / 2.0
        pts = [
          Geom::Point3d.new(0, y0, z0),
          Geom::Point3d.new(0, y1, z0),
          Geom::Point3d.new(0, y1, z1),
          Geom::Point3d.new(0, y0, z1)
        ]
        f = e.add_face(pts)
        f.reverse! if f.normal.x < 0
        f.pushpull(plate_thk)

        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      when "shelf_support"
        # L-bracket-ish pin: small cylinder + tab.
        pin_dia = detail[:pin_dia].to_f
        pin_len = detail[:pin_len].to_f
        tab = detail[:tab].to_f
        r = pin_dia / 2.0

        circ = e.add_circle(Geom::Point3d.new(0, 0, 0), X_AXIS, r, 14)
        face = e.add_face(circ)
        face.reverse! if face.normal.x < 0
        face.pushpull(pin_len)

        pts = [
          Geom::Point3d.new(pin_len, -tab / 2.0, -tab / 2.0),
          Geom::Point3d.new(pin_len + tab, -tab / 2.0, -tab / 2.0),
          Geom::Point3d.new(pin_len + tab,  tab / 2.0, -tab / 2.0),
          Geom::Point3d.new(pin_len,  tab / 2.0, -tab / 2.0)
        ]
        f2 = e.add_face(pts)
        f2.reverse! if f2.normal.z < 0
        f2.pushpull(tab)
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      when "cam_lock"
        # Cylinder body + small cam tab.
        dia = detail[:dia].to_f
        len = detail[:len].to_f
        cam_lx = detail[:cam_lx].to_f
        cam_ly = detail[:cam_ly].to_f
        cam_lz = detail[:cam_lz].to_f
        r = dia / 2.0

        circ = e.add_circle(Geom::Point3d.new(0, 0, 0), Y_AXIS, r, 18)
        face = e.add_face(circ)
        face.reverse! if face.normal.y < 0
        face.pushpull(len)

        pts = [
          Geom::Point3d.new(-cam_lx / 2.0, len, -cam_lz / 2.0),
          Geom::Point3d.new( cam_lx / 2.0, len, -cam_lz / 2.0),
          Geom::Point3d.new( cam_lx / 2.0, len + cam_ly, -cam_lz / 2.0),
          Geom::Point3d.new(-cam_lx / 2.0, len + cam_ly, -cam_lz / 2.0)
        ]
        f2 = e.add_face(pts)
        f2.reverse! if f2.normal.z < 0
        f2.pushpull(cam_lz)
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      when "bracket"
        # Simple L bracket (two plates).
        th = detail[:th].to_f
        leg = detail[:leg].to_f
        # Vertical plate
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(th, 0, 0),
          Geom::Point3d.new(th, 0, leg),
          Geom::Point3d.new(0, 0, leg)
        ]
        f = e.add_face(pts)
        f.reverse! if f.normal.y < 0
        f.pushpull(leg)
        # Horizontal plate
        pts2 = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(leg, 0, 0),
          Geom::Point3d.new(leg, 0, th),
          Geom::Point3d.new(0, 0, th)
        ]
        f2 = e.add_face(pts2)
        f2.reverse! if f2.normal.y < 0
        f2.pushpull(leg)
        e.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }

      else
        # Fallback: block.
        lx = dims[:lx].to_f
        ly = dims[:ly].to_f
        lz = dims[:lz].to_f
        pts = [
          Geom::Point3d.new(0, 0, 0),
          Geom::Point3d.new(lx, 0, 0),
          Geom::Point3d.new(lx, ly, 0),
          Geom::Point3d.new(0,  ly, 0)
        ]
        f = e.add_face(pts)
        f.reverse! if f.normal.z < 0
        f.pushpull(lz)
      end

      cache[key] = defn
      defn
    end

    def add_hardware_component(parent_ents, model, name:, kind:, x:, y:, z:, tag: nil, material: nil, dims: {}, detail: {})
      defn = ensure_hardware_definition(model, name: name, kind: kind, dims: dims, detail: detail)
      tr = Geom::Transformation.translation([x, y, z])
      inst = parent_ents.add_instance(defn, tr)
      inst.name = name
      inst.layer = tag if tag
      inst.material = material if material
      inst
    end

    # Wedge for ADA apron (triangular-ish prism extruded along X).
    def ensure_wedge_definition(model, name:, lx:, ly:, lz:, slope_depth:)
      cache = wedge_def_cache_for(model)
      key = "#{name}|#{lx.round(4)}|#{ly.round(4)}|#{lz.round(4)}|#{slope_depth.round(4)}"

      if (cached = cache[key]) && cached.valid? && definition_belongs_to_model?(cached, model)
        return cached
      end

      defn_name = "PART__#{name}__#{lx.round(3)}x#{ly.round(3)}x#{lz.round(3)}_s#{slope_depth.round(3)}"
      defs = model.definitions
      existing = defs[defn_name]
      if existing && existing.valid?
        cache[key] = existing
        return existing
      end

      defn = defs.add(defn_name)
      e = defn.entities

      raise ArgumentError, "Invalid slope depth for #{name}: slope_depth must be between 0 and ly" if slope_depth <= 0.0 || slope_depth > ly

      # Create the wedge as a profile in the Y/Z plane (at X=0), then push/pull along X.
      y_back = 0.0
      y_front = ly
      y_front_bottom = ly - slope_depth

      pts = [
        Geom::Point3d.new(0, y_back,         0),
        Geom::Point3d.new(0, y_back,         lz),
        Geom::Point3d.new(0, y_front,        lz),
        Geom::Point3d.new(0, y_front_bottom, 0)
      ]
      face = e.add_face(pts)
      raise "Failed to create wedge face for #{name}" unless face && face.valid?
      face.reverse! if face.normal.x < 0
      face.pushpull(lx)

      cache[key] = defn
      defn
    end


    def add_wedge_component(parent_ents, model, name:, x:, y:, z:, lx:, ly:, lz:, slope_depth:, tag: nil, material: nil)
      defn = ensure_wedge_definition(model, name: name, lx: lx, ly: ly, lz: lz, slope_depth: slope_depth)
      tr = Geom::Transformation.translation([x, y, z])
      inst = parent_ents.add_instance(defn, tr)
      inst.name = name
      inst.layer = tag if tag
      inst.material = material if material
      inst
    end

    # ----------------------------
    # Rules
    # ----------------------------
    def door_count_for_width(width_in, threshold_in = 24.0)
      (width_in.to_f >= threshold_in.to_f) ? 2 : 1
    end
    def drawer_split_count_for_width(width_in, threshold_in = 37.0)
      (width_in.to_f >= threshold_in.to_f) ? 2 : 1
    end

    # Manufacturer geometry for the 36x36 L-shaped cabinet uses 19.25" straight
    # carcass runs. Scale that relationship only when a custom footprint is used.
    def pie_cut_notch_size(width, depth)
      footprint = [width.to_f, depth.to_f].min
      straight_run = footprint * (19.25 / 36.0)
      notch = footprint - straight_run
      [notch, in_to_length(6.0)].max
    end

    # A 36x36 diagonal corner has a published 31.32" diagonal face. For a
    # symmetric plan, this determines the equal setback on both wall legs.
    def diagonal_corner_setback(width, depth)
      footprint = [width.to_f, depth.to_f].min
      diagonal = footprint * (31.32 / 36.0)
      footprint - (diagonal / Math.sqrt(2.0))
    end

    def hinge_count_for_door_height(door_h_in)
      h = door_h_in.to_f
      return 0 if h <= 0.0
      return 2 if h <= 30.0
      return 3 if h <= 60.0
      4
    end
    def cabinet_has_toe?(type)
      t = type.to_s
      return false if t.empty?
      # Never show a toe kick on wall cabinets.
      return false if t.downcase.include?("wall")
      # Toe kick as separate base applies to Base/Tall/Sink Base.
      # ADA Sink should be leg-supported / open knee space; toe base is not typical and breaks clearance.
      # Corner bases and Trash Can are base-like and use the standard toe base.
      (t == "Base" || t == "Tall" || t == "Sink Base" || t == "Trash Can" || t == "Cubbies" ||
       t == "Pie-Cut Corner Base" || t == "Diagonal Corner Base" || t == "Blind Corner Base")
    end

    def wall_install_z_offset_in = 54.0

    # ----------------------------
    # Drawer internals (components)
    # ----------------------------

    def add_drawer_box_assembly(parent_ents, model,
      name_prefix:,
      opening_x:, opening_w:,
      y0:, depth:,
      z0:, box_h:,
      side_clear: 0.5,
      box_thk: 0.50,
      bottom_thk: 0.50,
      tag_parts: nil, mat_parts: nil, mat_edge: nil)

      grp = parent_ents.add_group
      grp.name = name_prefix

      # Edge band material (passed from caller; fallback for safety)
      mat_edge ||= ensure_material(model, edge_band_material_name_from_thickness(box_thk), [200, 140, 40], ocl_type: :edge_banding)

      usable_w = opening_w - (2.0 * side_clear)
      raise ArgumentError, "Drawer opening too small for slide clearance" if usable_w <= (2.0 * box_thk)

      x = opening_x + side_clear
      w_box = usable_w
      y = y0
      d_box = depth
      h_box = box_h

      raise ArgumentError, "Drawer box depth too small" if d_box <= (2.0 * box_thk)
      raise ArgumentError, "Drawer box height too small" if h_box <= (box_thk + bottom_thk)

      e = grp.entities

      add_part_component(e, model,
        name: "Drawer Box Side - Left",
        x: x, y: y, z: z0,
        lx: box_thk, ly: d_box, lz: h_box,
        tag: tag_parts, material: mat_parts
      )
      add_part_component(e, model,
        name: "Drawer Box Side - Right",
        x: (x + w_box - box_thk), y: y, z: z0,
        lx: box_thk, ly: d_box, lz: h_box,
        tag: tag_parts, material: mat_parts
      )

      add_part_component(e, model,
        name: "Drawer Box Back",
        x: (x + box_thk), y: y, z: z0,
        lx: (w_box - 2.0 * box_thk), ly: box_thk, lz: h_box,
        tag: tag_parts, material: mat_parts
      )

      add_part_component(e, model,
        name: "Drawer Box Front",
        x: (x + box_thk), y: (y + d_box - box_thk), z: z0,
        lx: (w_box - 2.0 * box_thk), ly: box_thk, lz: h_box,
        tag: tag_parts, material: mat_parts
      )

      add_part_component(e, model,
        name: "Drawer Box Bottom",
        x: (x + box_thk), y: (y + box_thk), z: z0,
        lx: (w_box - 2.0 * box_thk), ly: (d_box - 2.0 * box_thk), lz: bottom_thk,
        tag: tag_parts, material: mat_parts,
            edge_band: [:yp],
            edge_material: mat_edge
      )

      grp
    end

    def add_simple_side_mount_slides_assembly(parent_ents, model,
      name_prefix:,
      x0:, opening_w:,
      y0:, slide_len:,
      z:, rail_h: 1.75, rail_thk: 0.50,
      tag_parts: nil, mat_parts: nil)

      # Häfele 100 lb full-extension ball-bearing slides (visual/takeoff approximation).
      # Left:  #432.21.975
      # Right: #432.21.972
      #
      # Geometry is intentionally lightweight: three nested rectangular members per side
      # (outer / intermediate / inner) to convey a telescoping slide without heavy detail.
      grp = parent_ents.add_group
      grp.name = name_prefix
      e = grp.entities

      # Total side clearance thickness per slide is typically ~1/2". Model that envelope.
      t_outer = rail_thk.to_f
      t_mid   = [t_outer - 0.08, 0.30].max
      t_inner = [t_mid   - 0.08, 0.22].max

      # Small insets so members appear nested.
      inset_mid   = 0.05
      inset_inner = 0.10

      # Length tapers to suggest telescoping members.
      len_outer = slide_len.to_f
      len_mid   = [len_outer - 1.0, 6.0].max
      len_inner = [len_outer - 2.0, 5.0].max

      # Subtle height reduction for inner members.
      h_outer = rail_h.to_f
      h_mid   = [h_outer - 0.10, 1.20].max
      h_inner = [h_outer - 0.20, 1.10].max

      # Helper to add a 3-member slide on a given side.
      add_telescoping_slide = lambda do |side_label, partno, x_base|
        side_grp = e.add_group
        side_grp.name = "Hafele Slide - #{side_label} (##{partno})"
        side_grp.layer = tag_parts if tag_parts
        se = side_grp.entities

        # Outer member (cabinet member)
        add_part_component(se, model,
          name: "Hafele Slide - #{side_label} Outer (##{partno})",
          x: x_base, y: y0, z: z,
          lx: t_outer, ly: len_outer, lz: h_outer,
          tag: tag_parts, material: mat_parts
        )

        # Intermediate member
        add_part_component(se, model,
          name: "Hafele Slide - #{side_label} Middle (##{partno})",
          x: x_base + inset_mid, y: y0 + 0.25, z: z + 0.05,
          lx: t_mid, ly: len_mid, lz: h_mid,
          tag: tag_parts, material: mat_parts
        )

        # Inner member (drawer member)
        add_part_component(se, model,
          name: "Hafele Slide - #{side_label} Inner (##{partno})",
          x: x_base + inset_inner, y: y0 + 0.50, z: z + 0.10,
          lx: t_inner, ly: len_inner, lz: h_inner,
          tag: tag_parts, material: mat_parts
        )

        side_grp
      end

      add_telescoping_slide.call("Left",  "432.21.975", x0)
      add_telescoping_slide.call("Right", "432.21.972", (x0 + opening_w - t_outer))

      grp
    end

    # ----------------------------
    # Defaults + Persistence

    # ----------------------------

    def defaults_for(type)
      base = {
        cabinet_type: type,

        # "height_in" is ALWAYS the finished top-of-counter (or top-of-cab if no top) reference.
        width_in: 30.0,
        depth_in: 24.0,
        height_in: 34.5,

        panel_thk_in: 0.75,
        back_thk_in: 0.75,
        shelf_thk_in: 0.75,
        door_thk_in: 0.75,
        drawer_front_thk_in: 0.75,
        box_thk_in: 0.75,

        # Base default: Stretchers. Wall/Tall forced to Full Top.
        top_mode: "Stretchers",
        stretcher_width_in: 5.0,

        # Toe kick: always separate base (fixed). ADA Sink does not use toe kick.
        toe_height_in: 4.0,
        toe_recess_in: 3.0,

        shelf_count: 1,

        # drawers (Base only)
        drawer_count: 1,                 # 0..5
        drawer_front_height_in: 6.0,     # used only when drawer_count == 1
        drawer_gap_in: 0.125,
        use_slides: true,

        # doors
        show_doors: true,
        hinge_side: "Auto",
        door_swing: "Closed",
        open_angle_deg: 95.0,

        overlay_mode: "Reveals",
        reveal_edge_in: 0.0625,
        reveal_center_in: 0.125,

        # partitions (doors-only): number of interior vertical partitions
        partition_count: 0,

        add_wire_pulls: true,
        add_hinges: true,
        add_door_bumpers: true,
        add_shelf_supports: true,
        add_cam_lock: true,
        add_countertop_brackets: true,
        automatic_double_door_threshold_in: 24.0,
        automatic_drawer_bank_split_threshold_in: 37.0,

        # sink / countertop
        false_front_height_in: 6.0, # dummy drawer above doors
        countertop_thk_in: 1.50,
        trash_drawer_box_bottom_offset_in: 0.5,
        aep_front_return_width_in: 1.5,
        aep_front_return_thk_in: 0.75,

        # Model 10580 ADA Wall Sink Cabinet
        ada_knee_clear_h_in: 27.0,
        ada_apron_h_in: 3.0,
        ada_knee_depth_in: 20.0,
        ada_side_leg_depth_in: 6.0,
        front_rail_height_in: 5.0,
        mount_rail_height_in: 4.0,
        access_panel_type: "Magnetic",
        fastener_type: "Confirmat",
        edge_banding: "1mm PVC",
        core_material: "Particleboard",
        laminate_color: "Project Default",
        moisture_resistant_core: false,
        french_cleat: false,
        second_mount_rail: false,
        safety_tether: false,

        # materials/tags
        # materials/tags omitted (UI section removed)

        auto_name: true,
        name: ""
      }

	      case type
	      when "Corner Base", "Pie-Cut Corner Base"
	        # Legacy Corner Base maps to the standard 36x36 pie-cut configuration.
	        base[:cabinet_type] = "Pie-Cut Corner Base"
	        base[:width_in]  = 36.0
	        base[:depth_in]  = 36.0
	        base[:height_in] = 34.5
	        base[:drawer_count] = 0
	        base[:use_slides] = false
	        base[:partition_count] = 0
	        base[:shelf_count] = 1
	        base[:show_doors] = true
	        base[:top_mode] = "Full Top"
	      when "Diagonal Corner Base"
	        base[:width_in]  = 36.0
	        base[:depth_in]  = 36.0
	        base[:height_in] = 34.5
	        base[:drawer_count] = 0
	        base[:use_slides] = false
	        base[:partition_count] = 0
	        base[:shelf_count] = 1
	        base[:show_doors] = true
	        base[:top_mode] = "Full Top"
	      when "Blind Corner Base"
	        base[:width_in]  = 42.0
	        base[:depth_in]  = 24.0
	        base[:height_in] = 34.5
	        base[:drawer_count] = 0
	        base[:use_slides] = false
	        base[:partition_count] = 0
	        base[:shelf_count] = 1
	        base[:show_doors] = true
	        base[:top_mode] = "Full Top"
	      when "Trash Can"
	        # 15" wide base cabinet with a full-height pull-out front attached to a drawer box.
	        base[:width_in]  = 15.0
	        base[:depth_in]  = 24.0
	        base[:height_in] = 34.5
	        base[:drawer_count] = 1
	        base[:use_slides] = true
	        base[:partition_count] = 0
	        base[:shelf_count] = 0
	        # Keep Show Doors checked by default per global rule; generation uses a full-height drawer front.
	        base[:show_doors] = true
	      	# name suffix handled below
      when "Cubbies"
        # Open cubby carcass: always a full top panel, no doors/drawers.
        base[:depth_in] = 24.0
        base[:height_in] = 48.0
        base[:top_mode] = "Full Top"
        base[:show_doors] = false
        base[:drawer_count] = 0
        base[:use_slides] = false
        base[:partition_count] = 1
        base[:shelf_count] = 3
      when "Wall"
        base[:depth_in] = 12.0
        base[:height_in] = 30.0
        base[:top_mode] = "Full Top"
        base[:drawer_count] = 0
        base[:use_slides] = false
        base[:partition_count] = 0
      when "Tall"
        base[:depth_in] = 24.0
        base[:height_in] = 84.0
        base[:top_mode] = "Full Top"
        base[:drawer_count] = 0
        base[:use_slides] = false
        base[:partition_count] = 1
      when "Sink Base"
        base[:depth_in] = 24.0
        base[:height_in] = 34.5
        base[:drawer_count] = 0
        base[:use_slides] = false
        base[:false_front_height_in] = 6.0
        base[:partition_count] = 0
        base[:countertop_thk_in] = 1.5
      when "ADA Sink"
        # Model 10580: wall-mounted, frameless lavatory cabinet.
        base[:catalog_code] = "10580"
        base[:width_in] = 36.0
        base[:depth_in] = 24.0
        base[:height_in] = 32.0
        base[:panel_thk_in] = 0.75
        base[:drawer_count] = 0
        base[:use_slides] = false
        base[:show_doors] = false
        base[:false_front_height_in] = 5.0
        base[:front_rail_height_in] = 5.0
        base[:mount_rail_height_in] = 4.0
        base[:shelf_count] = 0
        base[:back_thk_in] = 0.0
        base[:partition_count] = 0
        base[:countertop_thk_in] = 0.0
        base[:toe_height_in] = 0.0
        base[:toe_recess_in] = 0.0
        base[:top_mode] = "Open Top"
        base[:access_panel_type] = "Magnetic"
        base[:fastener_type] = "Confirmat"
      when "Appliance End Panel"
        base[:drawer_count] = 0
        base[:use_slides] = false
        base[:shelf_count] = 0
        base[:partition_count] = 0
        base[:show_doors] = false
        base[:toe_height_in] = 0.0
        base[:toe_recess_in] = 0.0
        base[:top_mode] = "Full Top"
      else # Base
        base[:depth_in] = 24.0
        base[:height_in] = 34.5
      end

      suffix =
        case type
        when "Tall" then " Pantry"
        when "Sink Base" then " Sink"
        when "ADA Sink" then " ADA"
        else ""
        end

      base[:name] = "#{type} #{base[:width_in]}x#{base[:depth_in]}x#{base[:height_in]}#{suffix}"
      base
    end
    def read_saved_for_type(type)
      raw = Sketchup.read_default(PREF_KEY, "last_#{type}", nil)
      parse_pref_hash(raw)
	rescue SyntaxError, ScriptError
	  nil
	rescue StandardError
	  nil
	end

    def write_saved_for_type(type, params)
      Sketchup.write_default(PREF_KEY, "last_#{type}", params.to_json)
    rescue
      nil
    end

    # Merge persisted values without allowing incomplete/legacy preference
    # records to erase current defaults. Older builds sometimes saved nil or
    # blank form values, which produced an apparently uninitialized dialog.
    def merge_valid_saved_params(defaults, saved)
      return defaults unless saved.is_a?(Hash)

      saved.each_with_object(defaults.dup) do |(key, value), merged|
        key = key.to_sym if key.respond_to?(:to_sym)
        next unless merged.key?(key)

        default_value = merged[key]
        valid =
          case default_value
          when Numeric
            !value.nil? && !value.to_s.strip.empty? && Float(value, exception: false)
          when TrueClass, FalseClass
            value == true || value == false
          else
            !value.nil?
          end

        merged[key] = value if valid
      end
    end

    def merged_params_for_type(type)
      defaults = defaults_for(type)
      project = SkilledServices::Settings::ProjectDefaults.cabinet_overrides(type)
      merged = defaults.merge(project).merge(merged_global_settings)

      # Apply construction-mode globals that vary by cabinet family.
      # We keep existing defaults as the fallback to avoid unexpected output.
      case type.to_s
      when "Cubbies"
        # Cubbies must always have a full top panel regardless of global base top settings.
        merged[:top_mode] = "Full Top"
      when "Tall"
        merged[:top_mode] = (merged[:tall_top_mode] || defaults[:top_mode]).to_s
      when "Base", "Sink Base", "ADA Sink"
        merged[:top_mode] = (merged[:base_top_mode] || defaults[:top_mode]).to_s
      when "Wall"
        merged[:top_mode] = "Full Top"
      end
      saved = read_saved_for_type(type)

      # Preserve ADA Sink type defaults that should not be overridden by global settings
      # unless the user explicitly saved an override.
      if type.to_s == "ADA Sink" && !(saved.is_a?(Hash) && saved.key?(:back_thk_in))
        merged[:back_thk_in] = defaults[:back_thk_in]
      end

      merged = merge_valid_saved_params(merged, saved)

      # Defensive defaults: If a saved preset has blank/zero values (common after schema changes),
      # fall back to type defaults rather than leaving the UI or build params invalid.
      if type.to_s == "Tall"
        merged[:height_in] = defaults[:height_in] if merged[:height_in].to_f <= 0.0
        merged[:toe_height_in] = defaults[:toe_height_in] if merged[:toe_height_in].to_f <= 0.0
        merged[:toe_recess_in] = defaults[:toe_recess_in] if merged[:toe_recess_in].to_f <= 0.0
      end

      merged
    end

    def standard_params_for_type(type)
      defaults = defaults_for(type)
      project = SkilledServices::Settings::ProjectDefaults.cabinet_overrides(type)
      merged = defaults.merge(project).merge(merged_global_settings)

      case type.to_s
      when "Wall", "Tall", "Cubbies", "Appliance End Panel"
        merged[:top_mode] = "Full Top"
      else
        merged[:top_mode] = (merged[:base_top_mode] || defaults[:top_mode]).to_s
      end
      merged[:back_thk_in] = 0.0 if type.to_s == "ADA Sink"
      merged
    end

    # ----------------------------
    # Cabinet Builder
    # ----------------------------

    module Cabinet
      # Minimal derived-dimension bundle for cabinet construction.
      # Centralizes repeated "spec math" to improve correctness and extensibility.
      class Spec
        attr_reader :w, :d, :finished_top_h, :thk, :back_thk
        attr_reader :toe_height, :toe_recess, :countertop_thk, :has_countertop
        attr_reader :countertop_top_z, :cabinet_top_z, :carcass_z0
        attr_reader :box_h, :inner_w, :top_z
    
        def initialize(w:, d:, finished_top_h:, thk:, back_thk:, toe_height:, toe_recess:, countertop_thk:, has_countertop:)
          @w = w
          @d = d
          @finished_top_h = finished_top_h
          @thk = thk
          @back_thk = back_thk
          @toe_height = toe_height
          @toe_recess = toe_recess
          @countertop_thk = countertop_thk
          @has_countertop = has_countertop
    
          @countertop_top_z = @finished_top_h
          @cabinet_top_z = @has_countertop ? (@countertop_top_z - @countertop_thk) : @countertop_top_z
    
          raise ArgumentError, "Cabinet top (below countertop) must be > toe height" if @cabinet_top_z <= @toe_height
    
          # For base-like types with toe, carcass sits on top of toe base.
          @carcass_z0 = @toe_height
    
          # Carcass height (from carcass_z0 to cabinet_top_z)
          @box_h = @cabinet_top_z - @carcass_z0
          raise ArgumentError, "Carcass height invalid (check heights/toe/countertop)" if @box_h <= @thk
    
          @inner_w = @w - 2.0 * @thk
          raise ArgumentError, "Width too small for carcass thickness" if @inner_w <= 0.0
    
          @top_z = @cabinet_top_z - @thk
        end
      end
    end

    def build_cabinet(model, params, target_group: nil, operation_name: nil)
      # Safety: ensure we always have a model reference for commit/abort in rescue paths
      model ||= Sketchup.active_model
      operation_started = false
      type = params[:cabinet_type].to_s
      if type == "Corner Base"
        type = "Pie-Cut Corner Base"
        params[:cabinet_type] = type
      end

      # Corner footprints are catalog-controlled; width/depth inputs do not
      # alter their geometry.
      case type
      when "Diagonal Corner Base", "Pie-Cut Corner Base"
        params[:width_in] = 36.0
        params[:depth_in] = 36.0
      when "Blind Corner Base"
        params[:width_in] = 42.0
        params[:depth_in] = 24.0
      end

      # ADA applies ONLY to the ADA Sink cabinet type
      is_ada_sink = (type == "ADA Sink")

      width_in = params[:width_in].to_f
      raise ArgumentError, "Max cabinet width is 48\". Provided: #{width_in}\"" if width_in > 48.0

      w = in_to_length(width_in)
      d = in_to_length(params[:depth_in])
      finished_top_h = in_to_length(params[:height_in]) # finished top reference (counter top surface)
      panel_thk = in_to_length(params[:panel_thk_in] || 0.75)
      back_mode = params[:back_mode].to_s
      back_panel_thk_in = (params.key?(:back_thk_in) ? params[:back_thk_in] : 0.75)
      back_panel_thk_in = 0.25 if back_mode == "Back Stretcher + 1/4 Back"
      back_thk = in_to_length(back_panel_thk_in)
      box_thk   = in_to_length(params.key?(:box_thk_in) ? params[:box_thk_in] : (params[:panel_thk_in] || 0.75))
      thk = panel_thk

      top_mode        = params[:top_mode].to_s
      stretcher_width = in_to_length(params[:stretcher_width_in])

      # Force Full Top on Wall + Tall
      top_mode = "Full Top" if (type == "Wall")

      shelves = params[:shelf_count].to_i

      # Partitions (doors-only)
      partition_count = params[:partition_count].to_i
      partition_count = 0 if partition_count < 0

      # Doors params
      show_doors = !!params[:show_doors]
      door_thk   = in_to_length(params[:door_thk_in])
      hinge_side = params[:hinge_side].to_s
      door_swing = params[:door_swing].to_s
      open_angle = params[:open_angle_deg].to_f

      # Specs captured during generation for downstream hardware placement.
      # These are cabinet-local coordinates.
      door_specs = []
      drawer_front_specs = []
      shelf_specs = []

      overlay_mode  = params[:overlay_mode].to_s
      reveal_edge   = in_to_length(params[:reveal_edge_in])
      reveal_center = in_to_length(params[:reveal_center_in])

      # Toe kick (fixed: separate base; ADA does not use it)
      use_toe = cabinet_has_toe?(type)
	  toe_height = in_to_length(params[:toe_height_in])
	  toe_recess = in_to_length(params[:toe_recess_in])

	  # Defensive defaults: if the dialog or saved prefs provide 0/blank values,
	  # fall back to shop defaults so placement doesn't fail.
	  if use_toe
	    default_toe_h = in_to_length((merged_global_settings[:toe_kick_h_in] || 4.0))
	    default_toe_r = in_to_length((merged_global_settings[:toe_kick_recess_in] || 3.0))
	    toe_height = default_toe_h if toe_height.to_f <= 0.0
	    toe_recess = default_toe_r if toe_recess.to_f <= 0.0
	  end

      # Drawer params (Base only)
      drawer_count = params[:drawer_count].to_i


      # If drawers are used, constrain partitions to a single center partition (layout limitation).
      if drawer_count.to_i > 0
        partition_count = [partition_count, 1].min
      end
      # Rule: If cabinet is drawers-only, do not allow shelves.
      # Drawers-only is (2+ drawers) OR (any drawers with doors turned off).
      if type == "Base" && (drawer_count >= 2 || (drawer_count > 0 && !show_doors))
        shelves = 0
      end
      drawer_count = [[drawer_count, 0].max, 5].min
      drawer_front_h_single = in_to_length(params[:drawer_front_height_in])
      drawer_front_heights_raw = params[:drawer_front_heights_in]
      drawer_gap = in_to_length(params[:drawer_gap_in])
      use_slides = !!params[:use_slides]

      if type != "Base" && type != "Trash Can"
        drawer_count = 0
        use_slides = false
      end

      # Sink base and ADA sink: no true drawers (false front handled separately)
      if type == "Sink Base" 
        drawer_count = 0
        use_slides = false
      end

      # Rule: if 2+ drawers, no doors
      if type == "Base" && drawer_count >= 2
        show_doors = false
      end

      # Overlay constraints
      reveal_edge = 0.0 if overlay_mode == "True Full Overlay"
      raise ArgumentError, "Reveal edge must be >= 0" if reveal_edge < 0.0
      raise ArgumentError, "Reveal center must be >= 0" if reveal_center < 0.0

      # Auto-partition rule:
      # For cabinets 37" and wider, include at least one vertical partition (except ADA + Sink Base).
      corner_base_type = ["Diagonal Corner Base", "Pie-Cut Corner Base", "Blind Corner Base"].include?(type)
      auto_partition = (width_in >= 37.0) && !is_ada_sink && (type != "Sink Base") && !corner_base_type
      partition_count = [partition_count, (auto_partition ? 1 : 0)].max
      # Sink/ADA extras
      false_front_h  = in_to_length(params[:false_front_height_in])
      countertop_thk = in_to_length(params[:countertop_thk_in])

      ada_knee_clear_h = in_to_length(params[:ada_knee_clear_h_in])
      ada_apron_h      = in_to_length(params[:ada_apron_h_in])
      ada_knee_depth   = in_to_length(params[:ada_knee_depth_in])
      ada_leg_depth    = in_to_length(params[:ada_side_leg_depth_in])
      front_rail_h    = in_to_length(params[:front_rail_height_in] || params[:false_front_height_in] || 5.0)
      mount_rail_h    = in_to_length(params[:mount_rail_height_in] || 4.0)
      access_panel_type = (params[:access_panel_type] || "Magnetic").to_s

      # validation
      safe_positive!(w, "Width")
      safe_positive!(d, "Depth")
      safe_positive!(finished_top_h, "Height")
      safe_positive!(thk, "Panel thickness")
      raise ArgumentError, "Width must be > 2 * panel thickness" if w <= 2.0 * thk

      if use_toe
        safe_positive!(toe_height, "Toe height")
        safe_positive!(toe_recess, "Toe recess")
        raise ArgumentError, "Toe recess must be < cabinet depth" if toe_recess >= d
        raise ArgumentError, "Toe height must be < finished height" if toe_height >= finished_top_h
      else
        toe_height = 0.0
        toe_recess = 0.0
      end

      if top_mode == "Stretchers"
        safe_positive!(stretcher_width, "Stretcher width")
        raise ArgumentError, "Stretcher width must be < cabinet depth" if stretcher_width >= d
      end

      # Countertop logic: finished_top_h is treated as cabinet height to top of cabinet (like other base cabinets).
      build_countertop = false # preference: never generate countertop geom
      has_countertop = build_countertop
      build_countertop = false # preference: never generate countertop geometry
      if has_countertop
        safe_positive!(countertop_thk, "Countertop thickness")
        safe_positive!(false_front_h, "False drawer front height")
        raise ArgumentError, "Finished height must exceed countertop thickness" if finished_top_h <= countertop_thk
      end

      # Edge band settings (finish ends)
      # Edge banding is applied only to exposed/visible edges of the cabinet SIDE PANELS.
      # - The front edge (:yp) is always banded on frameless carcasses.
      # - If a finished end is requested, also band the top (:zp) and bottom (:zn) edges
      #   of that side panel (typical for exposed ends).
      base_side_eb = [:yp]
      finish_left_end  = !!params[:finish_left_end]
      finish_right_end = !!params[:finish_right_end]
      eb_left  = base_side_eb + (finish_left_end  ? [:zp, :zn] : [])
      eb_right = base_side_eb + (finish_right_end ? [:zp, :zn] : [])

      # When any finished end is selected, we build an integral toe notch in the side panel(s)
      # and do NOT generate the separate toe-base ladder assembly.
      make_separate_toe = (use_toe && !(finish_left_end || finish_right_end))

      if is_ada_sink
        supported_thicknesses = [0.5, 0.625, 0.75]
        raise ArgumentError, "Model 10580 width must be between 30 and 48 inches" unless width_in.between?(30.0, 48.0)
        raise ArgumentError, "Model 10580 height is fixed at 32 inches" unless (finished_top_h.to_f - 32.0).abs < 0.001
        raise ArgumentError, "Model 10580 depth must be 24 or 29 inches" unless [24.0, 29.0].any? { |value| (d.to_f - value).abs < 0.001 }
        raise ArgumentError, "Material thickness must be 1/2, 5/8, or 3/4 inch" unless supported_thicknesses.any? { |value| (thk.to_f - value).abs < 0.001 }
        raise ArgumentError, "Front rail height must be between 4 and 6 inches" unless front_rail_h.to_f.between?(4.0, 6.0)
        safe_positive!(mount_rail_h, "Rear mount rail height")
        raise ArgumentError, "Minimum ADA knee width is 30 inches" if (w - (2.0 * thk)).to_f < 30.0
        raise ArgumentError, "Minimum ADA knee height is 27 inches" if (finished_top_h - front_rail_h).to_f < 27.0
        raise ArgumentError, "Access panel type is invalid" unless ["Magnetic", "Concealed Screws", "Quarter-Turn Cam Latches", "Touch Latches"].include?(access_panel_type)
        params[:catalog_code] = "10580"
        params[:product_name] = "ADA Wall Sink Cabinet"
        params[:cnc_operations] = ["rail joinery pilot holes", "access-panel hardware bores", "shelf-pin suppression"]
        params[:ada_clear_knee_width_in] = (w - (2.0 * thk)).to_f
        params[:ada_clear_knee_height_in] = (finished_top_h - front_rail_h).to_f
        params[:structural_note] = "Provide a second rear rail or concealed steel reinforcement" if width_in > 42.0 && !params[:second_mount_rail]
      end

      # Tags
      tag_carcass     = ensure_tag(model, params[:tag_carcass]     || "CAB_Carcass")
      tag_doors       = ensure_tag(model, params[:tag_doors]       || "CAB_Doors")
      tag_drawers     = ensure_tag(model, params[:tag_drawers]     || "CAB_Drawers")
      tag_drawerboxes = ensure_tag(model, params[:tag_drawerboxes] || "CAB_DrawerBoxes")
      tag_shelves     = ensure_tag(model, params[:tag_shelves]     || "CAB_Shelves")
      tag_toe         = ensure_tag(model, params[:tag_toe]         || "CAB_ToeKick")
      tag_back        = ensure_tag(model, params[:tag_back]        || "CAB_Back")
      tag_hardware    = ensure_tag(model, params[:tag_hardware]    || "CAB_Hardware")
      tag_countertop  = ensure_tag(model, params[:tag_countertop]  || "CAB_Countertop")

      # Materials (panel-driven)
      # Color pickers now control the actual finish materials used by panel SKUs.
      interior_rgb = self.hex_to_rgb(params[:carcass_color_hex] || "#ffffff") || [255, 255, 255]
      mat_interior = ensure_material(model, WHITE_INTERIOR_MELAMINE, interior_rgb, force_update: true, ocl_type: :sheet_goods)

      exterior_rgb = self.hex_to_rgb(params[:front_color_hex]) || [170, 170, 170]
      mat_ext_mel  = ensure_material(model, EXTERIOR_MELAMINE, exterior_rgb, force_update: true, ocl_type: :sheet_goods)
      mat_ext_hpl  = ensure_material(model, EXTERIOR_HPL,      exterior_rgb, force_update: true, ocl_type: :sheet_goods)

      # Toe kick material (fixed requirement: unfinished plywood)
      mat_toe = ensure_material(model, TOE_KICK_MATERIAL, [200, 180, 140], force_update: false, ocl_type: :sheet_goods)

      # Edge banding (retain existing behavior)
      edge_mat_name = edge_band_material_name(params[:panel_thk_in])
      edge_rgb = self.hex_to_rgb(params[:edgeband_color_hex] || "#c88c28") || [200, 140, 40]
      mat_edge     = ensure_material(model, edge_mat_name, edge_rgb, force_update: true, ocl_type: :edge_banding)

      # Hardware and fallback front/carcass materials used by legacy paths
      mat_hardware = ensure_material(model, params[:mat_hardware] || "MAT_Hardware", [90, 90, 90], ocl_type: :hardware)
      mat_parts    = mat_interior
      mat_fronts   = mat_ext_mel

      # Hardware toggles
      add_wire_pulls         = (params.key?(:add_wire_pulls)         ? !!params[:add_wire_pulls]         : true)
      drawer_pull_centered  = (params.key?(:drawer_pull_centered)  ? !!params[:drawer_pull_centered]  : false)
      add_hinges             = (params.key?(:add_hinges)             ? !!params[:add_hinges]             : true)
      add_door_bumpers       = (params.key?(:add_door_bumpers)       ? !!params[:add_door_bumpers]       : true)
      add_shelf_supports     = (params.key?(:add_shelf_supports)     ? !!params[:add_shelf_supports]     : true)
      add_cam_lock           = (params.key?(:add_cam_lock)           ? !!params[:add_cam_lock]           : true)
      add_countertop_brackets= (params.key?(:add_countertop_brackets)? !!params[:add_countertop_brackets]: true)
      add_file_drawer_hw     = (params.key?(:add_file_drawer_hardware) ? !!params[:add_file_drawer_hardware] : true)
      file_drawer_min_front_h = (params[:file_drawer_min_front_h_in] || 9.0).to_f

      # Not generated (per requirements), retained for schema compatibility.
      mat_countertop = ensure_material(model, params[:mat_countertop] || "MAT_Countertop", [180, 180, 180], ocl_type: :sheet_goods)
      op_name = operation_name || (target_group ? "Edit ForgeCase Cabinet" : "Generate ForgeCase Cabinet")

      model.start_operation(op_name, true)
      operation_started = true

      if target_group
        unless target_group.is_a?(Sketchup::Group) && target_group.valid?
          raise ArgumentError, "Edit target must be a valid SketchUp Group."
        end
      end

      root = target_group || model.active_entities.add_group
      clear_group_entities(root) if target_group
      base_name = params[:name].to_s.strip
      base_name = "ForgeCase Cabinet - #{type}" if base_name.empty?
      room = params[:room].to_s.strip
      root.name = room.empty? ? base_name : "#{room} #{base_name}"
      # ----------------------------
      # Derived dimensions (Spec)
      # ----------------------------
      spec = Cabinet::Spec.new(
        w: w,
        d: d,
        finished_top_h: finished_top_h,
        thk: thk,
        back_thk: back_thk,
        toe_height: toe_height,
        toe_recess: toe_recess,
        countertop_thk: countertop_thk,
        has_countertop: has_countertop
      )

      
      # ----------------------------
      # Appliance End Panel (AEP)
      # ----------------------------
      if type == "Appliance End Panel"
        # AEP: 3/4" panel, full depth, from floor to underside of countertop, with 3/4" x 1-1/2" front return.
        aep_panel_thk = panel_thk
        ct_thk = in_to_length(params[:countertop_thk_in] || params[:countertop_thk] || 1.5)
        aep_h = finished_top_h - ct_thk
        aep_h = finished_top_h if aep_h <= 0.to_l
      
        ents = root.entities
      
        # Use exterior melamine for visible AEP skin; fall back to interior.
        mat_panel = mat_ext_mel || mat_interior
      
        # Main panel: thickness (X) x depth (Y) x height (Z)
        add_part_component(
          ents, model,
          name: "Appliance End Panel",
          x: 0.to_l, y: 0.to_l, z: 0.to_l,
          lx: aep_panel_thk, ly: d, lz: aep_h,
          material: mat_panel,
          # Required edgeband: front + top + bottom
          edge_band: [:yp, :zp, :zn],
          edge_material: mat_edge
        )
      
        # Front return: 1-1/2" wide (X) x 3/4" thick (Y) x height, located at cabinet front.
        return_w = in_to_length(params[:aep_front_return_width_in] || 1.5)
        return_thk = in_to_length(params[:aep_front_return_thk_in] || 0.75)
        add_part_component(
          ents, model,
          name: "AEP Front Return",
          x: aep_panel_thk, y: d - return_thk, z: 0.to_l,
          lx: return_w, ly: return_thk, lz: aep_h,
          material: mat_panel,
          # Required edgeband: front + outside end + top + bottom
          edge_band: [:yp, :xp, :zp, :zn],
          edge_material: mat_edge
        )
        # Use the same non-mirrored geometry orientation as every other cabinet.
        orient_cabinet_geometry_for_native_front!(root, w, d, params)
        write_cabinet_attributes(root, params)
        ensure_default_scenes(model)
        model.commit_operation if model && model.respond_to?(:commit_operation)
        operation_started = false
        return root
      end
      

# Auto-compute shelves/partitions for Cubbies based on target size (10-16") and carcass clear space.
if type == "Cubbies"
  target = (params[:cubby_target_in] || params[:cubby_size_in] || 12).to_f
  target = [[target, 10.0].max, 16.0].min
  thk_in = (params[:panel_thk_in] || 0.75).to_f

  # Clear height (in): same derivation as shelf placement logic
    # Use derived Spec values (available here) instead of later locals.
  clear_h = (spec.top_z - (spec.carcass_z0 + thk)).to_f / 1.0.inch
  inner_w_in = spec.inner_w.to_f / 1.0.inch

  choose_divisions = lambda do |clear_len_in|
    best = nil
    (1..20).each do |div|
      opening = (clear_len_in - ((div - 1) * thk_in)) / div.to_f
      next unless opening >= 10.0 && opening <= 16.0
      score = (opening - target).abs
      best = [score, div] if best.nil? || score < best[0]
    end
    return best[1] if best

    # Fallback: largest div that still keeps opening >= 10, else 1
    fallback = 1
    (2..20).each do |div|
      opening = (clear_len_in - ((div - 1) * thk_in)) / div.to_f
      fallback = div if opening >= 10.0
    end
    fallback
  end

  cols = choose_divisions.call(inner_w_in)
  rows = choose_divisions.call(clear_h)

  shelves = [rows - 1, 0].max
  partition_count = [cols - 1, 0].max

  # For cubbies we want full-depth shelves (no 1/2" door clearance)
  show_doors = false
  drawer_count = 0
end
      
      countertop_top_z = spec.countertop_top_z
      cabinet_top_z    = spec.cabinet_top_z
      carcass_z0       = spec.carcass_z0
      box_h            = spec.box_h


      # ----------------------------
      # Toe Base (always separate) - NOT for ADA Sink
      # ----------------------------
      if make_separate_toe
        toe = root.entities.add_group
        toe.name = "Toe Base"
        toe.layer = tag_toe

        te = toe.entities
        platform_depth = d - toe_recess
        raise ArgumentError, "Toe platform depth must be > panel thickness" if platform_depth <= thk

        if type == "Diagonal Corner Base"
          setback = diagonal_corner_setback(w, d)
          add_part_component(te, model,
            name: "Toe End - Left", x: 0, y: 0, z: 0,
            lx: thk, ly: (d - toe_recess), lz: toe_height,
            tag: tag_toe, material: mat_toe)
          add_part_component(te, model,
            name: "Toe End - Right", x: (w - thk), y: 0, z: 0,
            lx: thk, ly: [setback - toe_recess, thk].max, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          add_part_component(te, model,
            name: "Toe Rail - Back", x: thk, y: 0, z: 0,
            lx: (w - (2 * thk)), ly: thk, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          rail_start_x = setback
          rail_start_y = d - toe_recess
          rail_end_x = w - toe_recess
          rail_end_y = setback
          rail_len = Math.sqrt(((rail_end_x - rail_start_x) ** 2) + ((rail_end_y - rail_start_y) ** 2))
          rail = add_part_component(te, model,
            name: "Toe Rail - Diagonal Front", x: rail_start_x, y: rail_start_y, z: 0,
            lx: rail_len, ly: thk, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          rail.transform!(Geom::Transformation.rotation(
            Geom::Point3d.new(rail_start_x, rail_start_y, 0), Z_AXIS, -45.degrees))
        elsif type == "Pie-Cut Corner Base"
          notch = pie_cut_notch_size(w, d)
          return_x = w - notch
          return_y = d - notch
          add_part_component(te, model,
            name: "Toe End - Left", x: 0, y: 0, z: 0,
            lx: thk, ly: [return_y - toe_recess, thk].max, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          add_part_component(te, model,
            name: "Toe End - Right", x: (w - thk), y: 0, z: 0,
            lx: thk, ly: [return_y - toe_recess, thk].max, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          add_part_component(te, model,
            name: "Toe Rail - Back", x: thk, y: 0, z: 0,
            lx: (w - (2.0 * thk)), ly: thk, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          add_part_component(te, model,
            name: "Toe Rail - Inside Horizontal",
            x: return_x, y: (return_y - toe_recess), z: 0,
            lx: notch, ly: thk, lz: toe_height,
            tag: tag_toe, material: mat_toe)
          add_part_component(te, model,
            name: "Toe Rail - Inside Vertical",
            x: (return_x - toe_recess), y: return_y, z: 0,
            lx: thk, ly: notch, lz: toe_height,
            tag: tag_toe, material: mat_toe)
        else
          inst_toe_end_left = add_part_component(te, model,
            name: "Toe End - Left",
            x: 0, y: 0, z: 0.0,
            lx: thk, ly: platform_depth, lz: toe_height,
            tag: tag_toe, material: mat_toe
          )

          inst_toe_end_right = add_part_component(te, model,
            name: "Toe End - Right",
            x: (w - thk), y: 0, z: 0.0,
            lx: thk, ly: platform_depth, lz: toe_height,
            tag: tag_toe, material: mat_toe
          )

          inst_toe_rail_back = add_part_component(te, model,
            name: "Toe Rail - Back",
            x: thk, y: 0, z: 0.0,
            lx: (w - (2.0 * thk)), ly: thk, lz: toe_height,
            tag: tag_toe, material: mat_toe
          )

          inst_toe_rail_front = add_part_component(te, model,
            name: "Toe Rail - Front",
            x: thk, y: (platform_depth - thk), z: 0.0,
            lx: (w - (2.0 * thk)), ly: thk, lz: toe_height,
            tag: tag_toe, material: mat_toe
          )
        end
        # Apply OpenCutList metadata to every toe component actually created by
        # the selected geometry branch. Corner branches do not use the standard
        # inst_toe_rail_front local variable.
        te.grep(Sketchup::ComponentInstance).each do |toe_part|
          toe_part.set_attribute('skservices_panel', 'panel_sku', TOE_KICK_SKU)
          toe_part.set_attribute('skservices_panel', 'thickness_in', 0.75)
          toe_part.set_attribute('skservices_panel', 'core', 'PLY')
          toe_part.set_attribute('skservices_panel', 'finish_front', 'UNFIN')
          toe_part.set_attribute('skservices_panel', 'finish_back', 'UNFIN')
        end


          # Crossmembers (rungs): run front-to-back, spaced across width <= 16" OC
  max_oc = 16.0
  clear_depth = platform_depth - (2.0 * thk) # between back/front rails
  clear_width = w - (2.0 * thk)             # between toe ends
  if clear_depth > thk && clear_width > max_oc && !corner_base_type
    # Determine number of bays so that spacing does not exceed max_oc.
    bays = (clear_width / max_oc).ceil
    bays = 1 if bays < 1
    rung_count = [bays - 1, 0].max

    1.upto(rung_count) do |i|
      t = i.to_f / bays.to_f
      x_center = thk + (clear_width * t)
      x = x_center - (thk / 2.0)
      inst_toe_cross = add_part_component(te, model,
        name: "Toe Crossmember #{i}",
        x: x, y: thk, z: 0.0,
        lx: thk, ly: clear_depth, lz: toe_height,
        tag: tag_toe, material: mat_toe
      )
      inst_toe_cross.set_attribute('skservices_panel', 'panel_sku', TOE_KICK_SKU)
      inst_toe_cross.set_attribute('skservices_panel', 'thickness_in', 0.75)
      inst_toe_cross.set_attribute('skservices_panel', 'core', 'PLY')
      inst_toe_cross.set_attribute('skservices_panel', 'finish_front', 'UNFIN')
      inst_toe_cross.set_attribute('skservices_panel', 'finish_back', 'UNFIN')
    end
  end
end

# ----------------------------
# Carcass assembly group
      # ----------------------------
      carcass = root.entities.add_group
      carcass.name = "Carcass"
      carcass.layer = tag_carcass
      ce = carcass.entities
      inner_w = spec.inner_w
      top_z   = spec.top_z

      # ----------------------------
      # ADA Sink construction:
      # - Open knee space (no bottom panel)
      # - Raised upper side panels + front legs
      # - Back: none by default
      # - Apron: 3" tall sloped or recessed; bottom >= 27" AFF
      # - Clear width: 30" min is user's responsibility; we do not auto-force width.
      # - Knee depth: 17–25"
      # ----------------------------
      if is_ada_sink
        # Model 10580 ADA Wall Sink Cabinet: open top, bottom, back, and interior.
        # The wall-mount and front rails span between full-height side panels.
        panel_reveal = in_to_length(params[:reveal_edge_in] || 0.0625)
        panel_width = inner_w - panel_reveal
        panel_height = finished_top_h - front_rail_h - (2.0 * panel_reveal)
        raise ArgumentError, "Access panel dimensions are invalid" if panel_width <= thk || panel_height <= thk

        add_part_component(ce, model,
          name: "Left Side",
          x: 0, y: 0, z: 0,
          lx: thk, ly: d, lz: finished_top_h,
          tag: tag_carcass, material: mat_parts,
          edge_band: [:yp], edge_material: mat_edge
        )
        add_part_component(ce, model,
          name: "Right Side",
          x: (w - thk), y: 0, z: 0,
          lx: thk, ly: d, lz: finished_top_h,
          tag: tag_carcass, material: mat_parts,
          edge_band: [:yp], edge_material: mat_edge
        )
        add_part_component(ce, model,
          name: "Front Rail",
          x: thk, y: (d - thk), z: (finished_top_h - front_rail_h),
          lx: inner_w, ly: thk, lz: front_rail_h,
          tag: tag_carcass, material: mat_parts,
          edge_band: [:yp, :zn], edge_material: mat_edge
        )
        add_part_component(ce, model,
          name: (params[:french_cleat] ? "Rear French Cleat" : "Rear Mount Rail"),
          x: thk, y: 0, z: (finished_top_h - mount_rail_h),
          lx: inner_w, ly: thk, lz: mount_rail_h,
          tag: tag_carcass, material: mat_parts,
          edge_band: [:yp], edge_material: mat_edge
        )

        if params[:second_mount_rail]
          add_part_component(ce, model,
            name: "Lower Rear Mount Rail",
            x: thk, y: 0, z: (finished_top_h * 0.45),
            lx: inner_w, ly: thk, lz: mount_rail_h,
            tag: tag_carcass, material: mat_parts,
            edge_band: [:yp], edge_material: mat_edge
          )
        end

        access = add_part_component(ce, model,
          name: "Removable Access Panel - #{access_panel_type}",
          x: (thk + panel_reveal / 2.0), y: d, z: panel_reveal,
          lx: panel_width, ly: door_thk, lz: panel_height,
          tag: tag_doors, material: mat_fronts,
          edge_band: [:xp, :xn, :zp, :zn], edge_material: mat_edge
        )
        access.set_attribute(CABINET_ATTR_DICT, "removable", true) if access.respond_to?(:set_attribute)
        access.set_attribute(CABINET_ATTR_DICT, "access_panel_type", access_panel_type) if access.respond_to?(:set_attribute)
        access.set_attribute(CABINET_ATTR_DICT, "grain_direction", "Vertical") if access.respond_to?(:set_attribute)

        hardware_group = root.entities.add_group
        hardware_group.name = "Hardware - #{access_panel_type}"
        hardware_group.layer = tag_hardware
        hardware_group.set_attribute(CABINET_ATTR_DICT, "fastener_type", (params[:fastener_type] || "Confirmat").to_s)
        hardware_group.set_attribute(CABINET_ATTR_DICT, "safety_tether", !!params[:safety_tether])

        root.set_attribute(CABINET_ATTR_DICT, "product_model", "10580")
        root.set_attribute(CABINET_ATTR_DICT, "construction", "Frameless Wall Mounted")
        root.set_attribute(CABINET_ATTR_DICT, "open_top", true)
        root.set_attribute(CABINET_ATTR_DICT, "open_bottom", true)
        root.set_attribute(CABINET_ATTR_DICT, "open_back", true)
      else
        # ----------------------------
        # Standard carcass construction
        # ----------------------------

        # Partitions are generated for standard (non-ADA) carcasses when either:
        # - the user explicitly requests partitions (partition_count > 0), or
        # - auto-partition triggers (e.g., Base cabinets >= 37" wide).
        # We compute this once and reuse it for splitting stretchers, back panels, and shelves.
        partition_active = (
          !is_ada_sink &&
          type != "Sink Base" &&
          ((show_doors && drawer_count == 0) || auto_partition || type == "Cubbies") &&
          (partition_count.to_i > 0 || auto_partition)
        )

        # Side panels
        # - Normal case: carcass sits on toe base (z = carcass_z0)
        # - Finished-end case (base-like types with toe): sides run to floor with an integral toe notch
        #
        # Diagonal corner: square wall footprint with the exposed corner cut at 45 degrees.
        if type == "Diagonal Corner Base"
          diagonal_setback = diagonal_corner_setback(w, d)
          add_part_component(ce, model,
            name: "Side - Left", x: 0, y: 0, z: carcass_z0,
            lx: thk, ly: d, lz: box_h,
            tag: tag_carcass, material: mat_parts,
            edge_band: eb_left, edge_material: mat_edge)
          add_part_component(ce, model,
            name: "Side - Right", x: (w - thk), y: 0, z: carcass_z0,
            lx: thk, ly: diagonal_setback, lz: box_h,
            tag: tag_carcass, material: mat_parts,
            edge_band: eb_right, edge_material: mat_edge)
        # Pie-cut corner: 36x36 footprint with a 12x12 inside-corner opening.
        elsif type == "Pie-Cut Corner Base"
          notch = pie_cut_notch_size(w, d)
          return_len = (d - notch)

          # Left side: full depth
          if use_toe && finish_left_end
            add_notched_side_component(ce, model,
              name: "Side - Left",
              x: 0, y: 0, z: 0.0,
              thk: thk, depth: d, box_h: box_h, toe_h: toe_height, toe_recess: toe_recess,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_left,
              edge_material: mat_edge
            )
          else
            add_part_component(ce, model,
              name: "Side - Left",
              x: 0, y: 0, z: carcass_z0,
              lx: thk, ly: d, lz: box_h,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_left,
              edge_material: mat_edge
            )
          end

          # Right side: shortened depth to the return (24")
          if use_toe && finish_right_end
            add_notched_side_component(ce, model,
              name: "Side - Right",
              x: (w - thk), y: 0, z: 0.0,
              thk: thk, depth: return_len, box_h: box_h, toe_h: toe_height, toe_recess: toe_recess,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_right,
              edge_material: mat_edge
            )
          else
            add_part_component(ce, model,
              name: "Side - Right",
              x: (w - thk), y: 0, z: carcass_z0,
              lx: thk, ly: return_len, lz: box_h,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_right,
              edge_material: mat_edge
            )
          end

          # The two inside edges are the cabinet opening. Do not close them with
          # fixed return panels; the perpendicular door leaves cover this opening.
        else
          if use_toe && finish_left_end
            add_notched_side_component(ce, model,
              name: "Side - Left",
              x: 0, y: 0, z: 0.0,
              thk: thk, depth: d, box_h: box_h, toe_h: toe_height, toe_recess: toe_recess,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_left,
              edge_material: mat_edge
            )
          else
            add_part_component(ce, model,
              name: "Side - Left",
              x: 0, y: 0, z: carcass_z0,
              lx: thk, ly: d, lz: box_h,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_left,
              edge_material: mat_edge
            )
          end

          if use_toe && finish_right_end
            add_notched_side_component(ce, model,
              name: "Side - Right",
              x: (w - thk), y: 0, z: 0.0,
              thk: thk, depth: d, box_h: box_h, toe_h: toe_height, toe_recess: toe_recess,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_right,
              edge_material: mat_edge
            )
          else
            add_part_component(ce, model,
              name: "Side - Right",
              x: (w - thk), y: 0, z: carcass_z0,
              lx: thk, ly: d, lz: box_h,
              tag: tag_carcass, material: mat_parts,
              edge_band: eb_right,
              edge_material: mat_edge
            )
          end
        end


        if type == "Diagonal Corner Base"
          setback = diagonal_corner_setback(w, d)
          add_polygon_part_component(ce, model,
            name: "Bottom - Diagonal Corner",
            points: [[0, 0], [inner_w, 0], [inner_w, setback], [setback, d], [0, d]],
            x: thk, y: 0, z: carcass_z0, lz: thk,
            tag: tag_carcass, material: mat_parts)
        elsif type == "Pie-Cut Corner Base"
          notch = pie_cut_notch_size(w, d)
          # L-shaped bottom: full interior rectangle minus a 9x9 notch at the front-right.
          # Piece 1: full width, reduced depth
          add_part_component(ce, model,
            name: "Bottom - Main",
            x: thk, y: 0, z: carcass_z0,
            lx: inner_w, ly: (d - notch), lz: thk,
            tag: tag_carcass, material: mat_parts,
            edge_band: [:yp],
            edge_material: mat_edge
          )
          # Piece 2: reduced width strip at the front
          add_part_component(ce, model,
            name: "Bottom - Wing",
            x: thk, y: (d - notch), z: carcass_z0,
            lx: (inner_w - notch), ly: notch, lz: thk,
            tag: tag_carcass, material: mat_parts,
            edge_band: [:yp],
            edge_material: mat_edge
          )
        else
          add_part_component(ce, model,
            name: "Bottom",
            x: thk, y: 0, z: carcass_z0,
            lx: inner_w, ly: d, lz: thk,
            tag: tag_carcass, material: mat_parts,
            edge_band: [:yp],
            edge_material: mat_edge
          )
        end

        if top_mode == "Stretchers"
          # If partitions are being generated, split stretchers so they do not intersect partitions.
          split_stretchers = partition_active

          if split_stretchers
            openings = partition_count.to_i + 1
            opening_w = (inner_w - (partition_count.to_i * thk)) / openings.to_f
            raise ArgumentError, "Partition count too large for width" if opening_w <= 1.0

            0.upto(openings - 1) do |i|
              seg_x  = thk + (i * (opening_w + thk))
              seg_lx = opening_w

              add_part_component(ce, model,
                name: "Stretcher - Back #{i + 1}",
                x: seg_x, y: 0, z: top_z,
                lx: seg_lx, ly: stretcher_width, lz: thk,
                tag: tag_carcass, material: mat_parts,
                edge_band: [:yp],
                edge_material: mat_edge
              )
              add_part_component(ce, model,
                name: "Stretcher - Front #{i + 1}",
                x: seg_x, y: (d - stretcher_width), z: top_z,
                lx: seg_lx, ly: stretcher_width, lz: thk,
                tag: tag_carcass, material: mat_parts,
                edge_band: [:yp],
                edge_material: mat_edge
              )
            end
          else
            add_part_component(ce, model,
              name: "Stretcher - Back",
              x: thk, y: 0, z: top_z,
              lx: inner_w, ly: stretcher_width, lz: thk,
              tag: tag_carcass, material: mat_parts,
              edge_band: [:yp],
              edge_material: mat_edge
            )
            add_part_component(ce, model,
              name: "Stretcher - Front",
              x: thk, y: (d - stretcher_width), z: top_z,
              lx: inner_w, ly: stretcher_width, lz: thk,
              tag: tag_carcass, material: mat_parts,
              edge_band: [:yp],
              edge_material: mat_edge
            )
          end
        else
          if type == "Diagonal Corner Base"
            setback = diagonal_corner_setback(w, d)
            add_polygon_part_component(ce, model,
              name: "Top - Diagonal Corner",
              points: [[0, 0], [inner_w, 0], [inner_w, setback], [setback, d], [0, d]],
              x: thk, y: 0, z: top_z, lz: thk,
              tag: tag_carcass, material: mat_parts)
          elsif type == "Pie-Cut Corner Base"
            notch = pie_cut_notch_size(w, d)
            # L-shaped top: full interior rectangle minus a 9x9 notch at the front-right.
            add_part_component(ce, model,
              name: "Top - Main",
              x: thk, y: 0, z: top_z,
              lx: inner_w, ly: (d - notch), lz: thk,
              tag: tag_carcass, material: mat_parts
            )
            add_part_component(ce, model,
              name: "Top - Wing",
              x: thk, y: (d - notch), z: top_z,
              lx: (inner_w - notch), ly: notch, lz: thk,
              tag: tag_carcass, material: mat_parts
            )
          else
            add_part_component(ce, model,
              name: "Top",
              x: thk, y: 0, z: top_z,
              lx: inner_w, ly: d, lz: thk,
              tag: tag_carcass, material: mat_parts
            )
          end
        end


        # Optional back stretcher (used with 1/4" back construction mode)
        if back_mode == "Back Stretcher + 1/4 Back"
          add_part_component(ce, model,
            name: "Back Stretcher",
            x: thk, y: 0, z: top_z,
            lx: inner_w, ly: stretcher_width, lz: thk,
            tag: tag_carcass, material: mat_parts
          )
        end

        back_panel_h = box_h
        back_panel_h = box_h - thk if top_mode == "Stretchers" || back_mode == "Back Stretcher + 1/4 Back"
        back_panel_h = [back_panel_h, thk].max

        if back_thk.to_f > 0.0
          back_grp = ce.add_group
          back_grp.name = "Back"
          back_grp.layer = tag_back

          if partition_active
            openings = partition_count.to_i + 1
            opening_w = (inner_w - (partition_count.to_i * thk)) / openings.to_f
            raise ArgumentError, "Partition count too large for width" if opening_w <= 1.0

            0.upto(openings - 1) do |i|
              seg_x  = thk + (i * (opening_w + thk))
              seg_lx = opening_w

              add_part_component(back_grp.entities, model,
                name: "Back Panel #{i + 1}",
                x: seg_x, y: 0, z: carcass_z0,
                lx: seg_lx, ly: back_thk, lz: back_panel_h,
                tag: tag_back, material: mat_parts
              )
            end
          else
            add_part_component(back_grp.entities, model,
              name: "Back Panel",
              x: thk, y: 0, z: carcass_z0,
              lx: inner_w, ly: back_thk, lz: back_panel_h,
              tag: tag_back, material: mat_parts
            )
          end
        end

      end

      # ----------------------------
      # Partitions
      # ----------------------------
      # Standard rule: partitions are primarily a "doors-only" feature (no drawers), and can also be forced
      # on by the auto-partition rule for wide cabinets.
      #
      # Cubbies are a special case: they are open cabinets and the internal grid is entirely defined by
      # partitions + shelves, so partitions are allowed at any width.
      if partition_count > 0 && !is_ada_sink && type != "Sink Base" && ((show_doors && drawer_count == 0) || auto_partition || type == "Cubbies")
        max_parts = 6
        partition_count = [partition_count, max_parts].min

        openings = partition_count + 1
        opening_w = (inner_w - (partition_count * thk)) / openings.to_f
        raise ArgumentError, "Partition count too large for width" if opening_w <= 1.0

        1.upto(partition_count) do |i|
          x = thk + (opening_w * i) + (thk * (i - 1))
          # Partitions should NOT pass through the bottom panel.
          # Start above the bottom panel thickness and reduce height accordingly.
          part_z = carcass_z0 + thk

          # Cubbies: partitions should stop at the underside of the full top (not pass through it),
          # and they should extend through the back panel.
          if type == "Cubbies"
            part_y  = 0.0
            part_ly = d
            part_lz = (top_z - part_z) # underside of top panel
          else
            part_y  = 0.0
            part_ly = d
            part_lz = box_h - thk
          end
          part_lz = [part_lz, thk].max

          add_part_component(ce, model,
            name: "Partition #{i}",
            x: x, y: part_y, z: part_z,
            lx: thk, ly: part_ly, lz: part_lz,
            tag: tag_carcass, material: mat_parts,
            edge_band: [:yp],
            edge_material: mat_edge
          )
        end
      end

      # ----------------------------
      # Shelves (standard only)
      # ----------------------------
      if shelves > 0 && !is_ada_sink
        shelves_grp = ce.add_group
        shelves_grp.name = "Shelves"
        shelves_grp.layer = tag_shelves
        se = shelves_grp.entities

        top_limit_z = top_z
        bottom_limit_z = carcass_z0 + thk
        clear_h = top_limit_z - bottom_limit_z
        spacing = clear_h / (shelves + 1)

        shelf_ly = (type == "Cubbies") ? (d - back_thk) : (d - back_thk - 0.5)  # cubbies are open; others shorten 1/2" away from doors
        shelf_ly = [shelf_ly, 0.25].max
        shelf_thk = thk

        # If partitions are active, split each shelf into segments per opening.
        if partition_active
          openings = partition_count.to_i + 1
          opening_w = (inner_w - (partition_count.to_i * thk)) / openings.to_f
          raise ArgumentError, "Partition count too large for width" if opening_w <= 1.0

          1.upto(shelves) do |shelf_idx|
            z = bottom_limit_z + spacing * shelf_idx - (shelf_thk / 2.0)
            z = [z, bottom_limit_z].max
            z = [z, (top_limit_z - shelf_thk)].min

            0.upto(openings - 1) do |bay_idx|
              seg_x  = thk + (bay_idx * (opening_w + thk))
              seg_lx = opening_w

              add_part_component(se, model,
                name: "Shelf #{shelf_idx} - Bay #{bay_idx + 1}",
                x: seg_x, y: back_thk, z: z,
                lx: seg_lx, ly: shelf_ly, lz: shelf_thk,
                tag: tag_shelves, material: mat_parts,
                edge_band: [:yp],
                edge_material: mat_edge
              )
              shelf_specs << { x: seg_x, y: back_thk, z: z, lx: seg_lx, ly: shelf_ly, lz: shelf_thk }
            end
          end
        else
          1.upto(shelves) do |i|
            z = bottom_limit_z + spacing * i - (shelf_thk / 2.0)
            z = [z, bottom_limit_z].max
            z = [z, (top_limit_z - shelf_thk)].min

	            if type == "Diagonal Corner Base"
	              setback = diagonal_corner_setback(w, d)
	              add_polygon_part_component(se, model,
	                name: "Shelf #{i} - Diagonal Corner",
	                points: [[0, 0], [inner_w, 0], [inner_w, setback], [setback, shelf_ly], [0, shelf_ly]],
	                x: thk, y: back_thk, z: z, lz: shelf_thk,
	                tag: tag_shelves, material: mat_parts)
	              shelf_specs << { x: thk, y: back_thk, z: z, lx: inner_w, ly: shelf_ly, lz: shelf_thk }
	            elsif type == "Pie-Cut Corner Base"
	              notch = pie_cut_notch_size(w, d)
	              # L-shaped shelf: full interior rectangle minus a 9x9 notch at the front-right.
	              add_part_component(se, model,
	                name: "Shelf #{i} - Main",
	                x: thk, y: back_thk, z: z,
	                lx: inner_w, ly: (shelf_ly - notch), lz: shelf_thk,
	                tag: tag_shelves, material: mat_parts,
	                edge_band: [:yp],
	                edge_material: mat_edge
	              )
	              add_part_component(se, model,
	                name: "Shelf #{i} - Wing",
	                x: thk, y: (back_thk + shelf_ly - notch), z: z,
	                lx: (inner_w - notch), ly: notch, lz: shelf_thk,
	                tag: tag_shelves, material: mat_parts,
	                edge_band: [:yp],
	                edge_material: mat_edge
	              )
	              shelf_specs << { x: thk, y: back_thk, z: z, lx: inner_w, ly: (shelf_ly - notch), lz: shelf_thk }
	              shelf_specs << { x: thk, y: (back_thk + shelf_ly - notch), z: z, lx: (inner_w - notch), ly: notch, lz: shelf_thk }
	            else
	              add_part_component(se, model,
	                name: "Shelf #{i}",
	                x: thk, y: back_thk, z: z,
	                lx: inner_w, ly: shelf_ly, lz: shelf_thk,
	                tag: tag_shelves, material: mat_parts,
	                edge_band: [:yp],
	                edge_material: mat_edge
	              )
	              shelf_specs << { x: thk, y: back_thk, z: z, lx: inner_w, ly: shelf_ly, lz: shelf_thk }
	            end
          end
        end
      end

      # ----------------------------
      # Drawers (Base only)
      # ----------------------------
      drawer_rows = []
      if type == "Base" && drawer_count > 0
        drawers_root = root.entities.add_group
        drawers_root.name = "Drawers"
        drawers_root.layer = tag_drawers

        front_y = d
        split_count = drawer_split_count_for_width(width_in, params[:automatic_drawer_bank_split_threshold_in] || 37.0)

        make_front_assemblies = lambda do |label, z, h_front|
          row_grp = drawers_root.entities.add_group
          row_grp.name = "Drawer Row #{label}"
          row_grp.layer = tag_drawers

          if split_count == 2
            total_available = w - (2.0 * reveal_edge) - reveal_center
            each_w = total_available / 2.0
            raise ArgumentError, "Reveals/center gap too large for drawer width" if each_w <= 0

            left_x  = reveal_edge
            right_x = reveal_edge + each_w + reveal_center

            left_asm = row_grp.entities.add_group
            left_drawer = left_asm.entities.add_group
            left_drawer.name = "Drawer Assembly - Left"
            left_asm.name = "Drawer Assembly - Left"
            left_asm.layer = tag_drawers

            right_asm = row_grp.entities.add_group
            right_drawer = right_asm.entities.add_group
            right_drawer.name = "Drawer Assembly - Right"
            right_asm.name = "Drawer Assembly - Right"
            right_asm.layer = tag_drawers

            add_part_component(left_drawer.entities, model,
              name: "Drawer Front - #{label} - Left",
              x: left_x, y: front_y, z: z,
              lx: each_w, ly: door_thk, lz: h_front,
              tag: tag_drawers, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
            )
            add_part_component(right_drawer.entities, model,
              name: "Drawer Front - #{label} - Right",
              x: right_x, y: front_y, z: z,
              lx: each_w, ly: door_thk, lz: h_front,
              tag: tag_drawers, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
            )

            drawer_front_specs << { side: :left,  x: left_x,  y: front_y, z: z, w: each_w, h: h_front }
            drawer_front_specs << { side: :right, x: right_x, y: front_y, z: z, w: each_w, h: h_front }

            drawer_rows << { label: label, z: z, h: h_front, split_count: 2, each_w: each_w, left_asm: left_asm, right_asm: right_asm }
          else
            drawer_x = reveal_edge
            drawer_w = w - (2.0 * reveal_edge)
            raise ArgumentError, "Reveal edge too large for drawer width" if drawer_w <= 0

            asm = row_grp.entities.add_group
            drawer = asm.entities.add_group
            drawer.name = "Drawer Assembly"
            asm.name = "Drawer Assembly"
            asm.layer = tag_drawers

            add_part_component(drawer.entities, model,
              name: "Drawer Front - #{label}",
              x: drawer_x, y: front_y, z: z,
              lx: drawer_w, ly: door_thk, lz: h_front,
              tag: tag_drawers, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
            )

            drawer_front_specs << { side: :full, x: drawer_x, y: front_y, z: z, w: drawer_w, h: h_front }

            drawer_rows << { label: label, z: z, h: h_front, split_count: 1, asm: asm }
          end
        end

        if drawer_count == 1
	          # Trash Can uses a single full-height pull-out front.
	          if type == "Trash Can"
	            drawer_front_h_single = box_h - (2.0 * reveal_edge)
	          end
          safe_positive!(drawer_front_h_single, "Top drawer front height")

          drawer_h = drawer_front_h_single
          drawer_z = cabinet_top_z - reveal_edge - drawer_h
          make_front_assemblies.call("Top", drawer_z, drawer_h)
        else
          heights = compute_drawer_front_heights(drawer_count, box_h, reveal_edge, drawer_gap, drawer_front_heights_raw)

          top_inside_z = cabinet_top_z - reveal_edge
          z_top = top_inside_z

          heights.each_with_index do |h_front, idx|
            z = z_top - h_front
            make_front_assemblies.call((idx + 1).to_s, z, h_front)
            z_top = z - drawer_gap
          end
        end

        # Drawer boxes + slides
        y0 = back_thk + 1.75  # moved 1" closer to drawer front
        max_depth = (d - back_thk) - 1.75
        box_depth = [max_depth, 10.0].max

        slide_len = box_depth
        # Keep slides aligned to the drawer box so they do not project past the front of
        # the drawer box (and into/through the drawer front geometry).
        slide_y0 = y0

        add_box_and_slides = lambda do |asm_grp, opening_x, opening_w, z0, boxh, label|
          box_asm = asm_grp.entities.add_group
          box_asm.name = "Drawer Box Assembly"
          box_asm.layer = tag_drawerboxes

          add_drawer_box_assembly(box_asm.entities, model,
            name_prefix: "Drawer Box",
            opening_x: opening_x, opening_w: opening_w,
            y0: y0, depth: box_depth,
            z0: z0, box_h: boxh,
            tag_parts: tag_drawerboxes, mat_parts: mat_parts,
            mat_edge: mat_edge
          )

          if use_slides
            slides_asm = asm_grp.entities.add_group
            slides_asm.name = "Slides"
            slides_asm.layer = tag_hardware

            add_simple_side_mount_slides_assembly(slides_asm.entities, model,
              name_prefix: "Slides - #{label}",
              x0: opening_x, opening_w: opening_w,
              y0: slide_y0, slide_len: slide_len,
              z: (z0 + (boxh * 0.35)),
              tag_parts: tag_hardware, mat_parts: mat_hardware
            )
          end
        end

	        drawer_rows.each do |row|
	          if type == "Trash Can"
	            # Drawer box is mounted 1/2" up from the cabinet bottom.
	            bottom_offset = in_to_length(params[:trash_drawer_box_bottom_offset_in] || 0.5)
	            z0 = carcass_z0 + thk + bottom_offset
	            boxh = [box_h - (thk + in_to_length(1.5)), 6.0].max
	          else
	            boxh = [row[:h] - 1.0, 3.0].max
	            z0 = row[:z] + 0.25
	          end

          if row[:split_count] == 2
            part_thk = (partition_count > 0) ? thk : 0.0
            opening_each = (inner_w - part_thk) / 2.0
            x_left  = thk
	            x_right = thk + opening_each + part_thk
	            add_box_and_slides.call(row[:left_drawer] || row[:left_asm],  x_left,  opening_each, z0, boxh, "Left")
            add_box_and_slides.call(row[:right_drawer] || row[:right_asm], x_right, opening_each, z0, boxh, "Right")
          else
            add_box_and_slides.call(row[:drawer] || row[:asm], thk, inner_w, z0, boxh, "Full")
          end
        end
      end

      # ----------------------------
      # Sink Base + ADA Sink fronts:
      # - false drawer front 6"
      # - doors below for Sink Base
      # - ADA: sloped apron + optional access doors (kept, but many ADA designs omit doors)
      # ----------------------------
      if type == "Sink Base" 
        fronts_grp = root.entities.add_group
        fronts_grp.name = "Sink Fronts"
        fronts_grp.layer = tag_doors
        fe = fronts_grp.entities

        front_y = d

        # False front sits below cabinet top
        ff_top_z = cabinet_top_z - reveal_edge
        ff_z = ff_top_z - false_front_h
        raise ArgumentError, "False front height too large for cabinet" if false_front_h >= box_h

        ff_x = reveal_edge
        ff_w = w - (2.0 * reveal_edge)
        raise ArgumentError, "Reveal edge too large for false front width" if ff_w <= 0

        add_part_component(fe, model,
          name: "False Drawer Front (Sink)",
          x: ff_x, y: front_y, z: ff_z,
          lx: ff_w, ly: door_thk, lz: false_front_h,
          tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
        )
        if type == "ADA Sink"
          # ADA apron: 3" tall, sloped/recessed; bottom >= 27" AFF
          apron_h = ada_apron_h
          apron_bottom_min = ada_knee_clear_h
          apron_bottom_z = [ff_z - 0.125 - apron_h, apron_bottom_min].max
          apron_z = apron_bottom_z

          apron_depth = clamp(ada_knee_depth, 17.0, 25.0)
          apron_depth = [apron_depth, d].min

          add_wedge_component(fe, model,
            name: "ADA Apron (Sloped)",
            x: reveal_edge,
            y: (d - apron_depth),
            z: apron_z,
            lx: (w - 2.0 * reveal_edge),
            ly: apron_depth,
            lz: apron_h,
            slope_depth: [3.0, apron_depth].min,
            tag: tag_doors,
            material: mat_parts
          )
        end

        # Doors below false front:
        # - Sink Base: standard doors
        # - ADA: optional; we still generate if enabled, but auto-skip if it conflicts with knee space/apron.
        if show_doors
          doors_grp = root.entities.add_group
          doors_grp.name = "Doors"
          doors_grp.layer = tag_doors
          de = doors_grp.entities

          door_span_bottom_z =
            if type == "ADA Sink"
              # Keep knee space open: start doors above knee clearance and above apron if present
              [ada_knee_clear_h, 0.0].max
            else
              carcass_z0
            end

          door_span_top_z = ff_z
          door_h = (door_span_top_z - door_span_bottom_z) - (2.0 * reveal_edge)
          door_z = door_span_bottom_z + reveal_edge


          # Door height segmentation (matches other base cabinet logic)
          # If door leaf is taller than 48", split into stacked segments with a reveal gap.
          max_door_leaf_h = 48.0
          stack_gap = reveal_center.to_f
          door_segments = []
          if door_h.to_f > 0.0
            dh = door_h.to_f
            if dh <= max_door_leaf_h
              door_segments << { h: dh, z: door_z, stack: :lower }
            else
              z_off = 0.0
              remaining = dh
              seg_idx = 0
              while remaining > 0.0
                seg_h = [remaining, max_door_leaf_h].min
                seg_z = door_z + z_off
                seg_tag = (seg_idx == 0) ? :lower : :upper
                door_segments << { h: seg_h, z: seg_z, stack: seg_tag }
                remaining -= (seg_h + stack_gap)
                z_off += (seg_h + stack_gap)
                seg_idx += 1
              end
            end
          end

          if door_h > 0.0
            door_count = door_count_for_width(width_in, params[:automatic_double_door_threshold_in] || 24.0)

            if door_count == 2
              total_available = w - (2.0 * reveal_edge) - reveal_center
              each_w = total_available / 2.0
              if each_w > 0
                left_x  = reveal_edge
                right_x = reveal_edge + each_w + reveal_center

                door_segments.each do |seg|


                  seg_h = seg[:h]


                  seg_z = seg[:z]


                  seg_tag = seg[:stack]


                


                  left_door = add_part_component(de, model,


                    name: "Door - Left - #{seg_tag.to_s.capitalize}",


                    x: left_x, y: front_y, z: seg_z,


                    lx: each_w, ly: door_thk, lz: seg_h,
tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
                


                  )


                  right_door = add_part_component(de, model,


                    name: "Door - Right - #{seg_tag.to_s.capitalize}",


                    x: right_x, y: front_y, z: seg_z,


                    lx: each_w, ly: door_thk, lz: seg_h,
tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
                


                  )


                


                  door_specs << { side: :left,  x: left_x,  y: front_y, z: seg_z, w: each_w, h: seg_h, stack: seg_tag }


                  door_specs << { side: :right, x: right_x, y: front_y, z: seg_z, w: each_w, h: seg_h, stack: seg_tag }

                  if door_swing == "Open"
                    hinge_axis = Geom::Vector3d.new(0, 0, 1)
                    left_pivot = Geom::Point3d.new(left_x, front_y, seg_z)
                    right_pivot = Geom::Point3d.new(right_x + each_w, front_y, seg_z)
                    left_door.transform!(Geom::Transformation.rotation(left_pivot, hinge_axis, open_angle.degrees))
                    right_door.transform!(Geom::Transformation.rotation(right_pivot, hinge_axis, -open_angle.degrees))
                  end
                end
              end
            else
              door_w = w - (2.0 * reveal_edge)
              if door_w > 0
                door_x = reveal_edge
                door_segments.each do |seg|

                  seg_h = seg[:h]

                  seg_z = seg[:z]

                  seg_tag = seg[:stack]

                

                  door = add_part_component(de, model,

                    name: "Door - Full - #{seg_tag.to_s.capitalize}",

                    x: door_x, y: front_y, z: seg_z,

                    lx: door_w, ly: door_thk, lz: seg_h,
tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
                

                  )

                

                  door_specs << { side: :full, x: door_x, y: front_y, z: seg_z, w: door_w, h: seg_h, stack: seg_tag }

                  if door_swing == "Open"
                    hinge_axis = Geom::Vector3d.new(0, 0, 1)
                    hs = hinge_side
                    hs = "Left" if hs == "Auto"
                    pivot_x = (hs == "Left") ? door_x : door_x + door_w
                    pivot = Geom::Point3d.new(pivot_x, front_y, seg_z)
                    ang = (hs == "Left") ? open_angle : -open_angle
                    door.transform!(Geom::Transformation.rotation(pivot, hinge_axis, ang.degrees))
                  end
                end
              end
            end
          end
        end
      else
        # ----------------------------
        # Standard Doors (Base/Wall/Tall)
        # Auto-fit philosophy: if doors can't fit, skip without error.
        # ----------------------------
        if show_doors
          doors_grp = root.entities.add_group
          doors_grp.name = "Doors"
          doors_grp.layer = tag_doors
          de = doors_grp.entities

	          skip_standard_doors = false
	          # Pie-cut corner uses two perpendicular 12" bi-fold door leaves.
	          if type == "Pie-Cut Corner Base"
	            notch = pie_cut_notch_size(w, d)
		            max_leaf_w = notch
		            return_x = w - notch
		            return_y = d - notch
	            # Door vertical span matches a standard base door span (no drawers)
	            door_z = carcass_z0 + reveal_edge
	            door_h = box_h - (2.0 * reveal_edge)
	            return root if door_h.to_f <= 0.0

		            # Horizontal leaf closes the Y-facing inside edge of the cutout.
		            leaf1_w = max_leaf_w - (2.0 * reveal_edge)
		            if leaf1_w.to_f > 0.0
		              leaf1_x = return_x + reveal_edge
		              add_part_component(de, model,
		                name: "Door - Front",
		                x: leaf1_x, y: return_y, z: door_z,
	                lx: leaf1_w, ly: door_thk, lz: door_h,
	                tag: tag_doors, material: mat_fronts,
	                edge_band: [:xp, :xn, :zp, :zn],
	                edge_material: mat_edge
	              )
		              door_specs << { side: :front, x: leaf1_x, y: return_y, z: door_z, w: leaf1_w, h: door_h }
		            end

		            # Vertical leaf closes the X-facing inside edge and meets leaf 1 at 90 degrees.
		            leaf2_w = max_leaf_w - (2.0 * reveal_edge)
		            if leaf2_w.to_f > 0.0
		              leaf2_y = return_y + reveal_edge
		              door2_x = return_x
	              door2 = add_part_component(de, model,
	                name: "Door - Right",
	                x: door2_x, y: leaf2_y, z: door_z,
	                lx: door_thk, ly: leaf2_w, lz: door_h,
	                tag: tag_doors, material: mat_fronts,
	                edge_band: [:yp, :yn, :zp, :zn],
	                edge_material: mat_edge
	              )
		              door_specs << { side: :right, x: door2_x, y: leaf2_y, z: door_z, w: leaf2_w, h: door_h }
	            end
		            # Skip standard door generation for the pie-cut corner.
		            skip_standard_doors = true
		          elsif type == "Diagonal Corner Base"
	            setback = diagonal_corner_setback(w, d)
		            door_z = carcass_z0 + reveal_edge
		            door_h = box_h - (2.0 * reveal_edge)
		            start_x = setback + reveal_edge
		            start_y = d - reveal_edge
		            end_x = w - reveal_edge
		            end_y = setback + reveal_edge
		            diagonal_w = Math.sqrt(((end_x - start_x) ** 2) + ((end_y - start_y) ** 2))
		            diagonal_door = add_part_component(de, model,
		              name: "Door - Diagonal Corner",
		              x: start_x, y: start_y, z: door_z,
		              lx: diagonal_w, ly: door_thk, lz: door_h,
		              tag: tag_doors, material: mat_fronts,
		              edge_band: [:xp, :xn, :zp, :zn], edge_material: mat_edge)
		            diagonal_door.transform!(Geom::Transformation.rotation(
		              Geom::Point3d.new(start_x, start_y, door_z), Z_AXIS, -45.degrees))
		            skip_standard_doors = true
		          elsif type == "Blind Corner Base"
		            opening_w = [in_to_length(18.0), w - (2.0 * reveal_edge)].min
		            door_z = carcass_z0 + reveal_edge
		            door_h = box_h - (2.0 * reveal_edge)
		            door_x = reveal_edge
		            blind_door = add_part_component(de, model,
		              name: "Door - Blind Corner Access",
		              x: door_x, y: d, z: door_z,
		              lx: opening_w, ly: door_thk, lz: door_h,
		              tag: tag_doors, material: mat_fronts,
		              edge_band: [:xp, :xn, :zp, :zn], edge_material: mat_edge)
		            door_specs << { side: :left, x: door_x, y: d, z: door_z, w: opening_w, h: door_h }
		            filler_x = door_x + opening_w + reveal_center
		            filler_w = w - filler_x - reveal_edge
		            if filler_w > 0
		              add_part_component(de, model,
		                name: "Blind Corner Fixed Front",
		                x: filler_x, y: d, z: door_z,
		                lx: filler_w, ly: door_thk, lz: door_h,
		                tag: tag_doors, material: mat_fronts,
		                edge_band: [:xp, :xn, :zp, :zn], edge_material: mat_edge)
		            end
		            skip_standard_doors = true
		          end

	          # Standard door generation (all other types)
	          if !skip_standard_doors
	            front_y = d

          door_span_h =
            if type == "Base" && drawer_count == 1
              # doors below top drawer (below cabinet_top_z)
              (box_h - drawer_front_h_single - drawer_gap)
            else
              box_h
            end

          door_z = carcass_z0 + reveal_edge
          door_h = door_span_h - (2.0 * reveal_edge)

          # Door height rule: do not allow any single door leaf to exceed 48".
          # If taller, split into stacked doors with a reveal gap between segments.
          max_door_leaf_h = 48.0
          stack_gap = reveal_center.to_f
          door_segments = []
          if door_h.to_f > 0.0
            dh = door_h.to_f
            if dh <= max_door_leaf_h
              door_segments << { h: dh, z: door_z, stack: :lower }
            else
              z_off = 0.0
              remaining = dh
              seg_idx = 0
              while remaining > 0.0
                seg_h = [remaining, max_door_leaf_h].min
                seg_z = door_z + z_off
                seg_tag = (seg_idx == 0) ? :lower : :upper
                door_segments << { h: seg_h, z: seg_z, stack: seg_tag }
                remaining -= (seg_h + stack_gap)
                z_off += (seg_h + stack_gap)
                seg_idx += 1
              end
            end
          end

          if door_h > 0.0
            door_count = door_count_for_width(width_in, params[:automatic_double_door_threshold_in] || 24.0)

            if door_count == 2
              total_available = w - (2.0 * reveal_edge) - reveal_center
              each_w = total_available / 2.0
              if each_w > 0
                left_x  = reveal_edge
                right_x = reveal_edge + each_w + reveal_center

                door_segments.each do |seg|


                  seg_h = seg[:h]


                  seg_z = seg[:z]


                  seg_tag = seg[:stack]


                


                  left_door = add_part_component(de, model,


                    name: "Door - Left - #{seg_tag.to_s.capitalize}",


                    x: left_x, y: front_y, z: seg_z,


                    lx: each_w, ly: door_thk, lz: seg_h,
tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
                


                  )


                  right_door = add_part_component(de, model,


                    name: "Door - Right - #{seg_tag.to_s.capitalize}",


                    x: right_x, y: front_y, z: seg_z,


                    lx: each_w, ly: door_thk, lz: seg_h,
tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
                


                  )


                


                  door_specs << { side: :left,  x: left_x,  y: front_y, z: seg_z, w: each_w, h: seg_h, stack: seg_tag }


                  door_specs << { side: :right, x: right_x, y: front_y, z: seg_z, w: each_w, h: seg_h, stack: seg_tag }

                  if door_swing == "Open"
                    hinge_axis = Geom::Vector3d.new(0, 0, 1)
                    left_pivot = Geom::Point3d.new(left_x, front_y, seg_z)
                    right_pivot = Geom::Point3d.new(right_x + each_w, front_y, seg_z)
                    left_door.transform!(Geom::Transformation.rotation(left_pivot, hinge_axis, open_angle.degrees))
                    right_door.transform!(Geom::Transformation.rotation(right_pivot, hinge_axis, -open_angle.degrees))
                  end
                end
              end
            else
              door_w = w - (2.0 * reveal_edge)
              if door_w > 0
                door_x = reveal_edge
                door_segments.each do |seg|

                  seg_h = seg[:h]

                  seg_z = seg[:z]

                  seg_tag = seg[:stack]

                

                  door = add_part_component(de, model,

                    name: "Door - Full - #{seg_tag.to_s.capitalize}",

                    x: door_x, y: front_y, z: seg_z,

                    lx: door_w, ly: door_thk, lz: seg_h,
tag: tag_doors, material: mat_fronts,
            edge_band: [:xp, :xn, :zp, :zn],
            edge_material: mat_edge
                

                  )

                

                  door_specs << { side: :full, x: door_x, y: front_y, z: seg_z, w: door_w, h: seg_h, stack: seg_tag }

                  if door_swing == "Open"
                    hinge_axis = Geom::Vector3d.new(0, 0, 1)
                    hs = hinge_side
                    hs = "Left" if hs == "Auto"
                    pivot_x = (hs == "Left") ? door_x : door_x + door_w
                    pivot = Geom::Point3d.new(pivot_x, front_y, seg_z)
                    ang = (hs == "Left") ? open_angle : -open_angle
                    door.transform!(Geom::Transformation.rotation(pivot, hinge_axis, ang.degrees))
                  end
                end
              end
            end
          end
        end
          end # !skip_standard_doors
      end

      # ----------------------------
      # Hardware (lightweight, coordination-focused)
      # ----------------------------
      if add_wire_pulls || add_hinges || add_door_bumpers || add_shelf_supports || add_cam_lock || add_countertop_brackets || add_file_drawer_hw
        hw = root.entities.add_group
        hw.name = "Hardware"
        hw.layer = tag_hardware
        he = hw.entities

        # Pulls (Hafele #116.07.227 4" CTC wire pull)
        if add_wire_pulls
          # Coordinate system (door/drawer front local):
          # origin at top-left, X right, Y down.
          # Model space: X right, Z up. So z_world = z_bottom + (H - y_on_face).
          ctc = 4.0

          # Tunable placement parameters (shop defaults)
          bar_dia = 0.25

          # Door pulls:
          #   - Latch-side inset is measured to the pull centerline.
          #   - Vertical location is referenced to the END of the pull:
          #       * base/tall (and lower stacked leaves): TOP of pull is 2" down from top.
          #       * wall (and upper stacked leaves): BOTTOM of pull is 2" up from bottom.
          # Updated requirement: the pull's outside edge is 1.5" from the door edge.
          # Convert to centerline inset by adding the pull radius.
          edge_inset = 1.50 + (bar_dia / 2.0)  # latch-side edge to pull centerline (X)
          door_end_offset = 2.00         # from top (base/tall) or from bottom (wall/upper) (in)

          # Drawer pulls: keep existing shop standard (centered, fixed down from top).
          drawer_top_offset = 1.25       # drawers: down from top (Y)

          # Distance the pull projects out from the mounting surface.
          # Because the pull definition is built with its mounting plane at Y=0,
          # this value controls the "standoff" so the pull is visibly on the front face.
          stand_off = 1.0

          # Thicknesses (used for limiting leg penetration so hardware never breaks through).
          door_thk_in = door_thk.to_f
          drawer_front_thk_in = params[:drawer_front_thk_in].to_f

          # Leg length: long enough to read as "mounted" but short enough to NOT
          # poke through the inside face of the door/drawer front.
          # The pull definition mounts at Y=0 (outside face) and legs extend toward -Y.
          # Keep a small safety margin so cylinders do not end exactly on the inside face.
          leg_len_door   = stand_off + [door_thk_in - 0.10, 0.25].max
          leg_len_drawer = stand_off + [drawer_front_thk_in - 0.10, 0.25].max


          # Cabinet class for door bias
          cab_class =
            if type.to_s.upcase.include?("WALL")
              :wall
            elsif type.to_s.upcase.include?("TALL")
              :tall
            else
              :base
            end

          # ----------------------------
          # Drawer fronts: horizontal pull, centered in width; vertical placement configurable.
          # ----------------------------
          drawer_front_specs.each do |sp|
            w = sp[:w].to_f
            h = sp[:h].to_f
            next if w <= 0.0 || h <= 0.0

                        x_center = w / 2.0
            y_center = (drawer_pull_centered ? (h / 2.0) : drawer_top_offset)
            # Optional improvement: if the drawer is too short for the top-offset rule,
            # fall back to vertical center.
            if (y_center + (ctc / 2.0)) > h
              y_center = h / 2.0
            end

            # Validity checks: keep holes on the part.
            next unless (x_center - (ctc / 2.0)) >= 0.0 && (x_center + (ctc / 2.0)) <= w

            # Two holes along X, same Y. We place the pull definition's origin at Hole 1.
            hole1_x = x_center - (ctc / 2.0)

            x_world = sp[:x].to_f + hole1_x
            y_world = sp[:y].to_f + drawer_front_thk_in # outside face
            z_world = sp[:z].to_f + (h - y_center)

            add_hardware_component(he, model,
              name: "Hafele Pull 4\" CTC (#116.07.227)",
              kind: "wire_pull",
              x: x_world, y: y_world, z: z_world,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { ctc: ctc, bar_dia: bar_dia, stand_off: stand_off, leg_len: leg_len_drawer }
            )
          end

          # ----------------------------
          # Doors: vertical pull on latch side.
          # Base/Tall: near top. Wall: near bottom.
          # ----------------------------
          door_specs.each do |ds|
            w = ds[:w].to_f
            h = ds[:h].to_f
            next if w <= 0.0 || h <= 0.0

            # Determine hinge side for this door leaf.
            hs =
              case ds[:side]
              when :left then "Left"
              when :right then "Right"
              else
                hinge_side.to_s
              end
            hs = "Left" if hs == "Auto" || hs.empty?

            # Latch-side inset
            x_center =
              if hs == "Left"
                (w - edge_inset) # latch right
              else
                edge_inset        # latch left
              end

            # Vertical pull placement:
            # Two holes along Y. To align with our pull definition (CTC along X),
            # we place at the LOWER hole then rotate the instance so X->Z.
            #
            # Requirement:
            #   - base/tall (and lower stacked leaves): TOP of pull is 2" down from top.
            #       => upper hole @ y = 2.0
            #       => lower hole @ y = 2.0 + CTC
            #   - wall (and upper stacked leaves): BOTTOM of pull is 2" up from bottom.
            #       => lower hole @ y = h - 2.0
            #
            is_upper_like = (cab_class == :wall || ds[:stack] == :upper)

            y_low =
              if is_upper_like
                (h - door_end_offset)
              else
                (door_end_offset + ctc)
              end

            # Validity checks: keep holes on the part.
            next unless (y_low - ctc) >= 0.0 && y_low <= h

            x_world = ds[:x].to_f + x_center
            y_world = ds[:y].to_f + door_thk # outside face
            z_world = ds[:z].to_f + (h - y_low)

            inst = add_hardware_component(he, model,
              name: "Hafele Pull 4\" CTC (#116.07.227)",
              kind: "wire_pull",
              x: x_world, y: y_world, z: z_world,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { ctc: ctc, bar_dia: bar_dia, stand_off: stand_off, leg_len: leg_len_door }
            )

            # Rotate about Y axis around insertion point so the pull becomes vertical.
            # Use -90° so the pull's length axis (+X in the definition) maps to +Z (up).
            rot = Geom::Transformation.rotation(Geom::Point3d.new(x_world, y_world, z_world), Y_AXIS, -90.degrees)
            inst.transform!(rot) if inst && inst.respond_to?(:transform!)
          end
        end



        
        # Pull style selection (wire_pull | knob | bar_pull | none)
        pull_kind = (params[:pull_kind] || (add_wire_pulls ? "wire_pull" : "none")).to_s

        # Bar pulls (simple approximation: straight bar + two posts; placed like wire pulls)
        if pull_kind == "bar_pull"
          ctc = 5.0
          bar_dia = 0.50
          edge_inset = 1.50 + (bar_dia / 2.0)
          door_end_offset = 2.00
          drawer_top_offset = 1.25
          stand_off = 1.00

          door_thk_in = door_thk.to_f
          drawer_front_thk_in = params[:drawer_front_thk_in].to_f
          leg_len_door   = stand_off + [door_thk_in - 0.10, 0.25].max
          leg_len_drawer = stand_off + [drawer_front_thk_in - 0.10, 0.25].max

          cab_class =
            if type.to_s.upcase.include?("WALL")
              :wall
            elsif type.to_s.upcase.include?("TALL")
              :tall
            else
              :base
            end

          # Drawer fronts: horizontal, centered.
          drawer_front_specs.each do |sp|
            w = sp[:w].to_f
            h = sp[:h].to_f
            next if w <= 0.0 || h <= 0.0

            x_center = w / 2.0
            y_center = (drawer_pull_centered ? (h / 2.0) : drawer_top_offset)
            if (y_center + (ctc / 2.0)) > h
              y_center = h / 2.0
            end
            next unless (x_center - (ctc / 2.0)) >= 0.0 && (x_center + (ctc / 2.0)) <= w

            x_world = sp[:x].to_f + x_center
            y_world = sp[:y].to_f + drawer_front_thk_in
            z_world = sp[:z].to_f + (h - y_center)

            add_hardware_component(he, model,
              name: "Bar Pull 5\" CTC",
              kind: "bar_pull",
              x: x_world, y: y_world, z: z_world,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { ctc: ctc, bar_dia: bar_dia, stand_off: stand_off, leg_len: leg_len_drawer }
            )
          end

          # Doors: vertical on latch side; locate by end offset like wire pull.
          door_specs.each do |ds|
            w = ds[:w].to_f
            h = ds[:h].to_f
            next if w <= 0.0 || h <= 0.0

            hs =
              case ds[:side]
              when :left then "Left"
              when :right then "Right"
              else
                hinge_side.to_s
              end
            hs = "Left" if hs == "Auto" || hs.empty?

            x_center = (hs == "Left") ? (w - edge_inset) : edge_inset

            y_low =
              if cab_class == :wall
                (h - door_end_offset) # bottom-of-pull is near bottom
              else
                door_end_offset + ctc # bottom-of-pull is ctc below the top-of-pull offset
              end

            # Keep within the part.
            next unless (y_low - ctc) >= 0.0 && y_low <= h

            x_world = ds[:x].to_f + x_center
            y_world = ds[:y].to_f + door_thk
            z_world = ds[:z].to_f + (h - y_low)

            add_hardware_component(he, model,
              name: "Bar Pull 5\" CTC",
              kind: "bar_pull",
              x: x_world, y: y_world, z: z_world,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { ctc: ctc, bar_dia: bar_dia, stand_off: stand_off, leg_len: leg_len_door }
            )
          end
        end

        # Knobs (simple cylinder knob)
        if pull_kind == "knob"
          knob_dia = 1.25
          knob_proj = 1.00
          edge_inset = 1.50
          door_offset = 2.00
          drawer_top_offset = 1.25

          cab_class =
            if type.to_s.upcase.include?("WALL")
              :wall
            elsif type.to_s.upcase.include?("TALL")
              :tall
            else
              :base
            end

          # Drawer knobs: centered in width; vertical placement configurable.
          drawer_front_specs.each do |sp|
            w = sp[:w].to_f
            h = sp[:h].to_f
            next if w <= 0.0 || h <= 0.0

            x_center = w / 2.0
            y_center = (drawer_pull_centered ? (h / 2.0) : drawer_top_offset)

            x_world = sp[:x].to_f + x_center
            y_world = sp[:y].to_f + params[:drawer_front_thk_in].to_f
            z_world = sp[:z].to_f + (h - y_center)

            add_hardware_component(he, model,
              name: "Knob 1-1/4\"",
              kind: "knob",
              x: x_world, y: y_world, z: z_world,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { dia: knob_dia, proj: knob_proj }
            )
          end

          # Door knobs: latch side, near top (base/tall) or near bottom (wall).
          door_specs.each do |ds|
            w = ds[:w].to_f
            h = ds[:h].to_f
            next if w <= 0.0 || h <= 0.0

            hs =
              case ds[:side]
              when :left then "Left"
              when :right then "Right"
              else
                hinge_side.to_s
              end
            hs = "Left" if hs == "Auto" || hs.empty?

            x_center = (hs == "Left") ? (w - edge_inset) : edge_inset
            y_on_face = (cab_class == :wall) ? (h - door_offset) : door_offset

            x_world = ds[:x].to_f + x_center
            y_world = ds[:y].to_f + door_thk
            z_world = ds[:z].to_f + (h - y_on_face)

            add_hardware_component(he, model,
              name: "Knob 1-1/4\"",
              kind: "knob",
              x: x_world, y: y_world, z: z_world,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { dia: knob_dia, proj: knob_proj }
            )
          end
        end


# Hinges (Blum 170° concealed hinge + baseplate)
        if add_hinges
          door_specs.each do |ds|
            hcount = hinge_count_for_door_height(ds[:h])
            next if hcount <= 0

            offsets =
              if hcount == 2
                [3.0, ds[:h] - 6.0]
              elsif hcount == 3
                [3.0, (ds[:h] / 2.0), ds[:h] - 6.0]
              else
                [3.0, (ds[:h] * 0.33), (ds[:h] * 0.66), ds[:h] - 6.0]
              end

            hs = hinge_side
            hs = "Left" if hs == "Auto" && ds[:side] == :full
            hs = (ds[:side] == :right) ? "Right" : "Left" if ds[:side] != :full

            panel_thk_in = (params[:panel_thk_in] || 0.75).to_f
            eps = 0.02 # small nudge to avoid z-fighting on the panel face

            hx = if hs == "Left"
                   ds[:x] + panel_thk_in + eps
                 else
                   ds[:x] + ds[:w] - panel_thk_in - eps
                 end
            hy = d - 2.0
            offsets.each do |off|
              hz = ds[:z] + off
              inst = add_hardware_component(he, model,
                name: "Blum Hinge 170° (#71T6680) + Baseplate (#173L8100)",
                kind: "hinge",
                x: hx, y: hy, z: hz,
                tag: tag_hardware, material: mat_hardware,
                dims: {},
                detail: { cup_dia: 1.375, cup_depth: 0.5, plate_lx: 2.0, plate_ly: 1.5, plate_lz: 0.25 }
              )
              # Mirror for right-side doors so the hinge projects into the opening on both sides.
              if hs == "Right" && inst && inst.respond_to?(:transform!)
                mirror = Geom::Transformation.scaling(Geom::Point3d.new(hx, hy, hz), -1, 1, 1)
                inst.transform!(mirror)
              end

              # Sink Base / ADA Sink: rotate hinge 90° about the green axis (Y) to match required orientation.
              if (type == "Sink Base" || type == "ADA Sink") && inst && inst.respond_to?(:transform!)
                rot = Geom::Transformation.rotation(Geom::Point3d.new(hx, hy, hz), Y_AXIS, 90.degrees)
                inst.transform!(rot)
              end
            end
          end
        end

        # Door bumpers (Hafele #356.21.428 3/8" clear rubber)
        # Requirement: latch side only (opposite hinge), and placed between carcass front and door back.
        if add_door_bumpers
          dia = 0.375
          depth = 0.25
          inset = 0.25
          y0 = d - depth

          door_specs.each do |ds|
            # Determine the hinge side for this specific door leaf.
            hs =
              case ds[:side]
              when :left  then "Left"
              when :right then "Right"
              else
                hinge_side.to_s
              end
            hs = "Left" if hs == "Auto" || hs.empty?

            latch_side = (hs == "Left") ? "Right" : "Left"

            # Place bumpers on the carcass front plane, on the latch side, inset from the door edge.
            bx =
              if latch_side == "Right"
                (ds[:x] + ds[:w] - inset - dia)
              else
                (ds[:x] + inset)
              end

            z_top = ds[:z] + ds[:h] - 0.75
            z_bot = ds[:z] + 0.75

            [z_top, z_bot].each do |bz|
              add_hardware_component(he, model,
                name: "Hafele Door Bumper 3/8\" (#356.21.428)",
                kind: "bumper",
                x: bx, y: y0, z: bz,
                tag: tag_hardware, material: mat_hardware,
                dims: { dia: dia, depth: depth },
                detail: {}
              )
            end
          end
        end

        # Shelf supports (Hafele #282.11.752)
        if add_shelf_supports && shelf_specs.any?
          shelf_specs.each do |s|
            x1 = s[:x] + 1.0
            x2 = s[:x] + s[:lx] - 1.0
            y1 = s[:y] + 1.0
            y2 = s[:y] + s[:ly] - 1.0
            z0 = s[:z] + (s[:lz] / 2.0)
            [[x1, y1], [x2, y1], [x1, y2], [x2, y2]].each do |xx, yy|
              add_hardware_component(he, model,
                name: "Hafele Shelf Support (#282.11.752)",
                kind: "shelf_support",
                x: xx, y: yy, z: z0,
                tag: tag_hardware, material: mat_hardware,
                dims: {},
                detail: { pin_dia: 0.25, pin_len: 0.5, tab: 0.25 }
              )
            end
          end
        end

        # Cam lock (CompX National C8060)
        if add_cam_lock
          add_hardware_component(he, model,
            name: "CompX National Cam Lock (C8060)",
            kind: "cam_lock",
            x: (w / 2.0),
            y: (d - 1.0),
            z: (cabinet_top_z - 2.0),
            tag: tag_hardware, material: mat_hardware,
            dims: {},
            detail: { dia: 0.75, len: 0.75, cam_lx: 0.75, cam_ly: 0.5, cam_lz: 0.125 }
          )
        end

        # Countertop brackets (A&M 21x21) - ADA Sink only
        if add_countertop_brackets && is_ada_sink
          leg = 21.0
          th = 0.125
          z0 = [cabinet_top_z - leg, 0.0].max
          yb = back_thk + 0.5
          [thk + 0.25, (w - thk - 0.25 - th)].each do |xx|
            add_hardware_component(he, model,
              name: "A&M Hardware Countertop Bracket 21x21",
              kind: "bracket",
              x: xx, y: yb, z: z0,
              tag: tag_hardware, material: mat_hardware,
              dims: {},
              detail: { th: th, leg: leg }
            )
          end
        end

        # File drawer hardware
        # NOTE: Never generate tall vertical "posts" that can be mistaken for slides.
        # Represent file rails as lightweight horizontal members running front-to-back
        # near the top inside of the drawer box.
        if add_file_drawer_hw && drawer_front_specs.any?
          drawer_box_depth = (d - back_thk - 1.75)
          drawer_box_depth = [drawer_box_depth, 6.0].max

          drawer_front_specs.each do |df|
            next if df[:side] == :false_front
            next unless df[:h].to_f >= file_drawer_min_front_h

            rail_lx = 0.50   # thickness across X
            rail_ly = drawer_box_depth # runs along Y (depth)
            rail_lz = 0.50   # low profile height (Z)

            # Place rails just below the top of the drawer box cavity.
            z0 = df[:z] + df[:h].to_f - 1.25
            y0 = back_thk + 1.75

            add_hardware_component(he, model,
              name: "File Drawer Rail - Left",
              kind: "block",
              x: df[:x] + 1.0,
              y: y0,
              z: z0,
              tag: tag_hardware, material: mat_hardware,
              dims: { lx: rail_lx, ly: rail_ly, lz: rail_lz },
              detail: {}
            )
            add_hardware_component(he, model,
              name: "File Drawer Rail - Right",
              kind: "block",
              x: (df[:x] + df[:w] - 1.0 - rail_lx),
              y: y0,
              z: z0,
              tag: tag_hardware, material: mat_hardware,
              dims: { lx: rail_lx, ly: rail_ly, lz: rail_lz },
              detail: {}
            )
          end
        end
      end

      # ----------------------------
      # Countertop (Sink Base + ADA Sink)
      # - Places slab from cabinet_top_z to finished_top_h
      # ----------------------------
      # Countertop geometry disabled by default (build_countertop=false)
      if has_countertop && build_countertop
        ct_grp = ce.add_group
        ct_grp.name = "Countertop"
        ct_grp.layer = tag_countertop
        cte = ct_grp.entities

        add_part_component(cte, model,
          name: "Countertop Slab",
          x: 0.0, y: 0.0, z: cabinet_top_z,
          lx: w, ly: d, lz: countertop_thk,
          tag: tag_countertop, material: mat_countertop
        )
      end

      # Model 10580 uses the cabinet's left-front-bottom as its local origin.
      # Placement height is controlled by the installer/project, not baked into geometry.

# Compute and persist a catalog model number for every generated cabinet.
begin
  params[:model_number] = compute_model_number(params)
  if root && root.valid?
    base_name = root.name.to_s
    mn = params[:model_number].to_s
    if !mn.empty?
      # Keep existing user name, but ensure model number is visible in Outliner.
      base_name = base_name.gsub(/\s*\(.*?–.*?\)\s*$/, "").strip
      root.name = base_name.empty? ? mn : "#{base_name} (#{mn})"
    end
  end
rescue
  # do not block generation on model-number issues
end

orient_cabinet_geometry_for_native_front!(root, w, d, params)
write_cabinet_attributes(root, params)
      ensure_default_scenes(model)
      model.commit_operation if model && model.respond_to?(:commit_operation)
      operation_started = false
      root
    rescue => e
      model.abort_operation if operation_started && model && model.respond_to?(:abort_operation)
      raise
    end

    # ----------------------------
    # UI (HtmlDialog + detailed preview)
    # ----------------------------
    def self.show_dialog(edit_selected: false)
      @pending_edit_selected = !!edit_selected
      @dialog ||= UI::HtmlDialog.new(
        dialog_title: "ForgeCase",
        preferences_key: "#{PREF_KEY}_dialog",
        scrollable: true,
        resizable: true,
        width: 640,
        height: 980,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      embedded_defaults = merged_params_for_type("Base")
      embedded_defaults_json = embedded_defaults.to_json

      html = SkilledServices::DialogTemplate.render("index", "EMBED_DEFAULTS_JSON" => embedded_defaults_json)

      @dialog.set_html(html)

      # Callbacks
      @dialog.add_action_callback("ready") do |_ctx|
        if @pending_edit_selected
          @pending_edit_selected = false
          load_selected_into_dialog
        else
          init = merged_params_for_type("Base")
          @dialog.execute_script("set_form(#{init.to_json})")
        end
        catalog = SkilledServices::Catalog::Loader.all
        last_code = Sketchup.read_default(PREF_KEY, "last_catalog_code", catalog.first["code"]).to_s
        @dialog.execute_script("initialize_catalog(#{catalog.to_json}, #{last_code.to_json})")
      end

      @dialog.add_action_callback("load_model") do |_ctx, code|
        item = SkilledServices::Catalog::Loader.find(code)
        next unless item
        params = merged_params_for_type(item["cabinet_type"])
        params.merge!(SkilledServices::Catalog::Loader.placement_params(code))
        Sketchup.write_default(PREF_KEY, "last_catalog_code", item["code"])
        @dialog.execute_script("set_form(#{params.to_json}); set_catalog_selection(#{item["code"].to_json});")
      end

      @dialog.add_action_callback("load_type") do |_ctx, type|
        type = type.to_s
        data = standard_params_for_type(type)
        @dialog.execute_script("set_form(#{data.to_json})")
      end

      @dialog.add_action_callback("reset_type") do |_ctx, type|
        type = type.to_s
        data = defaults_for(type)
        write_saved_for_type(type, data)
        @dialog.execute_script("set_form(#{data.to_json})")
      end

      @dialog.add_action_callback("reset_all") do |_ctx|
        ["Base", "Wall", "Tall", "Sink Base", "ADA Sink", "Trash Can", "Cubbies",
         "Appliance End Panel", "Diagonal Corner Base", "Pie-Cut Corner Base", "Blind Corner Base"].each do |t|
          write_saved_for_type(t, defaults_for(t))
        end
        init = merged_params_for_type("Base")
        @dialog.execute_script("set_form(#{init.to_json})")
      end

      @dialog.add_action_callback("edit_selected") do |_ctx|
        begin
          load_selected_into_dialog
        rescue => e
          UI.messagebox("Edit failed:\n#{e.class}: #{e.message}")
        end
      end

      

@dialog.add_action_callback("compute_model_number") do |_ctx, json|
  begin
    params = JSON.parse(json, symbolize_names: true)
    mn = compute_model_number(params)
    @dialog.execute_script("if (window.set_model_number) set_model_number(#{mn.to_json});")
  rescue
    @dialog.execute_script('if (window.set_model_number) set_model_number("");')
  end
end

@dialog.add_action_callback("place") do |_ctx, json|
        begin
          # Debounce accidental double-clicks on the UI "Place Cabinet" button.
          # If the same payload is received twice within a short window, ignore the duplicate.
          begin
            @last_place_sig ||= nil
            @last_place_at  ||= 0.0
            now = Time.now.to_f
            sig = Digest::SHA1.hexdigest(json.to_s)
            if @last_place_sig == sig && (now - @last_place_at) < 0.60
              begin
                @dialog.execute_script("if (window.on_place_done) on_place_done(false);")
              rescue
              end
              next
            end
            @last_place_sig = sig
            @last_place_at  = now
          rescue
            # If debounce fails for any reason, proceed normally.
          end

          params = JSON.parse(json, symbolize_names: true)
          edit_pid = params.delete(:edit_target_pid)

          type = params[:cabinet_type].to_s

      # ADA applies ONLY to the ADA Sink cabinet type
      is_ada_sink = (type == "ADA Sink")

          merged = defaults_for(type).merge(params)
          write_saved_for_type(type, merged)

          model = Sketchup.active_model
          raise "No active model." unless model

          # "Place/Edit" behavior:
          # - If the dialog is in edit mode, it sends a persistent_id.
          # - If that id is missing/invalid (common in some SketchUp workflows),
          #   fall back to the current selection and edit the selected cabinet group.
          target = nil
          if edit_pid && edit_pid.to_i > 0
            target = find_entity_by_pid(model, edit_pid)
          end
          if !(target && target.is_a?(Sketchup::Group) && target.valid?)
            target = selected_cabinet_group(model)
          end

          if target && target.is_a?(Sketchup::Group) && target.valid? && cabinet_group?(target)
            root = build_cabinet(model, merged, target_group: target, operation_name: "Edit ForgeCase Cabinet")
          else
            root = build_cabinet(model, merged, target_group: nil, operation_name: "Generate ForgeCase Cabinet")

            if type == "Wall"
              tr = Geom::Transformation.translation([0.0, 0.0, wall_install_z_offset_in])
              root.transform!(tr)
            end

            # Auto-place new cabinets beside the previously placed cabinet (avoid overlap)
            begin
              last = @last_placed_cabinet
              if last && last.valid? && last.respond_to?(:bounds)
                last_bb = last.bounds
                new_bb  = root.bounds
                dx = last_bb.max.x - new_bb.min.x
                dy = last_bb.min.y - new_bb.min.y
                gap = in_to_length(0.0) # set to 0.0 for flush; change if you want spacing
                root.transform!(Geom::Transformation.translation([dx + gap, dy, 0.0]))
              end
            rescue
              # ignore auto-placement failures
            end
          end

          
          # Remember last placed cabinet for auto-placement of the next cabinet.
          @last_placed_cabinet = root if root && root.valid? && (!edit_pid || edit_pid.to_i <= 0)
	          model.selection.clear
	          # Selection.add only accepts Drawingelements. Some build paths may
	          # return nil on non-fatal issues; avoid hard failure.
	          model.selection.add(root) if root && root.is_a?(Sketchup::Drawingelement)
          begin
            mn = root.get_attribute(CABINET_ATTR_DICT, CABINET_ATTR_MODEL_NUMBER).to_s
            @dialog.execute_script("if (window.set_model_number) set_model_number(#{mn.to_json});")
          rescue
          end

          # Notify the UI that placement has completed so it can re-enable buttons.
          begin
            @dialog.execute_script("if (window.on_place_done) on_place_done(true);")
          rescue
          end
        rescue => e
          bt = (e.backtrace || []).grep(/cabinetgenerator\.rb/).first || (e.backtrace || []).first
          UI.messagebox("Placement failed:
#{e.class}: #{e.message}
#{bt}")

          begin
            @dialog.execute_script("if (window.on_place_done) on_place_done(false);")
          rescue
          end
        end
      end

      @dialog.show
    end


# -------------------------------------------------------------------------
# Countertops
# -------------------------------------------------------------------------

# Defaults
DEFAULT_COUNTERTOP_THK_IN = 1.5
# Countertop front overhang beyond finished front (doors/drawer fronts)
COUNTERTOP_FRONT_REVEAL_IN = 0.25
# Default door/drawer-front thickness used for countertop depth when cabinet params don't provide it
DEFAULT_DOOR_THK_IN = 0.75

MAX_COUNTERTOP_SECTION_IN = 144.0 # 12ft

ADA_MAX_COUNTERTOP_AFF_IN = 32.5

def self._selected_cabinet_instances
  sel = Sketchup.active_model.selection
  sel.grep(Sketchup::ComponentInstance) + sel.grep(Sketchup::Group)
end

def self._cabinet_params_from_instance(inst)
  dict = inst.get_attribute(CABINET_ATTR_DICT, CABINET_ATTR_PARAMS_JSON)
  return nil if dict.nil? || dict.to_s.strip.empty?
  JSON.parse(dict, symbolize_names: true)
rescue
  nil
end

def self._is_sink_base?(params)
  t = params[:type].to_s.downcase
  return true if t.include?("sink")
  # Some builds store cabinet type under cabinet_type
  t2 = params[:cabinet_type].to_s.downcase
  t2.include?("sink")
end

def self._cabinet_top_z_for_instance(inst)
  params = _cabinet_params_from_instance(inst) || {}
  tr = inst.transformation
  # finished_top_h is the top-of-countertop height used by the generator.
  if params[:finished_top_h]
    ft = in_to_length(params[:finished_top_h].to_f)
    if params[:has_countertop] && params[:countertop_thk_in]
      ct = in_to_length(params[:countertop_thk_in].to_f)
      return tr.origin.z + ft - ct
    end
    return tr.origin.z + ft
  end
  inst.bounds.max.z
end

# Backward-compatibility alias (older builds used a typo)
def self._cabinet_cabinet_top_z_for_instance(inst)
  _cabinet_top_z_for_instance(inst)
end



# Compute signed distance from a point to a plane.
# Plane may be [a,b,c,d] or [point, normal].
def self._point_plane_distance(pt, plane)
  if plane.is_a?(Array) && plane.length == 4 && plane[0].is_a?(Numeric)
    a, b, c, d = plane
    denom = Math.sqrt(a*a + b*b + c*c)
    return 0.0 if denom < 1e-9
    return (a*pt.x + b*pt.y + c*pt.z + d) / denom
  end

  p0, n = plane
  n = n.clone
  denom = n.length.to_f
  return 0.0 if denom < 1e-9
  n = n.normalize
  a, b, c = n.to_a
  d = -(a*p0.x + b*p0.y + c*p0.z)
  (a*pt.x + b*pt.y + c*pt.z + d) # denom is 1.0 after normalize
end

def self.add_countertops_to_selection
  model = Sketchup.active_model
  insts = _selected_cabinet_instances
    if insts.empty?
    UI.messagebox("Select one or more generated cabinets first.")
    return
  end

  countertop_types = ["Plastic Laminate", "Solid Surface", "Other (Buyout)"]

  prompts  = ["Countertop thickness (in)", "Countertop material", "Layout", "Backsplash height (in)", "Create sink cutouts"]
  defaults = [DEFAULT_COUNTERTOP_THK_IN, countertop_types.first, "Auto (Straight / L / U)", 4.0, "Yes"]
  lists    = ["", countertop_types.join("|"), "Auto (Straight / L / U)|Straight|L Shape|U Shape", "", "Yes|No"]

  input = UI.inputbox(prompts, defaults, lists, "Add Countertops")
  return unless input

  ct_thk_in = input[0].to_f
  ct_mat    = input[1].to_s
  layout = input[2].to_s
  backsplash_height = in_to_length(input[3].to_f)
  create_sink_cutouts = input[4].to_s == "Yes"
  ct_thk = in_to_length(ct_thk_in)

  # Group cabinets by top elevation (tolerance ~ 1/16")
  tol = in_to_length(1.0 / 16.0)
  clusters = []
  insts.each do |inst|
    z = _cabinet_top_z_for_instance(inst)
    found = clusters.find { |c| (c[:z] - z).abs <= tol }
    if found
      found[:insts] << inst
    else
      clusters << { z: z, insts: [inst] }
    end
  end

  model.start_operation("Add Countertops", true)
  begin
    parent = model.active_entities.add_group
    parent.name = "Countertops - #{ct_mat}"
    parent.set_attribute(CABINET_ATTR_DICT, "countertop_material", ct_mat)
    parent.set_attribute(CABINET_ATTR_DICT, "layout", layout)
    parent.layer = nil
    parent.hidden = false
    clusters.each_with_index do |c, idx|
      sections = _countertop_sections_from_cabinets(c[:insts])

      sections.each_with_index do |sec, sidx|
        grp = parent.entities.add_group
        grp.name = "Countertop_#{idx + 1}_S#{sidx + 1}"
        grp.layer = nil
        grp.hidden = false
        grp.set_attribute(CABINET_ATTR_DICT, "countertop_material", ct_mat)
        insts_in_section = sec[:insts]
        _build_countertop_l_shape(grp.entities, insts_in_section, c[:z], ct_thk,
          backsplash_height: backsplash_height, create_sink_cutouts: create_sink_cutouts)
      end
    end
    model.commit_operation
  rescue => e
    model.abort_operation
    UI.messagebox("Failed to add countertops:\n#{e.class}: #{e.message}")
  end
end


def self._countertop_sections_from_cabinets(cabinet_insts)
  # Split a countertop run into <= 12ft sections, with joints at cabinet edges.
  return [{ insts: cabinet_insts }] if cabinet_insts.length <= 1

  # Order by X (world aligned)
  ordered = cabinet_insts.sort_by { |i| i.bounds.min.x }

  # Candidate joint positions: cabinet right edges (max.x)
  edges = [ordered.first.bounds.min.x]
  ordered.each { |i| edges << i.bounds.max.x }
  edges = edges.uniq.sort

  max_len = in_to_length(MAX_COUNTERTOP_SECTION_IN)

  sections = []
  i = 0
  while i < edges.length - 1
    start_x = edges[i]
    limit_x = start_x + max_len

    # Find farthest edge <= limit_x
    candidates = edges.select { |e| e > start_x + 0.001 && e <= limit_x + 0.001 }
    break if candidates.empty?

    end_x = candidates.last

    # Collect cabinets fully within [start_x, end_x] (joints are at cabinet edges so no partials)
    insts = ordered.select { |inst| inst.bounds.min.x >= start_x - 0.001 && inst.bounds.max.x <= end_x + 0.001 }

    # Fallback: if none match (due to floating rounding), include any overlapping
    if insts.empty?
      insts = ordered.select { |inst| inst.bounds.max.x > start_x + 0.001 && inst.bounds.min.x < end_x - 0.001 }
    end

    sections << { insts: insts }
    i = edges.index(end_x)
    break if i.nil?
  end

  # If we somehow didn't reach the end, include remaining as last section
  unless sections.empty?
    used = sections.flat_map { |s| s[:insts] }.uniq
    remaining = ordered - used
    sections << { insts: remaining } unless remaining.empty?
  end

  sections
end



# --- Countertop bridging helpers ---
def self._cab_back_and_depth(inst)
  b = inst.bounds
  y0 = b.min.y
  y1 = b.max.y
  back_y = [y0, y1].min
  depth  = (y1 - y0).abs

  # Extend to finished front (doors/drawer fronts) plus 1/4" reveal.
  # Assumes the cabinet instance bounds reflect the carcass depth.
  depth += countertop_front_overhang_length(inst)

  [back_y, depth]
end


def self._bridge_eligible?(a, b, max_gap_in: 42.0, max_depth_diff_in: 6.0, back_tol_in: 1.0/16.0)
  a_back, a_depth = _cab_back_and_depth(a)
  b_back, b_depth = _cab_back_and_depth(b)

  return false if (a_back - b_back).abs > in_to_length(back_tol_in)
  return false if (a_depth - b_depth).abs > in_to_length(max_depth_diff_in)

  ab = a.bounds
  bb = b.bounds
  left, right = (ab.min.x <= bb.min.x) ? [ab, bb] : [bb, ab]
  gap = right.min.x - left.max.x
  gap > in_to_length(0.001) && gap <= in_to_length(max_gap_in)
end

def self._countertop_bridge_rects(instances, max_gap_in: 42.0, max_depth_diff_in: 6.0, back_tol_in: 1.0/16.0)
  rects = []
  instances.combination(2) do |a, b|
    next unless _bridge_eligible?(a, b, max_gap_in: max_gap_in, max_depth_diff_in: max_depth_diff_in, back_tol_in: back_tol_in)

    ab = a.bounds
    bb = b.bounds
    a_back, a_depth = _cab_back_and_depth(a)
    b_back, b_depth = _cab_back_and_depth(b)

    left, right = (ab.min.x <= bb.min.x) ? [ab, bb] : [bb, ab]

    x0 = left.max.x
    x1 = right.min.x
    back_y = (a_back + b_back) * 0.5
    depth  = [a_depth, b_depth].max

    y0 = back_y
    y1 = back_y + depth
    rects << [x0, x1, y0, y1]
  end
  rects
end

def self._build_countertop_l_shape(ents, cabinet_insts, top_z, ct_thk, backsplash_height: 0.0, create_sink_cutouts: true)
  # Draw each cabinet footprint rectangle at top_z into a single entities context.
  # SketchUp will automatically merge coplanar faces where rectangles touch/overlap.
  tr_up = Geom::Transformation.translation([0, 0, top_z])
  cabinet_insts.each do |inst|
    bb = inst.bounds
    # footprint rectangle in XY using instance bounds (world-aligned),
    # with front overhang to finished front + reveal.
    back_y, depth = _cab_back_and_depth(inst)
    front_y = back_y + depth
    y_min = [back_y, front_y].min
    y_max = [back_y, front_y].max

    p1 = Geom::Point3d.new(bb.min.x, y_min, 0)
    p2 = Geom::Point3d.new(bb.max.x, y_min, 0)
    p3 = Geom::Point3d.new(bb.max.x, y_max, 0)
    p4 = Geom::Point3d.new(bb.min.x, y_max, 0)
    face = ents.add_face(p1, p2, p3, p4)
    face.reverse! if face.normal.z < 0
  end


# Add bridge rectangles between separated cabinets if:
# - gap <= 42"
# - cabinet backs are coplanar (within ~1/16")
# - cabinet depths within 6"
# The bridge depth covers the deeper cabinet.
_countertop_bridge_rects(cabinet_insts, max_gap_in: 42.0, max_depth_diff_in: 6.0, back_tol_in: 1.0/16.0).each do |x0, x1, y0, y1|
  bp1 = Geom::Point3d.new(x0, y0, 0)
  bp2 = Geom::Point3d.new(x1, y0, 0)
  bp3 = Geom::Point3d.new(x1, y1, 0)
  bp4 = Geom::Point3d.new(x0, y1, 0)
  bface = ents.add_face(bp1, bp2, bp3, bp4)
  bface.reverse! if bface && bface.normal.z < 0
end

  # Create a centered rectangular sink opening for cataloged sink bases.
  if create_sink_cutouts
    cabinet_insts.each do |inst|
      params = _cabinet_params_from_instance(inst) || {}
      next unless _is_sink_base?(params)
      bb = inst.bounds
      cut_w = [in_to_length(params[:sink_cutout_width_in] || 22.0), bb.width - in_to_length(4)].min
      cut_d = [in_to_length(params[:sink_cutout_depth_in] || 16.0), bb.depth - in_to_length(4)].min
      cx = (bb.min.x + bb.max.x) * 0.5
      back_y, depth = _cab_back_and_depth(inst)
      cy = back_y + depth * 0.52
      cut = ents.add_face(
        [cx - cut_w / 2, cy - cut_d / 2, 0], [cx + cut_w / 2, cy - cut_d / 2, 0],
        [cx + cut_w / 2, cy + cut_d / 2, 0], [cx - cut_w / 2, cy + cut_d / 2, 0]
      )
      cut.erase! if cut && cut.valid?
    end
  end

  # Ensure the countertop becomes a true solid by merging coplanar top faces
  # before extrusion (erasing internal coplanar edges yields contiguous faces).
  begin
    ents.grep(Sketchup::Edge).dup.each do |e|
      next unless e.valid? && e.faces.length == 2
      f1, f2 = e.faces
      next unless f1 && f2
      next unless (f1.normal.z.abs - 1.0).abs < 1e-6 && (f2.normal.z.abs - 1.0).abs < 1e-6
      next unless f1.normal.parallel?(f2.normal)
      e.erase!
    end
  rescue
    # Non-fatal; extrusion still proceeds.
  end

  # Move all geometry up to the cabinet top plane
  ents.transform_entities(tr_up, ents.to_a)


  # Merge coplanar horizontal faces before PushPull so the result is a single solid slab
  # (internal coplanar edges can create internal faces/walls that prevent solid groups).
  tol = in_to_length(1.0/64.0)
  ents.grep(Sketchup::Edge).dup.each do |e|
    next unless e.valid?
    next unless e.faces.length == 2
    f1, f2 = e.faces
    next unless f1 && f2 && f1.valid? && f2.valid?
    next unless (f1.normal.z.abs - 1.0).abs < 1e-6 && (f2.normal.z.abs - 1.0).abs < 1e-6

    p1 = f1.plane
    p2 = f2.plane
    # planes are [a,b,c,d]; for horizontal faces, a=b=0 and c is +/-1, so compare d
    next unless (p1[3] - p2[3]).abs <= tol

    begin
      e.erase!
    rescue
      # ignore edges that can't be erased due to transient geometry state
    end
  end

  # PushPull all top faces down to create slabs
  faces = ents.grep(Sketchup::Face).select { |f| (f.normal.z.abs - 1.0).abs < 1e-6 }
  faces.each do |f|
    # Ensure extrusion goes UP from the cabinet-top plane (bottom of countertop sits on cabinet tops)
    # Face normal can be flipped depending on point order; force it upward before pushpull.
    f.reverse! if f.normal.z < 0
    f.pushpull(ct_thk, false)
  end


  # Backsplash follows each cabinet back edge, supporting straight, L, and U layouts.
  if backsplash_height.to_f > 0.0
    backsplash_thk = in_to_length(0.75)
    cabinet_insts.each do |inst|
      bb = inst.bounds
      back_y, = _cab_back_and_depth(inst)
      face = ents.add_face(
        [bb.min.x, back_y, top_z + ct_thk], [bb.max.x, back_y, top_z + ct_thk],
        [bb.max.x, back_y, top_z + ct_thk + backsplash_height], [bb.min.x, back_y, top_z + ct_thk + backsplash_height]
      )
      face.pushpull(backsplash_thk, false) if face
    end
  end

  # Optional: soften internal coplanar edges for nicer selection
  ents.grep(Sketchup::Edge).each do |e|
    next unless e.faces.length == 2
    f1, f2 = e.faces
    next unless f1.normal.parallel?(f2.normal) # coplanar
    e.soft = true
    e.smooth = true
  end
end



# -------------------------------------------------------------------------
# Shop drawing scenes (ALL FRONT + RIGHT SECTION by cabinet type)
# -------------------------------------------------------------------------

def create_shop_scenes_sections_and_front_all
  model = Sketchup.active_model
  view  = model.active_view
  ents  = model.active_entities

  cabs = _all_cabinet_groups(ents)
  if cabs.empty?
    UI.messagebox("No cabinets found. (No Groups with #{CABINET_ATTR_DICT}/#{CABINET_ATTR_PARAMS_JSON})")
    return
  end

  model.start_operation("Create Shop Drawing Scenes", true)
  begin
    _install_section_scene_observer(model)
    _create_standard_shop_views(model, view, cabs)
    _create_front_scene_all_cabinets(model, view, cabs)
    _create_right_section_scenes_by_type(model, view, cabs)
    model.commit_operation
  rescue => e
    model.abort_operation
    raise
  end
rescue => e
  UI.messagebox("Scene creation failed:\n#{e.class}: #{e.message}\n\n#{e.backtrace&.first(12)&.join("\n")}")
end
module_function :create_shop_scenes_sections_and_front_all

def _create_standard_shop_views(model, view, cabs)
  bb = _combined_bounds(cabs)
  center = bb.center
  distance = [bb.width, bb.depth, bb.height].max * 3.0 + in_to_length(24)
  views = {
    "PLAN" => [Geom::Point3d.new(center.x, center.y, center.z + distance), Y_AXIS],
    "LEFT ELEVATION" => [Geom::Point3d.new(center.x - distance, center.y, center.z), Z_AXIS],
    "RIGHT ELEVATION" => [Geom::Point3d.new(center.x + distance, center.y, center.z), Z_AXIS]
  }
  views.each do |name, (eye, up)|
    _set_parallel_camera_and_zoom(view, eye: eye, target: center, up: up, zoom_entities: cabs)
    page = _ensure_page(name)
    page.use_camera = true if page.respond_to?(:use_camera=)
  end

  eye = Geom::Point3d.new(center.x + distance, center.y + distance, center.z + distance)
  camera = Sketchup::Camera.new(eye, center, Z_AXIS)
  camera.perspective = true
  view.camera = camera
  view.zoom(cabs)
  page = _ensure_page("3D VIEW")
  page.use_camera = true if page.respond_to?(:use_camera=)
end
module_function :_create_standard_shop_views

def create_professional_report(kind)
  model = Sketchup.active_model
  service = SkilledServices::Reports::ReportService.new(model)
  csv = service.to_csv(kind)
  label = kind.to_s.split("_").map(&:capitalize).join(" ")
  path = UI.savepanel("Save #{label} Report (CSV)", model.path.to_s.empty? ? nil : File.dirname(model.path), "#{kind}_report.csv")
  return unless path
  File.open(path, "wb") { |file| file.write(csv) }
  UI.messagebox("Saved #{label} report:\n#{path}")
rescue StandardError => e
  UI.messagebox("#{label || 'Report'} failed:\n#{e.class}: #{e.message}")
end
module_function :create_professional_report

# -------------------------------------------------------------------------
# Report: Model numbers + quantities, sorted by room
# -------------------------------------------------------------------------

def create_cabinet_report_by_room
  model = Sketchup.active_model

  cabs = []
  _all_cabinet_groups_recursive(model.entities, cabs)

  if cabs.empty?
    UI.messagebox("No cabinets found. (No Groups with #{CABINET_ATTR_DICT}/#{CABINET_ATTR_PARAMS_JSON})")
    return
  end

  rows = _cabinet_report_rows_by_room(cabs)

  # Build CSV
  csv_lines = ["Room,Model Number,Qty"]
  rows.each do |r|
    room = (r[:room].to_s.empty? ? "Unassigned" : r[:room].to_s)
    mn   = r[:model_number].to_s
    qty  = r[:qty].to_i
    # basic CSV escaping
    room_esc = room.include?(",") || room.include?('"') ? '"' + room.gsub('"','""') + '"' : room
    mn_esc   = mn.include?(",")   || mn.include?('"')   ? '"' + mn.gsub('"','""')   + '"' : mn
    csv_lines << "#{room_esc},#{mn_esc},#{qty}"
  end
  csv = csv_lines.join("\n")

  # Save prompt
  default_name = "cabinet_report_by_room.csv"
  save_path = UI.savepanel("Save Cabinet Report (CSV)", model.path && !model.path.empty? ? File.dirname(model.path) : nil, default_name)
  if save_path
    File.open(save_path, "wb") { |f| f.write(csv) }
    UI.messagebox("Saved cabinet report:\n#{save_path}")
  end

  # Also show a quick in-app preview dialog
  _show_report_dialog("Cabinet Report (by Room)", rows, csv)
rescue => e
  UI.messagebox("Cabinet report failed:\n#{e.class}: #{e.message}\n\n#{e.backtrace&.first(12)&.join("\n")}")
end
module_function :create_cabinet_report_by_room

# Back-compat alias for menu binding
def create_cabinet_report
  create_cabinet_report_by_room
end
module_function :create_cabinet_report

def _all_cabinet_groups_recursive(entities, out)
  entities.grep(Sketchup::Group).each do |g|
    out << g if cabinet_group?(g)
    # Recurse into group contents (rooms, nested containers, etc.)
    begin
      _all_cabinet_groups_recursive(g.entities, out) if g.entities
    rescue
    end
  end
end
module_function :_all_cabinet_groups_recursive

def _cabinet_report_rows_by_room(cabs)
  # room => { model_number => qty }
  agg = Hash.new { |h,k| h[k] = Hash.new(0) }

  cabs.each do |g|
    mn = g.get_attribute(CABINET_ATTR_DICT, CABINET_ATTR_MODEL_NUMBER)
    mn = mn.to_s.strip
    next if mn.empty?

    room = _extract_room_from_cabinet(g)
    room = room.to_s.strip
    room = "Unassigned" if room.empty?

    agg[room][mn] += 1
  end

  rooms_sorted = agg.keys.sort_by { |r| r.to_s.downcase }
  rows = []
  rooms_sorted.each do |room|
    models = agg[room].keys.sort_by { |mn| mn.to_s.downcase }
    models.each do |mn|
      rows << { room: room, model_number: mn, qty: agg[room][mn] }
    end
  end
  rows
end
module_function :_cabinet_report_rows_by_room

def _extract_room_from_cabinet(g)
  # Prefer explicit attribute if you ever add one later
  room = g.get_attribute(CABINET_ATTR_DICT, "room")
  return room if room && !room.to_s.strip.empty?

  pj = g.get_attribute(CABINET_ATTR_DICT, CABINET_ATTR_PARAMS_JSON)
  return nil if pj.nil? || pj.to_s.strip.empty?

  begin
    data = JSON.parse(pj.to_s)
    return data["room"] || data["Room"] || data["ROOM"] || data["room_name"] || data["RoomName"]
  rescue
    return nil
  end
end
module_function :_extract_room_from_cabinet

def _show_report_dialog(title, rows, csv)
  if defined?(UI::HtmlDialog)
    html_rows = rows.map do |r|
      "<tr><td>#{_h(r[:room])}</td><td>#{_h(r[:model_number])}</td><td style='text-align:right'>#{r[:qty].to_i}</td></tr>"
    end.join

    html = SkilledServices::DialogTemplate.render("report", "TITLE" => _h(title), "TABLE_ROWS" => html_rows, "CSV" => _h(csv))

    dlg = UI::HtmlDialog.new(
      dialog_title: title,
      preferences_key: "skservices_eurocabinet_report",
      width: 700,
      height: 650,
      resizable: true,
      scrollable: true,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
    dlg.set_html(html)
    dlg.show
  else
    # fallback
    UI.messagebox(csv)
  end
end
module_function :_show_report_dialog

def _h(s)
  s.to_s.gsub("&","&amp;").gsub("<","&lt;").gsub(">","&gt;").gsub('"',"&quot;")
end
module_function :_h


def _all_cabinet_groups(entities)
  entities.grep(Sketchup::Group).select { |g| cabinet_group?(g) }
end
module_function :_all_cabinet_groups

def _combined_bounds(groups)
  bb = Geom::BoundingBox.new
  groups.each { |g| bb.add(g.bounds) }
  bb
end
module_function :_combined_bounds

def _avg_axis(groups, which=:yaxis)
  v = Geom::Vector3d.new(0,0,0)
  groups.each do |g|
    ax = g.transformation.send(which)
    next unless ax.is_a?(Geom::Vector3d)
    ax = ax.clone
    next if ax.length.to_f == 0.0
    ax.length = 1.0
    v.x += ax.x; v.y += ax.y; v.z += ax.z
  end
  return Geom::Vector3d.new(0,1,0) if v.length.to_f == 0.0
  v.length = 1.0
  v
end
module_function :_avg_axis

def _set_parallel_camera_and_zoom(view, eye:, target:, up:, zoom_entities:)
  cam = Sketchup::Camera.new(eye, target, up)
  cam.perspective = false
  view.camera = cam
  if zoom_entities && !zoom_entities.empty?
    view.zoom(zoom_entities)  # SketchUp 2026: must be entities/selection, not BoundingBox
  else
    view.zoom_extents
  end
end
module_function :_set_parallel_camera_and_zoom

def _ensure_page(name)
  model = Sketchup.active_model
  pages = model.pages
  # If a page with same name exists, reuse it (avoid duplicates)
  existing = pages.find { |p| p.name == name }
  existing || pages.add(name)
end
module_function :_ensure_page

def _create_front_scene_all_cabinets(model, view, cabs)
  bb = _combined_bounds(cabs)

  front = _avg_axis(cabs, :yaxis)   # cabinet face normal (assumes +Y is cabinet front)
  up    = Geom::Vector3d.new(0,0,1)

  # Eye positioned in front of cabinets along -front
  center = bb.center
  dist = [bb.width, bb.depth, bb.height].max * 3.0 + 1.0
  eye = center.offset(front.reverse, dist)

  _set_parallel_camera_and_zoom(view, eye: eye, target: center, up: up, zoom_entities: cabs)

  page = _ensure_page("ALL - ELEV FRONT")
  page.use_camera = true if page.respond_to?(:use_camera=)
  # Don't force section plane state here
end
module_function :_create_front_scene_all_cabinets

def _type_signature(params)
  # Normalize keys (params are symbolize_names: true in read_cabinet_attributes)
  ct = (params[:cabinet_type] || params[:type] || params["cabinet_type"] || "CAB").to_s
  w  = (params[:width_in]  || params[:width]  || params["width_in"]  || params["width"]  || 0).to_f.round(3)
  h  = (params[:height_in] || params[:height] || params["height_in"] || params["height"] || 0).to_f.round(3)
  d  = (params[:depth_in]  || params[:depth]  || params["depth_in"]  || params["depth"]  || 0).to_f.round(3)

  doors = (params[:door_count] || params["door_count"] || params[:doors] || params["doors"] || "").to_s

  drawer_count = (params[:drawer_count] || params["drawer_count"] || params[:drawers] || params["drawers"] || 0).to_i

  dfh = params[:drawer_front_heights_in] || params["drawer_front_heights_in"] || params[:drawer_front_heights] || params["drawer_front_heights"] || []
  dfh = Array(dfh).map { |x| x.to_f.round(3) }

  "#{ct}|W#{w}|H#{h}|D#{d}|DOORS#{doors}|DRW#{drawer_count}|DFH[#{dfh.join(",")}]"
end
module_function :_type_signature

def _with_only_visible(groups_all, groups_visible)
  prev = {}
  groups_all.each { |g| prev[g] = g.hidden? }
  groups_all.each { |g| g.hidden = true }
  groups_visible.each { |g| g.hidden = false }
  yield
ensure
  prev.each { |g, was_hidden| g.hidden = was_hidden if g.valid? }
end
module_function :_with_only_visible

def _create_section_plane(entities, bb, normal_vec)
  n = normal_vec.clone
  n.length = 1.0 if n.length.to_f != 0.0
  p = bb.center
  entities.add_section_plane([p, n])
end
module_function :_create_section_plane


# -------------------------------------------------------------------------
# Section plane activation per scene (ensures the correct cut is active when a scene is activated)
# -------------------------------------------------------------------------
SECTION_SCENE_DICT = "SKServices_EuroCabinetGenerator_SceneMeta" unless const_defined?(:SECTION_SCENE_DICT)

class SectionScenePagesObserver < Sketchup::PagesObserver
  def onPageActivated(pages, page)
    model = pages.model
    return unless model && page

    pid = page.get_attribute(SECTION_SCENE_DICT, "active_section_plane_pid")
    if pid
      sp = nil
      begin
        model.entities.grep(Sketchup::SectionPlane) do |candidate|
          if candidate.respond_to?(:persistent_id) && candidate.persistent_id == pid
            sp = candidate
            break
          end
        end
      rescue
        sp = nil
      end
      begin
        model.active_section_plane = sp if sp && model.respond_to?(:active_section_plane=)
      rescue
      end
    else
      begin
        model.active_section_plane = nil if model.respond_to?(:active_section_plane=)
      rescue
      end
    end
  end
end

def _install_section_scene_observer(model)
  return unless model && model.respond_to?(:pages)

  # Observers exist only for the current SketchUp process. Do not persist an
  # "installed" flag in the model, because it survives save/reopen while the
  # Ruby observer does not. Retaining the observer also prevents GC removal.
  @section_scene_page_observers ||= {}
  key = model.object_id
  existing = @section_scene_page_observers[key]
  return if existing && existing[:model].equal?(model)

  begin
    observer = SectionScenePagesObserver.new
    model.pages.add_observer(observer)
    @section_scene_page_observers[key] = { model: model, observer: observer }
  rescue StandardError => e
    warn("#{PLUGIN_NAME}: failed to install section-scene observer: #{e.class}: #{e.message}")
  end
end
module_function :_install_section_scene_observer

def _create_right_section_scenes_by_type(model, view, cabs)
  ents = model.active_entities
  by_type = {}

  cabs.each do |g|
    params = read_cabinet_attributes(g)
    next unless params.is_a?(Hash)
    sig = _type_signature(params)
    (by_type[sig] ||= []) << g
  end
  return if by_type.empty?

  right = _avg_axis(cabs, :xaxis) # local +X as right
  up    = Geom::Vector3d.new(0,0,1)

  by_type.keys.sort.each do |sig|
    type_cabs = by_type[sig]
    bb = _combined_bounds(type_cabs)

    _with_only_visible(cabs, type_cabs) do
      # Add a section plane for this type (right section)
      sp = _create_section_plane(ents, bb, right)

      # Activate so the view shows the cut
      model.active_section_plane = sp if model.respond_to?(:active_section_plane=)

      center = bb.center
      dist = [bb.width, bb.depth, bb.height].max * 3.0 + 1.0
      eye = center.offset(right.reverse, dist) # view direction matches section normal (right)
      _set_parallel_camera_and_zoom(view, eye: eye, target: center, up: up, zoom_entities: type_cabs)

      page_name = "#{sig} - SECTION RIGHT"
      page = _ensure_page(page_name)
      pid = (sp.respond_to?(:persistent_id) ? sp.persistent_id : nil) rescue nil
      page.set_attribute(SECTION_SCENE_DICT, "active_section_plane_pid", pid) if pid
      page.use_camera = true if page.respond_to?(:use_camera=)
      page.use_section_planes = true if page.respond_to?(:use_section_planes=)
    end
  end
end
module_function :_create_right_section_scenes_by_type

    def self.install_menu
      @__menu_installed__ ||= false
      return if @__menu_installed__

      ext_menu = UI.menu("Extensions")

      begin
        sub = ext_menu.add_submenu(PLUGIN_NAME)
        sub.add_item("New / Place Cabinet…") { show_dialog(edit_selected: false) }
        sub.add_item("Edit Selected Cabinet…") { show_dialog(edit_selected: true) }
        sub.add_item("Double-Click Cabinet Edit Tool") { Sketchup.active_model.select_tool(SkilledServices::Editing::CabinetEditTool.new) }
        sub.add_item("Create Shop Drawing Scenes (Right Sections + Front All)…") { create_shop_scenes_sections_and_front_all }

        reports = sub.add_submenu("Reports")
        reports.add_item("Cabinet Report…") { create_professional_report(:cabinet) }
        reports.add_item("Bill of Materials…") { create_professional_report(:bill_of_materials) }
        reports.add_item("Material Report…") { create_professional_report(:material) }
        reports.add_item("Hardware Report…") { create_professional_report(:hardware) }
        reports.add_item("Door Report…") { create_professional_report(:door) }
        reports.add_item("Drawer Report…") { create_professional_report(:drawer) }
        reports.add_item("Room Report…") { create_professional_report(:room) }
        sub.add_separator
        sub.add_item("Global Settings…") { show_global_settings_dialog }
        sub.add_item("Add Countertops to Selection…") { add_countertops_to_selection }
        sub.add_separator
        sub.add_item("Check for Updates…") { SkilledServices::UpdateChecker.check(manual: true) }
      rescue
        # Fallback for unusual menu environments
        ext_menu.add_item(PLUGIN_NAME) { show_dialog(edit_selected: false) }
      end
      @__menu_installed__ = true
    end


    unless file_loaded?(__FILE__)
      if SkilledServices::EuroCabinetGenerator.respond_to?(:install_menu)
        SkilledServices::EuroCabinetGenerator.install_menu
      end
      SkilledServices::UpdateChecker.schedule_auto_check
      file_loaded(__FILE__)
    end
  end

end

# ----------------------------
# Safety aliases (in case of load-order / scope issues)
# Ensures the dialog can always be opened via:
#   SkilledServices::EuroCabinetGenerator.show_dialog
#   SkilledServices.show_dialog
# ----------------------------
module SkilledServices
  module EuroCabinetGenerator
    
    # -------------------------------------------------------------------------
    # Robust dialog/menu bindings
    # -------------------------------------------------------------------------
    begin
      sc = class << self; self; end

      # Preserve any earlier implementation (if present) and route calls through it.
      if sc.method_defined?(:show_dialog) && !sc.method_defined?(:_show_dialog_impl)
        sc.alias_method :_show_dialog_impl, :show_dialog
      end

      # Always provide a callable entrypoint for the Extensions menu.
      def self.show_dialog(edit_selected: false)
        if respond_to?(:_show_dialog_impl)
          _show_dialog_impl(edit_selected: edit_selected)
        else
          UI.messagebox("ForgeCase loaded, but the dialog implementation was not found. Please reinstall the plugin file.")
          nil
        end
      end

      # Ensure menu exists even if a previous edit broke menu wiring.
    rescue
      # no-op
    end

  end


  class << self
    unless respond_to?(:show_dialog)
      def show_dialog(*args, **kwargs)
        if defined?(SkilledServices::EuroCabinetGenerator) && SkilledServices::EuroCabinetGenerator.respond_to?(:show_dialog)
          SkilledServices::EuroCabinetGenerator.show_dialog(*args, **kwargs)
        else
          UI.messagebox("ForgeCase is not loaded.")
        end
      end
    end
  end
end
