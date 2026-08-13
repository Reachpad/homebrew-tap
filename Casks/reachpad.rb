cask "reachpad" do
  arch arm: "aarch64", intel: "x86_64"
  os macos: "apple-darwin", linux: "unknown-linux-musl"

  version "0.2.0"

  on_macos do
    sha256 "e020a36f6a35cca9f2385447d65976cd4014ced833d495f640711f706ac92c50"

    depends_on arch: :arm64
  end
  on_linux do
    sha256 arm64_linux:  "9733b5f2cb72b1c65a3ee37f69e65aca75841df4cc81876487c4b1b10abc8b1b",
           x86_64_linux: "20a3b7e89f4b150b4b768f61707b2272fdf61cdd88f7ce2866fec5e263a005fa"
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
