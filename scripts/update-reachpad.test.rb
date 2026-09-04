# frozen_string_literal: true

require_relative "update-reachpad"
require "tmpdir"

CHECKSUM = "a" * 64

def assert_equal(expected, actual)
  raise "expected #{expected.inspect}, got #{actual.inspect}" unless expected == actual
end

def assert(condition, message)
  raise message unless condition
end

def assert_raises(pattern)
  yield
rescue RuntimeError => error
  raise "expected #{pattern.inspect}, got #{error.message.inspect}" unless pattern.match?(error.message)

  error
else
  raise "expected #{pattern.inspect} to be raised"
end

class ChunkedResponse
  def initialize(chunks)
    @chunks = chunks
  end

  def read_body
    @chunks.each { |chunk| yield chunk }
  end
end

assert_equal({ "reachpad.tar.gz" => CHECKSUM }, checksum_map("#{CHECKSUM}  reachpad.tar.gz\n"))

assert_raises(/duplicate checksum.*line 2/) do
  checksum_map("#{CHECKSUM}  reachpad.tar.gz\n#{'b' * 64}  reachpad.tar.gz\n")
end

assert_raises(/invalid checksum line 1/) do
  checksum_map("#{CHECKSUM}  reachpad.tar.gz unexpected\n")
end

assert_raises(/invalid checksum line 1/) do
  checksum_map("#{'A' * 64}  reachpad.tar.gz\n")
end

assert_raises(/refusing non-HTTPS/) do
  fetch("http://example.com/release")
end

assert_raises(/credential-bearing fetch URL/) do
  fetch("https://token@example.com/release")
end

assert_raises(/unexpected host/) do
  fetch("https://example.com/release")
end

redirect = redirect_target(
  "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v1.2.3/SHA256SUMS",
  "https://release-assets.githubusercontent.com/github-production-release-asset/1/asset?sig=secret",
)
assert_equal("release-assets.githubusercontent.com", redirect.host)
assert_raises(/unexpected origin/) do
  redirect_target(RELEASE_API, "https://github.com/Reachpad/reachpad-cli/releases/latest")
end

assert_equal(
  "abcde".b,
  read_bounded_body(ChunkedResponse.new(["ab", "cde"]), "https://example.com/release", 5),
)

assert_raises(/exceeded 5 bytes/) do
  read_bounded_body(
    ChunkedResponse.new(["ab", "cde", "f"]),
    "https://example.com/release",
    5,
  )
end

leak = assert_raises(/exceeded 5 bytes/) do
  read_bounded_body(
    ChunkedResponse.new(["abcdef"]),
    "https://release-assets.githubusercontent.com/asset?sig=secret-log-sentinel",
    5,
  )
end
assert(!leak.message.include?("secret-log-sentinel"), "bounded-read errors must strip URL queries")

provider_leak = assert_raises(/GET release-assets\.githubusercontent\.com failed \(RuntimeError\)/) do
  sanitize_network_errors(
    URI("https://release-assets.githubusercontent.com/asset?sig=provider-error-secret-sentinel"),
  ) do
    raise "provider-error-secret-sentinel"
  end
end
assert(!provider_leak.message.include?("secret-sentinel"), "network errors must strip provider messages")
assert_equal(nil, provider_leak.cause)

MAC_SHA = "1" * 64
MAC_INTEL_SHA = "2" * 64
ARM_SHA = "3" * 64
INTEL_SHA = "4" * 64
TAG = "cli-v1.2.3"
SUMS = <<~SUMS
  #{MAC_SHA}  #{PLATFORM_ASSETS.fetch(:macos_arm64)}
  #{MAC_INTEL_SHA}  #{PLATFORM_ASSETS.fetch(:macos_x86_64)}
  #{ARM_SHA}  #{PLATFORM_ASSETS.fetch(:linux_arm64)}
  #{INTEL_SHA}  #{PLATFORM_ASSETS.fetch(:linux_x86_64)}
SUMS

def release_asset(name, digest, size)
  {
    "name" => name,
    "browser_download_url" => expected_asset_url(TAG, name),
    "digest" => "sha256:#{digest}",
    "size" => size,
  }
end

