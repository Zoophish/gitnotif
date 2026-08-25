# GitNotif

A tiny, fast, native macOS menu bar app for GitHub notifications — like Gitify, but ~1,000 lines of Swift with zero dependencies.

![requires macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)

## Features

- Bell icon in the menu bar with live unread count
- Popover inbox grouped by repository, with type-colored icons (PRs, issues, releases, discussions)
- Native swipe actions — full-swipe to mark done, swipe right to mark read
- Native banner notifications for new items; click to open on github.com
- Right-click the bell for a quick menu (refresh, sign out, quit)
- Polls the GitHub notifications API, honoring `X-Poll-Interval` and `If-Modified-Since` (most polls are free 304s, gentle on rate limits)
- Token stored in the macOS Keychain
- No Dock icon

## Install

### Homebrew

```sh
brew install --cask --no-quarantine zoophish/tap/gitnotif
```

`--no-quarantine` is needed because the app is not notarized (no paid Apple
Developer account). Alternatively, right-click the app → Open on first launch.

### From source

```sh
./build.sh
cp -R build/GitNotif.app /Applications/
open /Applications/GitNotif.app
```

## Setup

The GitHub notifications API only works with classic PATs and OAuth app tokens
(fine-grained PATs are not supported). On first launch, click the bell and either:

- **Use GitHub CLI token** — reads `gh auth token`. Best option if your org
  blocks classic PATs (the GitHub CLI is an OAuth app most orgs allow), or
- paste a **classic PAT** with the `notifications` scope.

## Layout

```
Sources/GitNotif/
  GitNotifApp.swift       # MenuBarExtra shell + right-click status menu
  NotificationStore.swift # @Observable state + polling loop
  GitHubClient.swift      # REST calls, pagination, poll headers
  BannerCenter.swift      # UserNotifications banners for new items
  GHCLI.swift             # reads the GitHub CLI token
  Models.swift            # GHNotification + web-URL mapping
  Keychain.swift          # token storage
  Views/                  # SwiftUI popover, rows, token setup
```
