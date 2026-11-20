# How to Join the V Rising Server

## Requirements

- **V Rising on PC (Steam)** (no PS5 crossplay).
- **Tailscale** installed and connected to the shared tailnet.

## First-Time Connection

1. Make sure **Tailscale** is running and connected.
2. Open **V Rising**.
3. Go to **Play → Online Play → Find Servers**.
4. Click **Direct Connect** (bottom-right).
5. Enter **`<TAILSCALE_IP>:9876`** (must be `silmeria`'s numeric `100.x.y.z` IPv4 address — do **not** type `silmeria`).
6. Check the **LAN Server** box.
7. Click **Connect** (no password required) and create your vampire.

> **Next time you play:** Just click **Continue** on the main menu (with Tailscale running).

## FAQ & Common Issues

**I get `Error: Authentication Error` while loading.**
- You didn't check **LAN Server** in the Direct Connect window. Go back, tick **LAN Server**, and connect again.

**Connection timed out / server not reachable.**
- Check that **Tailscale is turned on and logged in**.
- Verify you typed **`<TAILSCALE_IP>:9876`** (numeric `100.x.y.z` IP + `:9876`, not a hostname).
- Turn off any other VPN (e.g., NordVPN, Cloudflare WARP) that may conflict with Tailscale.
- Check the clock: the server runs a brief daily backup at **05:45** and reboots at **06:00** (Brasília time / `America/Sao_Paulo`). Wait ~5 minutes and retry.

**I can't find the server in the in-game server browser.**
- Expected — the server is intentionally unlisted and private to Tailscale. Always join via **Direct Connect** the first time.

**It asks for a password — what is it?**
- There is no password. Leave it blank (or make sure you didn't mistype the IP/port).

**`Version mismatch` error.**
- Close V Rising and let **Steam update the game**. If V Rising just released a patch today, ask the host to restart the server (it auto-updates on restart and every morning at 06:00).

**High ping or rubber-banding.**
- Pause downloads and disconnect any other VPN. Tailscale may temporarily fall back to a relay if your router has strict NAT; restarting Tailscale or switching off restrictive Wi-Fi/mobile hotspots usually restores a direct peer-to-peer link.

**The server kicked me around 05:45 or 06:00 — did I lose my progress?**
- No. The server autosaves every 2 minutes and performs a clean save before both the `05:45` backup and the `06:00` daily reboot.

**Can my friend on PS5 join?**
- No — V Rising does not support PC/PS5 crossplay. Steam PC only.