assets_json = [
  release_asset("SHA256SUMS", Digest::SHA256.hexdigest(SUMS), SUMS.bytesize),
  release_asset(PLATFORM_ASSETS.fetch(:macos_arm64), MAC_SHA, 10),
  release_asset(PLATFORM_ASSETS.fetch(:macos_x86_64), MAC_INTEL_SHA, 11),
  release_asset(PLATFORM_ASSETS.fetch(:linux_arm64), ARM_SHA, 12),
  release_asset(PLATFORM_ASSETS.fetch(:linux_x86_64), INTEL_SHA, 13),
]
release = { "assets" => assets_json }
assets = required_release_assets(release, TAG)
assert_equal(
  {
    PLATFORM_ASSETS.fetch(:macos_arm64) => MAC_SHA,
    PLATFORM_ASSETS.fetch(:macos_x86_64) => MAC_INTEL_SHA,
    PLATFORM_ASSETS.fetch(:linux_arm64) => ARM_SHA,
    PLATFORM_ASSETS.fetch(:linux_x86_64) => INTEL_SHA,
  },
  verified_checksums(SUMS, assets).slice(*PLATFORM_ASSETS.values),
)

wrong_url = Marshal.load(Marshal.dump(release))
wrong_url["assets"].first["browser_download_url"] = expected_asset_url("cli-v9.9.9", "SHA256SUMS")
assert_raises(/does not belong to the selected release/) do
  required_release_assets(wrong_url, TAG)
end

duplicate = { "assets" => [*assets_json, assets_json.last.dup] }
assert_raises(/exactly one/) do
  required_release_assets(duplicate, TAG)
end

tampered_sums = SUMS.sub(ARM_SHA, INTEL_SHA)
tampered_assets_json = Marshal.load(Marshal.dump(assets_json))
tampered_assets_json.first["digest"] = "sha256:#{Digest::SHA256.hexdigest(tampered_sums)}"
tampered_assets_json.first["size"] = tampered_sums.bytesize
assert_raises(/GitHub's digest/) do
  verified_checksums(
    tampered_sums,
    required_release_assets({ "assets" => tampered_assets_json }, TAG),
  )
end

formula = File.read(FORMULA_PATH)
current_version = formula_version(formula)
next_version_parts = current_version.split(".").map { |part| Integer(part, 10) }
next_version_parts[-1] += 1
next_version = next_version_parts.join(".")
next_checksums = {
  PLATFORM_ASSETS.fetch(:macos_arm64) => MAC_SHA,
  PLATFORM_ASSETS.fetch(:macos_x86_64) => MAC_INTEL_SHA,
  PLATFORM_ASSETS.fetch(:linux_arm64) => ARM_SHA,
  PLATFORM_ASSETS.fetch(:linux_x86_64) => INTEL_SHA,
}
updated = update_formula(formula, next_version, next_checksums)
PLATFORM_ASSETS.each_value do |filename|
  expected = next_checksums.fetch(filename)
  assert(
    updated.match?(/#{Regexp.escape(filename)}"\n\s*sha256 "#{expected}"/),
    "#{filename} received the wrong platform checksum",
  )
end
assert_raises(/refusing to downgrade/) do
  update_formula(formula, "0.0.0", next_checksums)
end
assert_raises(/assets changed for existing formula version/) do
  update_formula(formula, formula_version(formula), next_checksums)
end
assert_raises(/existing formula version/) do
  # 0.4.5.0 and 0.4.5 compare equal numerically. A spelling change must not
  # bypass the same-version asset replay guard.
  update_formula(formula, "#{current_version}.0", next_checksums)
end
assert_raises(/not canonical/) do
  leading_zero_version = current_version.sub(/\A\d+/) { |part| "0#{part}" }
  update_formula(formula, leading_zero_version, next_checksums)
end

Dir.mktmpdir do |directory|
  path = File.join(directory, "reachpad.rb")
  File.write(path, "old")
  File.chmod(0o755, path)
  atomic_write(path, "new")
  assert_equal("new", File.read(path))
  assert_equal(0o755, File.stat(path).mode & 0o777)
  assert_equal(["reachpad.rb"], Dir.children(directory))
end

workflow = File.read(File.expand_path("../.github/workflows/update-reachpad.yml", __dir__))
assert(
  workflow.match?(%r{uses: actions/checkout@[0-9a-f]{40}\s+# v\d}),
  "checkout action must be pinned to an immutable commit",
)
assert(!workflow.match?(%r{uses: actions/checkout@v\d}), "checkout action uses a mutable major tag")
assert_equal(1, workflow.scan(/^\s+contents: write$/).length)
assert(workflow.include?("cancel-in-progress: false"), "scheduled runs may cancel an updater during writeback")
assert(workflow.include?("ruby --disable-gems scripts/update-reachpad.test.rb"), "workflow does not run updater tests")
assert(workflow.include?("git add -- Formula/reachpad.rb"), "workflow stages more than the generated formula")

puts "update-reachpad tests passed"
