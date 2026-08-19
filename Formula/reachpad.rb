# The Reachpad CLI is a FORMULA, not a cask, and the difference is not
# cosmetic. `brew install --cask` stamps com.apple.quarantine on everything it
# stages, so the first run of a cask-installed reachpad hit macOS Gatekeeper:
# "Apple could not verify reachpad is free of malware". Our release binaries
# are ad-hoc signed by the linker, not Developer ID signed and notarized, so
# that gate can never clear. Formulae are not quarantined, so the same
# unsigned binary installed this way just runs.
#
# The second reason is that Homebrew Cask is macOS-only: the cask's Linux
# branch could never install anything, however carefully we maintained it.
class Reachpad < Formula
  desc "Run coding agents in durable cloud workspaces"
  homepage "https://reachpad.dev/docs/cli"

  # `brew audit` calls this version redundant, because it can scan 0.2.0 out of
  # the cli-v0.2.0 URLs. It is kept deliberately: it is the ONE place the
  # updater rewrites the version, and it keeps the formula valid on platforms
  # that have no url — an Intel Mac then fails on the arm64 requirement below
  # with a sentence about architecture instead of a broken-formula error.
  version "0.4.1"

  livecheck do
    url :stable
    regex(/^cli-v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest do |json, regex|
      json["tag_name"]&.match(regex)&.[](1)
    end
  end

  # The url/sha256 sit directly in `on_macos` instead of in a nested `on_arm`,
  # and `brew audit` says so ("on_macos cannot include url"). That is deliberate
  # while there is no Intel macOS binary: nesting them leaves an Intel Mac with
  # a formula that has no url at all, which fails as "formula requires at least
  # a URL", whereas this shape lets the arm64 requirement reject Intel with a
  # sentence about architecture. Nest it under `on_arm` — and the audit note
  # goes away — the day the release workflow publishes x86_64-apple-darwin.
  on_macos do
    depends_on arch: :arm64

    url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-apple-darwin.tar.gz"
    sha256 "d90b2aa6a87f3e9e57ddd199bcd2307b52ee091941b8bb468e29dfdedb9edfda"
  end

  on_linux do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-unknown-linux-musl.tar.gz"
      sha256 "2f80e2d12b630da49798a821ccf03024feedd48abd9510a2d66b35d858101cc6"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-unknown-linux-musl.tar.gz"
      sha256 "576fcf26e6e7164386627d02c7edd24517ff556042cc38e1178693692c8a02cc"
    end
  end

  def install
    bin.install "reachpad"
  end

  test do
    assert_match "reachpad", shell_output("#{bin}/reachpad --help")
  end
end
