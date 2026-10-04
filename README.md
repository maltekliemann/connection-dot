# connection-dot

A [SwiftBar](https://swiftbar.app) plugin that shows the state of your internet connection as a colored dot in the macOS menu bar. When the connection fails, the dropdown shows where: local network, ISP or DNS.

## How it works

Every second, the script fetches Apple's captive portal check (`captive.apple.com/hotspot-detect.html`), the same one macOS uses. The TCP connect time doubles as the ping. A parallel connection to 1.1.1.1 catches broken IPv4 when the fetch goes over IPv6.

The last 10 results are kept in `$TMPDIR/connection-dot.state`. After two consecutive failures, the script pings the default gateway, connects to 1.1.1.1 and 8.8.8.8, and queries DNS to locate the fault.

## States

| Dot | Meaning |
|---|---|
| Green | Connected. The dropdown shows ping, average ping and recent failures. |
| Yellow | Degraded: average ping above 150 ms, 2 or more of the last 10 checks failed, IPv4 down, DNS failing, or a captive portal. |
| Red | No internet. The dropdown shows whether the router still answers. |

The thresholds are at the top of the script.

## Setup

1. Install SwiftBar: `brew install --cask swiftbar`
2. Start SwiftBar and choose a plugin folder when asked, e.g. `~/SwiftBar`. If you already use SwiftBar, use your existing plugin folder; it is shown in SwiftBar's preferences.
3. Copy the script into the plugin folder:

   ```
   cp connectivity.1s.sh ~/SwiftBar/
   chmod +x ~/SwiftBar/connection-dot.1s.sh
   ```

   SwiftBar picks it up immediately. The `1s` in the filename sets the refresh interval.
4. Turn on "Launch at login" in SwiftBar's preferences so the dot survives a restart.

## Troubleshooting

- **No dot:** check System Settings → Menu Bar → Allow in the Menu Bar.
- **Dot hidden behind the notch:** make room in the menu bar, then ⌘-drag the dot into place.
