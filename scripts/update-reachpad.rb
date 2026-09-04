#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "digest"
require "net/http"
require "tempfile"
require "uri"

RELEASE_API = "https://api.github.com/repos/Reachpad/reachpad-cli/releases/latest"
FORMULA_PATH = File.expand_path("../Formula/reachpad.rb", __dir__)
MAX_RESPONSE_BYTES = 5 * 1024 * 1024
FETCH_HOSTS = %w[api.github.com github.com release-assets.githubusercontent.com].freeze
CANONICAL_VERSION_RE = /\A(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))+\z/
PLATFORM_ASSETS = {
  macos_arm64: "reachpad-aarch64-apple-darwin.tar.gz",
  macos_x86_64: "reachpad-x86_64-apple-darwin.tar.gz",
  linux_arm64: "reachpad-aarch64-unknown-linux-musl.tar.gz",
  linux_x86_64: "reachpad-x86_64-unknown-linux-musl.tar.gz",
}.freeze

class FetchError < RuntimeError; end

def validated_uri(url)
  uri = URI.parse(url)
  raise "refusing non-HTTPS fetch URL" unless uri.is_a?(URI::HTTPS)
  raise "refusing credential-bearing fetch URL" if uri.userinfo
  raise "refusing fetch URL without a host" unless uri.host
  raise "refusing fetch URL on a non-standard port" unless uri.port == 443
  raise "refusing fetch URL from an unexpected host" unless FETCH_HOSTS.include?(uri.host)
  raise "refusing fetch URL with a fragment" if uri.fragment

  uri
rescue URI::InvalidURIError
  raise "refusing invalid fetch URL"
end

def redirect_target(current_url, location)
  current = validated_uri(current_url)
  target = validated_uri(URI.join(current, location).to_s)
  allowed = target.host == current.host ||
    (current.host == "github.com" && target.host == "release-assets.githubusercontent.com")
  raise "refusing redirect to an unexpected origin" unless allowed

  target
rescue URI::InvalidURIError
  raise "refusing invalid redirect location"
end

def url_host(url)
  URI.parse(url).host || "remote host"
rescue URI::InvalidURIError
  "remote host"
end

def sanitize_network_errors(uri)
  yield
rescue FetchError
  raise
rescue StandardError => error
  raise FetchError, "GET #{uri.host} failed (#{error.class})", cause: nil
end

def fetch(url, redirects = 5)
  raise "too many redirects while fetching #{url_host(url)}" if redirects.negative?

  uri = validated_uri(url)

  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github+json"
  request["User-Agent"] = "Reachpad-homebrew-tap"
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 10
  http.read_timeout = 30
  http.write_timeout = 30 if http.respond_to?(:write_timeout=)
  body = nil
  response = sanitize_network_errors(uri) do
    http.start do |connection|
      connection.request(request) do |incoming|
        body = read_bounded_body(incoming, url) if incoming.is_a?(Net::HTTPSuccess)
      end
    end
  end

  case response
  when Net::HTTPSuccess
    body || ""
  when Net::HTTPRedirection
    location = response["location"]
    raise "GET #{url_host(url)} redirected without a location" unless location

    fetch(redirect_target(uri.to_s, location).to_s, redirects - 1)
  else
    raise "GET #{url_host(url)} returned HTTP #{response.code}"
  end
end

def read_bounded_body(response, url, limit = MAX_RESPONSE_BYTES)
  body = +"".b
  response.read_body do |chunk|
    if chunk.bytesize > limit - body.bytesize
      raise FetchError, "GET #{url_host(url)} exceeded #{limit} bytes"
    end

    body << chunk
  end
  body
end

def checksum_map(contents)
  checksums = {}
  contents.each_line.with_index(1) do |line, line_number|
    fields = line.split
    unless fields.length == 2 && fields[0].match?(/\A[0-9a-f]{64}\z/)
      raise "invalid checksum line #{line_number}"
    end

    checksum, filename = fields
    raise "duplicate checksum filename on line #{line_number}" if checksums.key?(filename)

    checksums[filename] = checksum
  end
  checksums
end

def replace_once(contents, pattern)
  count = contents.scan(pattern).length
  raise "expected one formula match for #{pattern.inspect}, found #{count}" unless count == 1

  contents.sub(pattern) { yield(Regexp.last_match) }
end

