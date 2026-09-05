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

  # `brew audit` calls this version redundant because it can scan the version
  # out of the URLs. It is kept deliberately: the updater rewrites it once so
  # all four interpolated platform URLs advance atomically and rollback checks
  # have one canonical version anchor.
  version "0.4.6"

  livecheck do
    url :stable
    regex(/^cli-v((?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))+)$/i)
    strategy :github_latest do |json, regex|
      json["tag_name"]&.match(regex)&.[](1)
    end
  end

  on_macos do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-apple-darwin.tar.gz"
      sha256 "ce424a7e363771e6d191a46b33efa336b1acaa87c58edeaf94bb2fc2b6062ad1"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-apple-darwin.tar.gz"
      sha256 "d95917869f3fe463771a273d23a2cb686897bfc906825c591d8c80765f061690"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-unknown-linux-musl.tar.gz"
      sha256 "294493cc67d37b58dcab91ce9e15c98828dd8a742259fb415fe4e77a4d519bde"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-unknown-linux-musl.tar.gz"
      sha256 "3fa3fcf75ea6e302fdf4b75129df6e085e06bd1e55e7d3c2007a844261d0f4d6"
    end
  end

  def install
    bin.install "reachpad"
  end

  test do
    assert_match "reachpad", shell_output("#{bin}/reachpad --help")
  end
end
