# Security Policy

## What NotchNudge can and can't do

- **No network access.** NotchNudge never connects to the internet. No analytics, no update checks, no crash reporting.
- **No special permissions.** It does not ask for Accessibility, Screen Recording, Full Disk Access, or any other privacy permission. The global shortcut uses a standard macOS API that needs no permission.
- **One local file.** Your reminders are stored in `~/Library/Application Support/NotchNudge/reminders.json`. Nothing else is read or written.
- **Built in the open.** Every release file is built by GitHub Actions from the tagged source code. You can see the build log for each release in the [Actions tab](https://github.com/sergxp/notchnudge/actions/workflows/release.yml), and check downloads against `SHA256SUMS.txt` on the release page.

## Supported versions

Only the [latest release](https://github.com/sergxp/notchnudge/releases/latest) gets security fixes.

## Reporting a vulnerability

Please **don't open a public issue** for security problems.

Report it privately through GitHub: go to the [Security tab](https://github.com/sergxp/notchnudge/security) and click **Report a vulnerability**.

You can expect a first reply within 7 days. Once a fix is released, you'll be credited in the release notes unless you'd rather stay anonymous.
