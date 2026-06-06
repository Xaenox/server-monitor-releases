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

## Install Agent On Another VPS

Use this flow for every VPS you want to monitor.

1. Connect the VPS to your private network, for example Tailscale:

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=<server-name>
```

With a Tailscale auth key:

```bash
read -rsp "Tailscale auth key: " TS_AUTH_KEY; echo
sudo tailscale up --auth-key="$TS_AUTH_KEY" --hostname=<server-name>
unset TS_AUTH_KEY
```

2. In the dashboard, add a new server and copy the agent token shown once.

3. On the monitored VPS, install the agent:

```bash
curl -fsSLo /tmp/server-monitor-install.sh \
  https://github.com/Xaenox/server-monitor-releases/releases/latest/download/install.sh
sudo bash /tmp/server-monitor-install.sh agent \
  --dashboard-url https://<dashboard-hostname-or-domain>
```

The installer prompts for the agent token interactively so the token is not written to shell history.

4. Verify:

```bash
systemctl status server-monitor-agent --no-pager
journalctl -u server-monitor-agent --since "2 minutes ago" --no-pager
```

The server should appear live in the dashboard within one collection interval, usually 30 seconds.
