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
  version "0.5.0"

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
      sha256 "cf21c450722212403cfbcfd4cde7f0c488440e6298f67fdb7b3c4c362c0bfd57"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-apple-darwin.tar.gz"
      sha256 "99b22c997cb79a4416c469a572666be78e62626492b89dd8c2ed47568238c7f4"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-unknown-linux-musl.tar.gz"
      sha256 "4a350d3ddbff622a4b548eea427017a96bd8f76459e36f2e648815e01c0199cb"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-unknown-linux-musl.tar.gz"
      sha256 "f01ae78ec95739ba8a830b5ba7554e6877afb8694b123cde47c1554138a854ca"
    end
  end

  def install
    bin.install "reachpad"
  end

  test do
    assert_match "reachpad", shell_output("#{bin}/reachpad --help")
  end
end
