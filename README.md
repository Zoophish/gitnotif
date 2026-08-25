# GitNotif

A tiny, fast, native macOS menu bar app for GitHub notifications.

![requires macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)

## Features

- Live unread count in the menu bar
- Inbox grouped by repository
- Banner notifications for new items
- macOS Keychain token storage

## Install

### Homebrew

```sh
brew install --cask zoophish/tap/gitnotif
xattr -dr com.apple.quarantine /Applications/GitNotif.app
```

The `xattr` step is needed because the app is not notarized. macOS quarantines
it on download.

### From source

```sh
./build.sh
cp -R build/GitNotif.app /Applications/
open /Applications/GitNotif.app
```

## Setup

The GitHub notifications API only works with classic tokens and OAuth app
tokens. Fine-grained tokens are not supported. On first launch, click the bell
and either:

- **Use GitHub CLI token**, which reads `gh auth token`
- Paste a classic token with the `notifications` scope
