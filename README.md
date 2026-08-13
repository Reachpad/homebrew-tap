# Reachpad Homebrew tap

Install the Reachpad CLI on Apple Silicon macOS or x86_64/ARM64 Linux:

```sh
brew install reachpad/tap/reachpad
reachpad
```

Homebrew installs the binary from the public
[Reachpad CLI release](https://github.com/Reachpad/reachpad-cli/releases) and
verifies the archive checksum declared in the formula. Run `brew upgrade
reachpad` to install a newer release.

Intel macOS is not supported until Reachpad publishes an Intel macOS binary.
Without Homebrew, install from the product-owned endpoint:

```sh
curl -fsSL https://reachpad.dev/install | sh
```

The hourly workflow updates the formula from the latest `cli-v*` release and
its published `SHA256SUMS` file. Greentree verifies the updated formula before
the workflow publishes it.

## Upgrading from the cask

This tap shipped a cask (`brew install --cask reachpad/tap/reachpad`) until
2026-08-13. Homebrew quarantines everything a cask stages, so macOS refused to
run the binary with "Apple could not verify reachpad is free of malware" —
and Homebrew Cask is macOS-only, so the cask never worked on Linux at all. The
formula fixes both. If you installed the cask, switch over with:

```sh
brew uninstall --cask reachpad
brew install reachpad/tap/reachpad
```
