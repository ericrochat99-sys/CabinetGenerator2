# frozen_string_literal: true

module SkilledServices
  module DialogTemplate
    TEMPLATE_ROOT = __dir__.freeze

    module_function

    def render(name, replacements = {})
      base_name = name.to_s
      validate_name!(base_name)

      html = read_asset("#{base_name}.html")
      css_name = base_name == "index" ? "styles.css" : "#{base_name}.css"
      script_name = base_name == "index" ? "app.js" : "#{base_name}.js"
      html.sub!("{{STYLES}}", read_asset(css_name))
      html.sub!("{{SCRIPT}}", read_asset(script_name))

      replacements.each do |key, value|
        html.gsub!("{{#{key}}}", value.to_s)
      end

      unresolved = html.scan(/\{\{[A-Z0-9_]+\}\}/).uniq
      raise ArgumentError, "Unresolved dialog placeholders: #{unresolved.join(', ')}" unless unresolved.empty?

      html
    end

    def read_asset(filename)
      File.read(File.join(TEMPLATE_ROOT, filename), encoding: "UTF-8")
    end
    private_class_method :read_asset

    def validate_name!(name)
      return if name.match?(/\A[a-z0-9_]+\z/)

      raise ArgumentError, "Invalid dialog template name"
    end
    private_class_method :validate_name!
  end
end
