# frozen_string_literal: true

module SkilledServices
  module Editing
    # Lightweight pick tool that opens a cabinet editor on double-click.
    class CabinetEditTool
      def activate
        ::UI.set_status_text("Double-click a generated cabinet to edit it.", SB_PROMPT)
      end

      def onLButtonDoubleClick(_flags, x, y, view)
        helper = view.pick_helper
        helper.do_pick(x, y)
        entity = helper.best_picked
        cabinet = cabinet_ancestor(entity)
        unless cabinet
          ::UI.beep
          return
        end
        Sketchup.active_model.selection.clear
        Sketchup.active_model.selection.add(cabinet)
        SkilledServices::EuroCabinetGenerator.show_dialog(edit_selected: true)
      end

      def getMenu(menu)
        menu.add_item("Exit Cabinet Edit Tool") { Sketchup.active_model.select_tool(nil) }
      end

      private

      def cabinet_ancestor(entity)
        current = entity
        20.times do
          return current if current.is_a?(Sketchup::Group) && current.get_attribute(
            SkilledServices::EuroCabinetGenerator::CABINET_ATTR_DICT,
            SkilledServices::EuroCabinetGenerator::CABINET_ATTR_PARAMS_JSON
          )
          current = current.respond_to?(:parent) ? current.parent : nil
          current = current.parent if current.is_a?(Sketchup::Entities) && current.respond_to?(:parent)
          break unless current
        end
        nil
      end
    end
  end
end