# Each checksum is anchored to the release filename on the url line directly
# above it, so a sha can never be written under the wrong platform no matter
# how the formula's blocks are reordered.
def sha_after(filename)
  /(#{Regexp.escape(filename)}"\n\s*sha256 ")[0-9a-f]{64}(")/
end

def expected_asset_url(tag, filename)
  "https://github.com/Reachpad/reachpad-cli/releases/download/#{tag}/#{filename}"
end

def required_release_assets(release, tag)
  assets = release["assets"]
  unless assets.is_a?(Array) && assets.all? { |asset| asset.is_a?(Hash) }
    raise "release API returned an invalid assets list"
  end

  required = ["SHA256SUMS", *PLATFORM_ASSETS.values]
  required.to_h do |filename|
    matches = assets.select { |asset| asset["name"] == filename }
    raise "release must contain exactly one #{filename} asset" unless matches.length == 1

    asset = matches.first
    unless asset["browser_download_url"] == expected_asset_url(tag, filename)
      raise "#{filename} asset URL does not belong to the selected release"
    end
    unless asset["digest"].is_a?(String) && asset["digest"].match?(/\Asha256:[0-9a-f]{64}\z/)
      raise "#{filename} asset has no valid GitHub SHA-256 digest"
    end
    unless asset["size"].is_a?(Integer) && asset["size"].positive?
      raise "#{filename} asset has no valid size"
    end

    [filename, asset]
  end
end

def verified_checksums(contents, assets)
  checksum_asset = assets.fetch("SHA256SUMS")
  unless contents.bytesize == checksum_asset.fetch("size")
    raise "SHA256SUMS size does not match GitHub release metadata"
  end
  digest = checksum_asset.fetch("digest").delete_prefix("sha256:")
  unless Digest::SHA256.hexdigest(contents) == digest
    raise "SHA256SUMS digest does not match GitHub release metadata"
  end

  checksums = checksum_map(contents)
  PLATFORM_ASSETS.each_value do |filename|
    expected = assets.fetch(filename).fetch("digest").delete_prefix("sha256:")
    raise "SHA256SUMS does not match GitHub's digest for #{filename}" unless checksums[filename] == expected
  end
  checksums
end

def formula_version(contents)
  matches = contents.scan(/^  version "([^"]+)"$/).flatten
  raise "expected one formula version, found #{matches.length}" unless matches.length == 1
  raise "formula version is not canonical dotted syntax" unless matches.first.match?(CANONICAL_VERSION_RE)

  matches.first
end

def compare_versions(left, right)
  left_parts = left.split(".").map { |part| Integer(part, 10) }
  right_parts = right.split(".").map { |part| Integer(part, 10) }
  width = [left_parts.length, right_parts.length].max
  (left_parts + [0] * width).first(width) <=> (right_parts + [0] * width).first(width)
end

def update_formula(contents, version, checksums)
  raise "release version is not canonical dotted syntax" unless version.match?(CANONICAL_VERSION_RE)

  current = formula_version(contents)
  comparison = compare_versions(version, current)
  raise "refusing to downgrade the formula from #{current} to #{version}" if comparison.negative?

  updated = replace_once(contents, /^  version "[^"]+"$/) { %(  version "#{version}") }
  PLATFORM_ASSETS.each_value do |filename|
    updated = replace_once(updated, sha_after(filename)) do |found|
      "#{found[1]}#{checksums.fetch(filename)}#{found[2]}"
    end
  end
  if comparison.zero? && updated != contents
    raise "release assets changed for existing formula version #{current}, or an equivalent spelling was used"
  end

  updated
end

def atomic_write(path, contents)
  stat = File.stat(path)
  temporary = Tempfile.new([".#{File.basename(path)}.", ".tmp"], File.dirname(path))
  begin
    temporary.binmode
    temporary.write(contents)
    temporary.flush
    temporary.fsync
    temporary.chmod(stat.mode & 0o777)
    temporary.close
    File.rename(temporary.path, path)
    begin
      File.open(File.dirname(path), File::RDONLY) { |directory| directory.fsync }
    rescue SystemCallError
      # Some filesystems do not support directory fsync; the same-directory
      # rename is still atomic there.
    end
  ensure
    temporary.close!
  end
end

def main(argv)
  begin
    release = JSON.parse(fetch(RELEASE_API))
  rescue JSON::ParserError
    raise "release API returned invalid JSON"
  end
  raise "release API returned a non-object" unless release.is_a?(Hash)
  raise "latest release must not be a draft or prerelease" unless release["draft"] == false && release["prerelease"] == false

  tag = release.fetch("tag_name")
  match = tag.is_a?(String) && tag.match(/\Acli-v(.+)\z/)
  raise "unexpected Reachpad release tag" unless match

  version = match[1]
  raise "release version is not canonical dotted syntax" unless version.match?(CANONICAL_VERSION_RE)
  assets = required_release_assets(release, tag)
  checksum_url = assets.fetch("SHA256SUMS").fetch("browser_download_url")
  checksums = verified_checksums(fetch(checksum_url), assets)

  original = File.read(FORMULA_PATH)
  updated = update_formula(original, version, checksums)

  if argv == ["--check"]
    abort "Formula/reachpad.rb does not match #{tag}; run scripts/update-reachpad.rb" unless original == updated

    puts "Formula/reachpad.rb matches #{tag}"
  elsif argv.empty?
    atomic_write(FORMULA_PATH, updated) unless original == updated
    puts original == updated ? "Formula/reachpad.rb already matches #{tag}" : "Updated Formula/reachpad.rb to #{tag}"
  else
    abort "usage: scripts/update-reachpad.rb [--check]"
  end
end

main(ARGV) if $PROGRAM_NAME == __FILE__
