# server-monitor releases

Public release assets for the private `server-monitor` source repository.

This repository intentionally contains no source code. Use the GitHub Releases assets for production installs.

## Quick Install

Dashboard behind Tailscale:

```bash
curl -fsSLo /tmp/server-monitor-install.sh \
  https://github.com/Xaenox/server-monitor-releases/releases/latest/download/install.sh
sudo bash /tmp/server-monitor-install.sh dashboard --tailscale-serve
```

Agent:

```bash
curl -fsSLo /tmp/server-monitor-install.sh \
  https://github.com/Xaenox/server-monitor-releases/releases/latest/download/install.sh
sudo bash /tmp/server-monitor-install.sh agent --dashboard-url https://server-monitor.example.ts.net
```

The wrapper asks for passwords and agent tokens interactively, then downloads the pinned release installers and assets from this repository's GitHub Releases.
