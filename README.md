# AI Powerhouse Installer

One command to set up everything you need.

## macOS Installation

Open Terminal and paste this command:

```bash
curl -fsSL https://raw.githubusercontent.com/eddale/ai-powerhouse-installer/main/install-mac.sh | bash
```

The installer runs for 5-15 minutes (mostly automatic).

## What Gets Installed

- **Xcode Command Line Tools** (developer tools for your Mac)
- **Homebrew** (package manager)
- **GitHub CLI** (connects to your account)
- **Claude Code** (your AI assistant)
- **Your personal workspace** (downloaded to ~/Documents/my-powerhouse)
- **Desktop launcher** (double-click to start)

## Already Installed Something?

No problem. The installer detects what's already there and skips it.

You can re-run the installer any time -- it won't break anything.

## After Installation

1. Double-click **AI Powerhouse** on your Desktop
2. When Claude starts, type: `build my mission context`
3. Complete the guided interview (~50 minutes)

Your AI workspace is now personalized to you.

## Troubleshooting

**"Permission denied" when running the script?**
Make sure you're copying the entire command including `curl`.

**Homebrew asks for your password?**
This is your Mac login password. It's normal -- Homebrew needs it to install.

**Browser opened but nothing happened?**
Click "Authorize" in the browser, then come back to Terminal.

**Claude command not found after install?**
Close Terminal completely, open a new one, and try: `claude --version`

## Windows

Coming soon. For now, follow the manual setup guide.
