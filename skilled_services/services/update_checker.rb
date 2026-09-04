# frozen_string_literal: true

require "json"
require "uri"

module SkilledServices
  module UpdateChecker
    RELEASE_API_URL = "https://api.github.com/repos/ericrochat99-sys/CabinetGenerator2/releases/latest".freeze
    RELEASE_PATH_PREFIX = "/ericrochat99-sys/CabinetGenerator2/releases/".freeze
    DOWNLOAD_PATH_PREFIX = "/ericrochat99-sys/CabinetGenerator2/releases/download/".freeze
    PREFERENCES_KEY = "SkilledServices_UpdateChecker".freeze
    LAST_CHECK_KEY = "last_checked_at".freeze
    CHECK_INTERVAL = 86_400
    STARTUP_DELAY = 5.0
    class NoReleaseError < StandardError; end

    module_function

    def schedule_auto_check
      return if @auto_check_scheduled

      @auto_check_scheduled = true
      ::UI.start_timer(STARTUP_DELAY, false) { check(manual: false) }
    end

    def check(manual: true)
      return if @checking
      return unless manual || check_due?

      @checking = true
      latest_release do |release, error|
        begin
          raise error if error

          process_release(release, manual)
        rescue NoReleaseError
          ::UI.messagebox("No ForgeCase releases have been published yet.") if manual
        rescue StandardError => callback_error
          if manual
            ::UI.messagebox("Unable to check for updates.\n\n#{callback_error.message}")
          end
        ensure
          finish_check(manual)
        end
      end
    rescue StandardError => error
      if manual
        ::UI.messagebox("Unable to check for updates.\n\n#{error.message}")
      end
      finish_check(manual)
    end

    def process_release(release, manual)
      latest_version = parse_version(release.fetch("tag_name"))
      installed_version = parse_version(SkilledServices::VERSION)

      if (latest_version <=> installed_version) == 1
        show_update_available(release)
      elsif manual
        ::UI.messagebox("ForgeCase is up to date (version #{SkilledServices::VERSION}).")
      end
    end

    def finish_check(manual)
      mark_checked unless manual
      @checking = false
      @request = nil
    end

    def latest_release
      request = Sketchup::Http::Request.new(RELEASE_API_URL, Sketchup::Http::GET)
      request.headers = {
        "Accept" => "application/vnd.github+json",
        "User-Agent" => "ForgeCase-SketchUp/#{SkilledServices::VERSION}",
        "X-GitHub-Api-Version" => "2022-11-28"
      }

      # Retain the request until its asynchronous callback runs. SketchUp can
      # otherwise garbage-collect it and silently cancel the request.
      @request = request
      started = request.start do |_completed_request, response|
        begin
          status = response.status_code.to_i
          raise NoReleaseError if status == 404
          raise "GitHub returned HTTP #{status}" unless status.between?(200, 299)

          yield JSON.parse(response.body), nil
        rescue JSON::ParserError
          yield nil, RuntimeError.new("GitHub returned an invalid release response")
        rescue StandardError => error
          yield nil, error
        end
      end

      raise "SketchUp could not start the update request" unless started
    end

    def parse_version(value)
      match = value.to_s.strip.match(/\Av?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?\z/)
      raise "Invalid release version: #{value}" unless match

      match.captures.map(&:to_i)
    end

    def show_update_available(release)
      tag = release.fetch("tag_name").to_s.sub(/\Av/, "")
      asset = release_asset(release, tag)
      message = <<~MESSAGE
        ForgeCase #{tag} is available.

        Installed version: #{SkilledServices::VERSION}

        Download and install this update now?
      MESSAGE

      result = ::UI.messagebox(message, MB_YESNO)
      download_and_install(asset, tag) if result == IDYES
    end

    def release_asset(release, tag)
      expected_name = "forgecase-#{tag}.rbz"
      assets = release.fetch("assets")
      asset = assets.find { |candidate| candidate["name"].to_s == expected_name }
      raise "Release does not contain #{expected_name}" unless asset

      url = trusted_download_url(asset.fetch("browser_download_url"), tag, expected_name)
      { "name" => expected_name, "url" => url, "size" => asset["size"].to_i }
    end

    def download_and_install(asset, tag)
      raise "This SketchUp version cannot install extension archives" unless Sketchup.respond_to?(:install_from_archive)

      ::Sketchup.status_text = "ForgeCase: downloading version #{tag}..."
      request = Sketchup::Http::Request.new(asset.fetch("url"), Sketchup::Http::GET)
      request.headers = {
        "Accept" => "application/octet-stream",
        "User-Agent" => "ForgeCase-SketchUp/#{SkilledServices::VERSION}"
      }
      @download_request = request
      started = request.start do |_completed_request, response|
        archive_path = nil
        begin
          status = response.status_code.to_i
          raise "GitHub returned HTTP #{status} while downloading the update" unless status.between?(200, 299)

          data = response.body
          validate_archive_download!(data, asset)
          archive_path = File.join(Sketchup.temp_dir, asset.fetch("name"))
          File.binwrite(archive_path, data)

          ::Sketchup.status_text = "ForgeCase: installing version #{tag}..."
          installed = Sketchup.install_from_archive(archive_path, false)
          raise "SketchUp could not install the downloaded update" unless installed

          reloaded = reload_installed_extension
          if reloaded
            ::UI.messagebox("ForgeCase #{tag} was installed and reloaded successfully.\n\nYou can continue working without restarting SketchUp.")
          else
            ::UI.messagebox("ForgeCase #{tag} was installed successfully.\n\nSketchUp could not fully reload the extension in this session, so restart SketchUp before using the updated tools.")
          end
        rescue StandardError => error
          ::UI.messagebox("Unable to install the ForgeCase update.\n\n#{error.message}")
        ensure
          File.delete(archive_path) if archive_path && File.file?(archive_path)
          @download_request = nil
          ::Sketchup.status_text = ""
        end
      end
      raise "SketchUp could not start the update download" unless started
    rescue StandardError => error
      @download_request = nil
      ::Sketchup.status_text = ""
      ::UI.messagebox("Unable to install the ForgeCase update.\n\n#{error.message}")
    end

    def validate_archive_download!(data, asset)
      raise "The downloaded update was empty" unless data.is_a?(String) && data.bytesize.positive?
      raise "The downloaded file is not a valid RBZ archive" unless data.byteslice(0, 2) == "PK"

      expected_size = asset.fetch("size").to_i
      if expected_size.positive? && data.bytesize != expected_size
        raise "The downloaded update was incomplete"
      end
    end

    def reload_installed_extension
      plugin_root = Sketchup.find_support_file("skilled_services", "Plugins")
      main_file = plugin_root && File.join(plugin_root, "main.rb")
      version_file = plugin_root && File.join(plugin_root, "version.rb")
      return false unless main_file && version_file && File.file?(main_file) && File.file?(version_file)

      generator = SkilledServices::EuroCabinetGenerator if defined?(SkilledServices::EuroCabinetGenerator)
      if generator
        dialog = generator.instance_variable_get(:@dialog)
        dialog.close if dialog && dialog.respond_to?(:close)
        generator.instance_variable_set(:@dialog, nil)
      end

      SkilledServices.send(:remove_const, :VERSION) if SkilledServices.const_defined?(:VERSION, false)
      Sketchup.load(version_file)
      Sketchup.load(main_file)
      true
    rescue StandardError => error
      warn("ForgeCase hot reload failed: #{error.class}: #{error.message}")
      false
    end

    def trusted_release_url(value)
      uri = URI.parse(value.to_s)
      valid = uri.scheme == "https" && uri.host == "github.com" && uri.path.start_with?(RELEASE_PATH_PREFIX)
      raise "GitHub returned an untrusted release URL" unless valid

      uri.to_s
    end

    def trusted_download_url(value, tag, filename)
      uri = URI.parse(value.to_s)
      expected_suffix = "/v#{tag}/#{filename}"
      valid = uri.scheme == "https" && uri.host == "github.com" &&
        uri.path.start_with?(DOWNLOAD_PATH_PREFIX) && uri.path.end_with?(expected_suffix)
      raise "GitHub returned an untrusted update download URL" unless valid

      uri.to_s
    end

    def check_due?
      last_checked = Sketchup.read_default(PREFERENCES_KEY, LAST_CHECK_KEY, 0).to_i
      Time.now.to_i - last_checked >= CHECK_INTERVAL
    rescue StandardError
      true
    end

    def mark_checked
      Sketchup.write_default(PREFERENCES_KEY, LAST_CHECK_KEY, Time.now.to_i)
    rescue StandardError
      nil
    end
  end
end
