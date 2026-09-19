# Temporary Gaming RDP

The **Temporary Gaming RDP** workflow creates a Windows GitHub Actions runner,
enables RDP with Network Level Authentication, and connects it to Tailscale.
The runner is temporary and is removed when the workflow ends or is cancelled.

Before running it, add these repository secrets under **Settings → Secrets and
variables → Actions**:

- `TAILSCALE_AUTH_KEY`: a short-lived, reusable Tailscale auth key
- `RDP_PASSWORD`: a password of at least 12 characters

Start the workflow from **Actions → Temporary Gaming RDP → Run workflow**.
Install and sign in to Tailscale on your client device, then use the Tailscale
IPv4 address and displayed username in an RDP client. The workflow never prints
the password and does not add the RDP user to Administrators.

When the workflow ends, it backs up common Windows game-save locations
(`Documents\My Games`, `Saved Games`, and the user AppData folders) as a
private Actions artifact named `game-saves-<run-id>`. Download that artifact
from the completed workflow's **Summary** page before starting a future
session. This saves game progress, not installed games or the Windows
environment. Some launchers use cloud saves or custom folders that may need
separate backup configuration.

The runner also selects Windows High performance mode, removes AC CPU
throttling, enables Game Mode and hardware-accelerated GPU scheduling when
supported, disables Game Bar capture overhead, and keeps RDP UDP transport
enabled for lower input latency. GitHub-hosted runners are still shared
virtual machines, so they may not provide a gaming GPU or consistent frame
rates.

GitHub-hosted runners have limited lifetime and are not dedicated gaming
machines. RDP is also not optimized for high-refresh gaming; Sunshine and
Moonlight generally provide better game streaming.
