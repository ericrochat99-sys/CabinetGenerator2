# frozen_string_literal: true

require "sketchup.rb"
require "extensions.rb"
require_relative "skilled_services/version"

module SkilledServices
  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new(
      "ForgeCase",
      File.join(__dir__, "skilled_services", "main")
    )
    extension.description = "Create configurable European-style cabinets, shop-drawing scenes, and cabinet reports."
    extension.version = VERSION
    extension.creator = "ForgeCase"
    extension.copyright = "Copyright #{Time.now.year} ForgeCase"

    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
