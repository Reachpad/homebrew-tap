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
  version "0.5.1"

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
      sha256 "345c80dda35eac170a5c71d75aac245423f508b87d777bf3a4bf6daf8abaf68e"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-apple-darwin.tar.gz"
      sha256 "1b50b77be56472ae2efd1f278a4c78a3c81f28352d420f619b401e0aa9a78709"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-unknown-linux-musl.tar.gz"
      sha256 "18688c1dcd181b8730c39d8ca6c62a0a5646695aabe723e88cd080e4c6e26b8a"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-unknown-linux-musl.tar.gz"
      sha256 "9f1287233e9d6db1e6c5fad15a53b5b21c0f3a4f348bc9f0bda8a7c42efd8a6a"
    end
  end

  def install
    bin.install "reachpad"
  end

  test do
    assert_match "reachpad", shell_output("#{bin}/reachpad --help")
  end
end
