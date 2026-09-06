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
  version "0.5.2"

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
      sha256 "b71e33bb0d127a12d4e2df618c62acdf387897d51a3a88ba4241bffc9cacc82e"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-apple-darwin.tar.gz"
      sha256 "d0d195fcd1b964796a8c0c7ba6fea443dbd6f37f36e5fb902d09dc750cfe9c47"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-aarch64-unknown-linux-musl.tar.gz"
      sha256 "871dc75d4c1803cb80f4e0c512e3014047b441d46508cae5704007bd54fb7ca4"
    end
    on_intel do
      url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-x86_64-unknown-linux-musl.tar.gz"
      sha256 "4308dcf6ee900ac20e3ec02627e5960c2c9bfd5174c1b0c1a6e9c38fce6cf4cd"
    end
  end

  def install
    bin.install "reachpad"
  end

  test do
    assert_match "reachpad", shell_output("#{bin}/reachpad --help")
  end
end
