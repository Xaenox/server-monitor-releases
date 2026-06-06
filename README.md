# server-monitor releases

Public release assets for the private `server-monitor` source repository.

This repository intentionally contains no source code. Use the GitHub Releases assets for production installs.

## Quick Install

Dashboard behind Tailscale:

```bash
curl -fsSL https://raw.githubusercontent.com/Xaenox/server-monitor-releases/main/install.sh \
  | sudo bash -s -- dashboard --tailscale-serve
```

Agent:

```bash
curl -fsSL https://raw.githubusercontent.com/Xaenox/server-monitor-releases/main/install.sh \
  | sudo bash -s -- agent --dashboard-url https://server-monitor.example.ts.net
```

The wrapper asks for passwords and agent tokens interactively, then downloads the pinned release installers and assets from this repository's GitHub Releases.
