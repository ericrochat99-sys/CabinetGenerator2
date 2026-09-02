# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "zlib"

ROOT = File.expand_path("..", __dir__)
require File.join(ROOT, "skilled_services", "version")

OUTPUT_DIR = File.join(ROOT, "dist")
OUTPUT_FILE = File.join(OUTPUT_DIR, "skilled-services-#{SkilledServices::VERSION}.rbz")
RUNTIME_PATHS = ["skilled_services.rb", "skilled_services"].freeze
REQUIRED_PATHS = [
  "skilled_services.rb",
  "skilled_services/main.rb",
  "skilled_services/version.rb",
  "skilled_services/services/update_checker.rb",
  "skilled_services/ui/dialog.rb",
  "skilled_services/ui/index.html",
  "skilled_services/ui/styles.css",
  "skilled_services/ui/app.js"
].freeze
EXCLUDED_NAMES = %w[.git .github .DS_Store node_modules tests tmp].freeze
SECRET_NAME_PATTERN = /(?:\.env|credentials|private[_-]?key|secret|token)/i

def runtime_files(staging_dir)
  Dir.chdir(staging_dir) do
    Dir.glob("**/*", File::FNM_DOTMATCH)
       .reject { |path| path == "." || File.directory?(path) }
       .sort
  end
end

def validate_runtime!(files)
  missing = REQUIRED_PATHS - files
  raise "Missing required runtime files: #{missing.join(', ')}" unless missing.empty?

  rejected = files.select do |path|
    parts = path.split("/")
    parts.any? { |part| EXCLUDED_NAMES.include?(part) } || File.basename(path).match?(SECRET_NAME_PATTERN)
  end
  raise "Development or secret-like files found: #{rejected.join(', ')}" unless rejected.empty?

  roots = files.map { |path| path.split("/").first }.uniq
  unexpected = roots - RUNTIME_PATHS
  raise "Unexpected archive root entries: #{unexpected.join(', ')}" unless unexpected.empty?
end

def raw_deflate(data)
  stream = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS)
  stream.deflate(data, Zlib::FINISH)
ensure
  stream&.close
end

def write_zip(output_file, staging_dir, files)
  central_entries = []
  offset = 0
  dos_time = 0
  dos_date = (1 << 5) | 1 # 1980-01-01
  utf8_flag = 0x0800

  File.open(output_file, "wb") do |archive|
    files.each do |relative_path|
      name = relative_path.encode(Encoding::UTF_8)
      data = File.binread(File.join(staging_dir, relative_path))
      compressed = raw_deflate(data)
      crc = Zlib.crc32(data)

      local_header = [
        0x04034b50, 20, utf8_flag, 8, dos_time, dos_date,
        crc, compressed.bytesize, data.bytesize, name.bytesize, 0
      ].pack("VvvvvvVVVvv")
      archive.write(local_header)
      archive.write(name)
      archive.write(compressed)

      central_entries << [name, crc, compressed.bytesize, data.bytesize, offset]
      offset += local_header.bytesize + name.bytesize + compressed.bytesize
    end

    central_offset = offset
    central_entries.each do |name, crc, compressed_size, size, local_offset|
      header = [
        0x02014b50, 20, 20, utf8_flag, 8, dos_time, dos_date,
        crc, compressed_size, size, name.bytesize, 0, 0, 0, 0, 0, local_offset
      ].pack("VvvvvvvVVVvvvvvVV")
      archive.write(header)
      archive.write(name)
      offset += header.bytesize + name.bytesize
    end

    central_size = offset - central_offset
    archive.write([
      0x06054b50, 0, 0, files.length, files.length,
      central_size, central_offset, 0
    ].pack("VvvvvVVv"))
  end
end

FileUtils.mkdir_p(OUTPUT_DIR)
Dir.mktmpdir("skilled-services-rbz-") do |staging_dir|
  FileUtils.cp(File.join(ROOT, "skilled_services.rb"), staging_dir)
  FileUtils.cp_r(File.join(ROOT, "skilled_services"), staging_dir)
  files = runtime_files(staging_dir)
  validate_runtime!(files)
  write_zip(OUTPUT_FILE, staging_dir, files)
end

puts OUTPUT_FILE
