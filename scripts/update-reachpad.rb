#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

RELEASE_API = "https://api.github.com/repos/Reachpad/reachpad-cli/releases/latest"
CASK_PATH = File.expand_path("../Casks/reachpad.rb", __dir__)

def fetch(url, redirects = 5)
  raise "too many redirects while fetching #{url}" if redirects.negative?

  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github+json"
  request["User-Agent"] = "Reachpad-homebrew-tap"
  response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
    http.request(request)
  end

  case response
  when Net::HTTPSuccess
    response.body
  when Net::HTTPRedirection
    fetch(URI.join(url, response.fetch("location")).to_s, redirects - 1)
  else
    raise "GET #{url} returned #{response.code}"
  end
end

def checksum_map(contents)
  contents.each_line.to_h do |line|
    checksum, filename = line.split
    raise "invalid checksum line: #{line.inspect}" unless checksum&.match?(/\A[0-9a-f]{64}\z/) && filename

    [filename, checksum]
  end
end

def replace_once(contents, pattern)
  count = contents.scan(pattern).length
  raise "expected one cask match for #{pattern.inspect}, found #{count}" unless count == 1

  contents.sub(pattern) { yield(Regexp.last_match) }
end

release = JSON.parse(fetch(RELEASE_API))
tag = release.fetch("tag_name")
match = tag.match(/\Acli-v(\d+(?:\.\d+)+)\z/)
raise "unexpected Reachpad release tag #{tag.inspect}" unless match

version = match[1]
checksum_asset = release.fetch("assets").find { |asset| asset["name"] == "SHA256SUMS" }
raise "#{tag} has no SHA256SUMS asset" unless checksum_asset

checksums = checksum_map(fetch(checksum_asset.fetch("browser_download_url")))
required = {
  macos_arm64: "reachpad-aarch64-apple-darwin.tar.gz",
  linux_arm64: "reachpad-aarch64-unknown-linux-musl.tar.gz",
  linux_x86_64: "reachpad-x86_64-unknown-linux-musl.tar.gz",
}
required.each_value do |filename|
  raise "#{tag} SHA256SUMS has no #{filename}" unless checksums.key?(filename)
end

original = File.read(CASK_PATH)
updated = replace_once(original, /^  version "[^"]+"$/) { %(  version "#{version}") }
updated = replace_once(updated, /(on_macos do\n    sha256 ")[0-9a-f]{64}(")/) do |found|
  "#{found[1]}#{checksums.fetch(required[:macos_arm64])}#{found[2]}"
end
updated = replace_once(updated, /(sha256 arm64_linux:\s+")[0-9a-f]{64}(")/) do |found|
  "#{found[1]}#{checksums.fetch(required[:linux_arm64])}#{found[2]}"
end
updated = replace_once(updated, /(x86_64_linux: ")[0-9a-f]{64}(")/) do |found|
  "#{found[1]}#{checksums.fetch(required[:linux_x86_64])}#{found[2]}"
end

if ARGV == ["--check"]
  abort "Casks/reachpad.rb does not match #{tag}; run scripts/update-reachpad.rb" unless original == updated

  puts "Casks/reachpad.rb matches #{tag}"
elsif ARGV.empty?
  File.write(CASK_PATH, updated) unless original == updated
  puts original == updated ? "Casks/reachpad.rb already matches #{tag}" : "Updated Casks/reachpad.rb to #{tag}"
else
  abort "usage: scripts/update-reachpad.rb [--check]"
end
