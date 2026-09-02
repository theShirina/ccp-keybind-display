# CCP Keybind Display

A keybind display and editor for Companion Control Panel (CCP), made for WoW 1.12 client.

The addon reads CCP commands directly from WoW's binding list, so it can pick up new commands without an update. It does not replace or modify CCP.

## Requirements

- WoW 1.12 client (`## Interface: 11200`)
- WoW's Companion Control Panel (CCP) installed and enabled

## Before installing

This addon is for compatible WoW 1.12 clients.

## Installation

1. Download [`CCPKeybindDisplay-0.3.1.zip`](https://github.com/theShirina/ccp-keybind-display/releases/download/v0.3.1/CCPKeybindDisplay-0.3.1.zip).
2. Close World of Warcraft.
3. Extract the ZIP into your WoW `Interface\AddOns` folder.
4. Check that this path exists:

   ```text
   Interface\AddOns\CCPKeybindDisplay\CCPKeybindDisplay.toc
   ```

5. Start WoW and enable **CCP Keybind Display** on the AddOns screen.

If the addon does not appear, check for an extra nested folder such as `CCPKeybindDisplay\CCPKeybindDisplay\`.

### Updating

Close WoW and replace the existing `Interface\AddOns\CCPKeybindDisplay` folder with the folder from the new ZIP. Account-wide settings remain in WoW's SavedVariables.

## What's new

### 0.3.1

- Filter the settings list by role without changing which commands appear on the HUD.
- Control each HUD binding after **Show all assigned** has been enabled.
- The HUD now sizes itself to the current text and font size; the **Preferred width** control has been removed.
- Background and HUD visibility controls now work with WoW 1.12 checkbox values.

### 0.3.0

- First public release with a compact command and keybind display.
- Persistent **Show all assigned** mode, role filters, and per-command visibility controls.
- Built-in keybind manager with conflict confirmation, plus a movable minimap button and settings window.

## Use

Type `/ckd` or click the minimap key icon to open settings.

The overlay shows one compact command column beside one keybind column. Its width follows the current text and font size, while the scale setting controls the final on-screen size.

Settings include:

- role filters for the settings list and per-command HUD visibility;
- persistent **Show all assigned** mode;
- opacity, scale, font size, and row spacing;
- background, lock, display, and minimap-button controls;
- an assigned-only settings filter;
- a built-in keybind manager with conflict confirmation.

The keybind manager saves accepted changes to WoW's active binding set. Replacing a command's bindings opens a confirmation, and any conflict names the action that will lose its key. **Clear all** is a separate button that removes both key slots.

### Commands

```text
/ckd              Open settings
/ckd show         Show the overlay
/ckd hide         Hide the overlay
/ckd lock         Lock the overlay
/ckd unlock       Unlock the overlay
/ckd minimap      Toggle the minimap button
/ckd refresh      Rediscover bindings
/ckd reset        Restore addon defaults
```

## How it works

CCP Keybind Display reads commands through `GetNumBindings()` and `GetBinding()`. It includes actions named `CCP_*` and CCP's `CP` show/hide action. Role suffixes place commands into General, Tank, Healer, Tank + Healer, DPS, Melee DPS, or Ranged DPS.

The addon has no network code, analytics, advertisements, or external services. It stores account-wide preferences only in `CCPKeybindDisplayDB`.

## Building and testing

The release ZIP is deterministic and contains only the addon folder.

```text
python tests/validate.py --lua <path-to-lua-5.0.3> --luac <path-to-luac-5.0.3>
python scripts/build_release.py
```

The validator checks Lua 5.0 syntax, `_G == nil` behavior, dynamic discovery, SavedVariables migration, layout geometry, binding transactions, release contents, and LF/CRLF reproducibility.

See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting changes.

## License

[MIT](LICENSE). Companion Control Panel and World of Warcraft are separate projects and are not included in this repository.
