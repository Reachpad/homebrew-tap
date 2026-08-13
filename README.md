# Reachpad Homebrew tap

Install the Reachpad CLI on Apple Silicon macOS or x86_64/ARM64 Linux:

```sh
brew install --cask reachpad/tap/reachpad
reachpad
```

Homebrew installs the binary from the public
[Reachpad CLI release](https://github.com/Reachpad/reachpad-cli/releases) and
verifies the archive checksum declared in the cask. Run `brew upgrade
--cask reachpad` to install a newer release.

Intel macOS is not supported until Reachpad publishes an Intel macOS binary.
Without Homebrew, install from the product-owned endpoint:

```sh
curl -fsSL https://reachpad.dev/install | sh
```

The hourly workflow updates the cask from the latest `cli-v*` release and its
published `SHA256SUMS` file. Greentree verifies the updated cask before the
workflow publishes it.
