cask "reachpad" do
  arch arm: "aarch64", intel: "x86_64"
  os macos: "apple-darwin", linux: "unknown-linux-musl"

  version "0.1.1"

  on_macos do
    sha256 "adabc122ecd36d9c0b1b2d48b6888b059e963d73a57c3ef88d6171b1ac5766d2"

    depends_on arch: :arm64
  end
  on_linux do
    sha256 arm64_linux:  "ea1397e827c85fd4a7ce3301ae3640b8250c549a0fa76f6aba196c39de30b308",
           x86_64_linux: "1ca6e0280518ffa7d842500b2392e106b96d5b1ade6dabbb41fbad8c5f35d9e2"
  end

  url "https://github.com/Reachpad/reachpad-cli/releases/download/cli-v#{version}/reachpad-#{arch}-#{os}.tar.gz"
  name "Reachpad CLI"
  desc "Run coding agents in durable cloud workspaces"
  homepage "https://reachpad.dev/docs/cli"

  livecheck do
    url :url
    regex(/^cli-v?(\d+(?:\.\d+)+)$/i)
    strategy :github_latest do |json, regex|
      json["tag_name"]&.match(regex)&.[](1)
    end
  end

  binary "reachpad"
end
