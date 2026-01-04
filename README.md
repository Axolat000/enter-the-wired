#Enter the Wired - Universal ACCELA & SLSsteam Installer
This script makes it easier to install ACCELA and SLSsteam (to play games that are not in your library).
It detects your Linux distribution and attempts to install dependencies automatically.

Main Features:
Automatic dependency installation (Fedora, Debian/Ubuntu, Arch, Bazzite/SteamOS)
Native Steam and Flatpak Steam support (automatic detection)
Modifies /usr/bin/steam directly with LD_AUDIT injection
Patches steam.sh in Steam installation directory
Creates backup at /usr/bin/steam.bak before modifying
Opens Steam temporarily to allow updates
Creates steam.cfg to prevent Steam from overriding the configuration
Works in Gaming Mode and Desktop Mode on all distributions
SafeMode enabled by default (Steam Deck)
PlayNotOwnedGames enabled by default
