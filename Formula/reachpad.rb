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
  version "0.4.5"

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
      sha256 "b74c911494a7ab46024bce08a0b724379295e9a7fe89a55a1b5c82bf7598afe7"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-apple-darwin.tar.gz"
      sha256 "d8011d69925991a6b5d759c2734da370c4565175b1f3f988e88be18754f1a916"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-unknown-linux-musl.tar.gz"
      sha256 "f7100e0b4e779fe3382a6fae3ddb8a1340b4119d6794187ddf0bbafe7676aeb9"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-unknown-linux-musl.tar.gz"
      sha256 "2d1981f4d13d88a39344d72e5baaf003b915fa1d335df99edf45a9315029f72b"
    end
  end

  def install
    bin.install "reachpad"
  end

  test do
    assert_match "reachpad", shell_output("#{bin}/reachpad --help")
  end
end
