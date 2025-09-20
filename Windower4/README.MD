# WhereIsNM

A Windower 4 addon for Final Fantasy XI that tracks the latest locations of roaming Notorious Monsters (NMs) and shimmering ??? spawn points in Temenos and Apollyon. The data is based on reports from other players on your server and automatically refreshes to keep information current.

## Features

- Track roaming NM locations in real-time
- Monitor ??? spawn points
- Server-based reporting system with automatic data refresh
- Built-in duplication protection
- 24-hour automatic data cleanup
- Support for both Temenos and Apollyon zones
- Shortcut commands for quick reporting

## Installation

1. Download the latest release from the [Releases](../../releases) page
2. Extract the `addons/whereisnm/` folder to your Windower directory
3. Load the addon using `//lua load whereisnm` or add it to your startup script

## Commands

### Basic Usage
- `//nm` - Get the latest NM and ??? locations
- `//nm show/hide` - Display or hide the UI box
- `//nm help` - Show all available commands

### Reporting Locations

#### ??? Spawn Reports
```
//nm report <zone> <sector> <floor>
```
**Example:** `//nm report t central 2`

#### NM Spawn Reports
```
//nm report nm <job/name> <zone> <sector> <floor>
```
**Examples:**
- `//nm report nm war t central 2` (using job abbreviation)
- `//nm report nm agoge t central 2` (using NM name)
- `//nm report nm theophany a nw 3` (Apollyon NM)

#### Time of Death (TOD) Reports
```
//nm report tod [job/name] <zone> <sector> <floor>
```
**Examples:**
- `//nm report tod war t central 2` (kill specific NM)
- `//nm report tod t central 2` (kill any NM at location)

## Zone Reference

### Zone Shortcuts
- `t`, `te`, `tem` = Temenos
- `a`, `ap`, `apo` = Apollyon

### Available Sectors

#### Temenos
- `n`, `north`, `northern` (floors 1-7)
- `w`, `west`, `western` (floors 1-7)
- `e`, `east`, `eastern` (floors 1-7)
- `c`, `cent`, `central` (floors 1-4)

#### Apollyon
- `nw` (floors 1-5)
- `ne` (floors 1-5)
- `sw` (floors 1-4)
- `se` (floors 1-4)

## NM Reference

### Temenos NMs
| Job | NM Name |
|-----|---------|
| war | Agoge |
| mnk | Hesychast's |
| whm | Piety |
| blm | Archmage's |
| rdm | Vitiation |
| thf | Plunderer's |
| pld | Caballarius |
| drk | Fallen's |
| bst | Ankusa |
| brd | Bihu |
| rng | Arcadian |
| sam | Sakonji |
| nin | Mochizuki |
| drg | Pteroslaver |
| smn | Glyphic |
| blu | Luhlaza |
| cor | Lanun |
| pup | Pitre |
| dnc | Horos |
| sch | Pedagogy |
| geo | Bagua |
| run | Futhark |

### Apollyon NMs
| Job | NM Name |
|-----|---------|
| war | Pummeler's |
| mnk | Anchorite's |
| whm | Theophany |
| blm | Spaekona's |
| rdm | Atrophy |
| thf | Pillager's |
| pld | Reverence |
| drk | Ignominy |
| bst | Totemic |
| brd | Brioso |
| rng | Orion |
| sam | Wakido |
| nin | Hachiya |
| drg | Vishap |
| smn | Convoker's |
| blu | Assimilator's |
| cor | Laksamana's |
| pup | Foire |
| dnc | Maxixi |
| sch | Academic's |
| geo | Geomancy |
| run | Runeist |

## How It Works

- Data is based on reports from players on your server
- Reports automatically expire after 24 hours to keep information fresh
- New reports replace old reports for the same location
- Built-in duplication protection prevents spam reporting
- Use shortcuts for faster reporting (zone abbreviations, job codes, etc.)

## Requirements

- **Windower 4**: This addon requires Windower 4
- **FFXI**: Compatible with Final Fantasy XI
- **Server Connection**: Requires connection to retrieve shared data

## File Structure

```
addons/whereisnm/
├── whereisnm.lua    
├── api.lua         
└── sha2.lua        
```

## Quick Start

1. Load the addon: `//lua load whereisnm`
2. Check current locations: `//nm`
3. Report a ??? spawn: `//nm report t central 2`
4. Report an NM: `//nm report nm war t central 2`
5. Report a kill: `//nm report tod war t central 2`

## Troubleshooting

**Addon won't load**
- Ensure all files are in `Windower4/addons/whereisnm/`
- Check Windower console for error messages

**No data showing**
- Data depends on player reports from your server
- Try `//nm` to refresh current data

**Commands not working**
- Verify addon is loaded with `//lua list`
- Check command syntax in `//nm help`

## Support

- Submit issues on the [GitHub Issues](../../issues) page
- Visit [whereisnm.com](https://whereisnm.com) for more information
- Check the [documentation](https://whereisnm.com/documentation) for detailed guides

## License

See the LICENSE file for license information.