RaspSetup v4 – 2026‑03‑16

This release focuses on improving the user experience and modernising the
toolset provided by RaspSetup. Key changes include:

Added

Fastfetch replaces Neofetch. Fastfetch is installed via apt and
presents system information more quickly and attractively.

Node.js & NPM installer now uses the NodeSource LTS setup script by
default, falling back to the distribution packages if that fails.

Unattended Pi‑Hole and AdGuard Home installs to avoid intrusive
interactive prompts and run in a quieter mode.

Dynamic system information (OS, board model and RAM) is displayed in
the update prompt to give users a clear picture of their hardware.

A unified error display (msg_error) and success countdown gauge
(msg_countdown) for consistent feedback across all installers.

Changed

Neofetch option removed and replaced by Fastfetch in the menu.

Improved whiptail UI: wider menu, clearer descriptions and more
consistent messaging.

Better board detection using /sys/firmware/devicetree/base/model with
fallbacks and RAM display.

The Node.js option uses install_nodejs() rather than the generic
apt installer and automatically attempts to use the NodeSource script.

Pi‑Hole installation now uses --unattended to avoid prompts.

AdGuard Home installation now uses the --silent flag.

Fail2Ban configuration for Webmin is now optional and triggered
only when both Webmin and Fail2Ban are installed.

Fixed

Corrected minor typos and cleaned up the code structure for readability.

Consolidated redundant installation logic into reusable functions.

Removed

Support for Neofetch has been dropped in favour of Fastfetch.
