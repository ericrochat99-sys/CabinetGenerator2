# frozen_string_literal: true

require "json"
require "uri"

module SkilledServices
  module UpdateChecker
    RELEASE_API_URL = "https://api.github.com/repos/ericrochat99-sys/CabinetGenerator2/releases/latest".freeze
    RELEASE_PATH_PREFIX = "/ericrochat99-sys/CabinetGenerator2/releases/".freeze
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
          ::UI.messagebox("No Skilled Services releases have been published yet.") if manual
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
        ::UI.messagebox("Skilled Services is up to date (version #{SkilledServices::VERSION}).")
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
        "User-Agent" => "SkilledServices-SketchUp/#{SkilledServices::VERSION}",
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
      release_url = trusted_release_url(release.fetch("html_url"))
      message = <<~MESSAGE
        Skilled Services #{tag} is available.

        Installed version: #{SkilledServices::VERSION}

        Open the official GitHub release page to download the update?
      MESSAGE

      result = ::UI.messagebox(message, MB_YESNO)
      ::UI.openURL(release_url) if result == IDYES
    end

    def trusted_release_url(value)
      uri = URI.parse(value.to_s)
      valid = uri.scheme == "https" && uri.host == "github.com" && uri.path.start_with?(RELEASE_PATH_PREFIX)
      raise "GitHub returned an untrusted release URL" unless valid

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
