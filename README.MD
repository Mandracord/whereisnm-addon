# WhereIsNM

![GitHub Downloads](https://img.shields.io/github/downloads/Mandracord/whereisnm-addon/total) ![Latest Release](https://img.shields.io/github/v/release/Mandracord/whereisnm-addon) ![GitHub last commit](https://img.shields.io/github/last-commit/Mandracord/whereisnm-addon)  [![Discord Bot](https://img.shields.io/badge/Discord-Invite%20Bot-5865F2?logo=discord&logoColor=white)](https://whereisnm.com/discord)



Track roaming Notorious Monsters (NMs) and ??? spawn points in FFXI's Temenos and Apollyon zones. Data is shared across your server with automatic updates and weekly resets.

## Quick Start

1. [Download the addon](https://whereisnm.com/addon)
2. Extract to `Your_Windower_Folder/addons/whereisnm/`
3. Load: `//lua load whereisnm` or add to your `init.txt` script
4. Use: `//nm` to view current locations

## Commands

| Command | Description | Example |
|---------|-------------|---------|
| `//nm` or `/nm` | Get latest NM and ??? locations | |
| `//nm tod [job_or_name]` | Report NM kill (inside Limbus) | `//nm tod War` or `//nm tod Agoge` |
| `//nm tod [zone] [job_or_name]` | Report NM kill (outside Limbus) | `//nm tod Temenos Agoge` |
| `//nm hud` | Display/Hide the HUD | |
| `//nm help` | Show all commands | |

**Note:** Commands work with `//` (Windower) or `/` (Ashita). TOD command accepts auto-translated terms for zone and job.

## Job Reference

Use job abbreviations (War, Mnk, Whm, etc.) or NM names (Agoge, Piety, Theophany, etc.) when reporting kills.

See the [complete job/NM mapping table](https://whereisnm.com/documentation#cheatsheet) for all 22 jobs across both Temenos and Apollyon.

## Weekly Reset Schedule

NM and ??? entries are automatically removed on weekly reset. Check [whereisnm.com/documentation](https://whereisnm.com/documentation) for current reset countdown.

## Discord Bot

Use `/recent [server]` in Discord to check your server's latest reports without being in-game. See [documentation](https://whereisnm.com/documentation#discord-bot) for all Discord commands.

## Requirements

- Windower 4 or ~~Ashita~~ (coming soon)

## Links

- [Full Documentation](https://whereisnm.com/documentation) - Complete guides and tables
- [Website](https://whereisnm.com)
- [Report Issues](https://github.com/Mandracord/whereisnm-addon/issues)

## License

See LICENSE file for details.
