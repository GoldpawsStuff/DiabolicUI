# DiabolicUI2 Change Log
All notable changes to this project will be documented in this file. Be aware that the [Unreleased] features are not yet available in the official tagged builds.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [2.0.46-RC] 2022-09-20
### Added
- Added the `/calendar`chat command to Wrath.
- Added a full buff display, accessible by clicking a plus icon in the bottom left corner of the screen. The icon is invisible until hovered, or by holding down the `Shift`+`Ctrl` modifier keys. Beware that this is just the first draft, expect upgrades to the display in the upcoming days, like timer bars.

### Changed
- Changed the Wrath tracker frame strata to be below the default Immersion setting, as this was interfering with the ability to click the dialogs.

### Fixed
- Fixed the distance between the tracker title and its collapse button in Wrath when the tracker was collapsed when logging on or after a reload.

## [2.0.45-RC] 2022-09-19
### Added
- Added mirror timers for things like breath, fatigue and feign death.
- Added retail timer trackers, for things like dungeon and battleground countdowns.

## [2.0.44-RC] 2022-09-17
### Added
- Added the Wrath Shaman totem bar.

## [2.0.43-RC] 2022-09-16
### Changed
- Put the Wrath tracker into a higher frame strata to keep it above the Diabolic action bar artwork.

### Fixed
- The Wrath minimap tracking menu now correctly appears when right-clicking the map.
- There is no longer a bugged Wrath minimap middle-click shortcut.

## [2.0.42-RC] 2022-09-15
### Fixed
- Fixed the issue that made the buttons very dark for everybody that did not use the GoldpawEdition.
- Changed the order of the Wrath Runes color table to match on-screen order, instead of being ordered by runeTypeID. Since we're using oUF which sort by display order for our unitframes, this caused the Unholy and Frost to be mixed up.

## [2.0.40-RC] 2022-09-13
### Added
- Added first draft of Runes for both Retail and Wrath. Based directly on the look of SimpleClassPower. Plan to add some different textures for the Wrath version, as the multi-colored runes calls for a different visual aesthetic than the point driven Retail Rune system requires.

### Fixed
- The title of the collapsed Wrath tracker should no longer cover parts of the expand/collapse toggle button.

## [2.0.39-RC] 2022-09-12
### Changed
- Chat buttons and tabs should now become visible when the chat window is moused over.
- Will no longer change the default nameplate visibility distance in Wrath.

### Fixed
- Now clears the alpha of the "-" prefix of quest lines in the Wrath tracker on every update.

## [2.0.38-RC] 2022-09-11
### Added
- Added the missing and unstyled buttons to the Wrath micro menu.
- Added a skull icon to unit tooltips of non-classified boss mobs whose unit level couldn't be determined.

### Changed
- Adjusted the minimap clock font slightly.
- Adjusted action button icons to be slightly brighter.
- Adjusted the health orb content to be slightly brighter.

## [2.0.37-RC] 2022-09-09
### Changed
- Updated oUF fully for Wrath.
- Updated the Wrath quest tracker scale to follow DiabolicUI, not the Blizzard UIscale.

## [2.0.36-RC] 2022-09-08
### Fixed
- Hiding the reputation- and max level tracking bars in Wrath.
- Fixed some issues related to difficulty coloring when hovering over certain units.

## [2.0.35-Release] 2022-09-08
- Added first draft of Wrath compatibility.

### Fixed
- Fixed an issue where chat font sizes would reset on every reload.

## [2.0.34-Release] 2022-09-03
### Removed
- Removed TaintLess.xml as it's about to be deprecated.

## [2.0.33-Release] 2022-08-24
- Restructure repository to be a fork of UICore.
- Added and updated the first draft of the wiki pages.

## [2.0.32-Release] 2022-08-17
- Bump to client patch 9.2.7.

### Added
- Added the `/setscale n` chat command to change the scale of DiabolicUI2 and its elements. Accepted values for `n` range from 0.75 to 1.25, where 1 is the default setting.
- Added the `/resetscale` chat command, which resets any user set scales to the default value of 1.

## [2.0.31-RC] 2022-08-09
- Why the fuck was the TOC version set to Dragonflight?

## [2.0.30-RC] 2022-07-29
### Changed
- Changed how font object size is calculated in the chat frames, as code comments in the blizzard interface API indicates that default/unset font sizes will return wrong size values.

## [2.0.29-Beta] 2022-07-15
### Added
- Added API constants to check for Dragonflight client versions.
- Added a lot of code to handle disabling of Blizzard bars and objects in Dragonflight.

### Removed
- Removed some redundant copypaste leftovers that weren't relevant to neither Shadowlands nor Dragonflight, which are the only client versions DiabolicUI supports.

## [2.0.28-RC] 2022-07-14
### Changes
- Updated the embedded oUF to the most recent version.
- A boat load of fortification in the blizzard default object removal code. And possibly some bugs, since everything is untested these days.

## [2.0.27-Release] 2022-05-31
- Bump toc to WoW client patch 9.2.5.

## [2.0.26-Release] 2022-05-02
### Added
- Added `/switchto` as an alias for th `/go` theme-switcher command. Did you know you can type `/go azerite` and `/go diabolic` to switch between AzeriteUI and DiabolicUI when you have both installed?

## [2.0.25-Release] 2022-04-24
- Untested changes, nobody volunteered. Will deal with potential bugs when reported.

### Added
- Added a `/setclock` command with the optional args `12`, `24`, `local` and `realm` to toggle how the minimap clock displays the time. For example typing `/setclock 24 local` sets the clock to use your local computer time in 24-hour mode.

## [2.0.24-RC] 2022-04-06
### Removed
- Removed the now deprecated FixingThings.

## [2.0.23-RC] 2022-03-19
### Added
- Added the first draft of a micro menu. Usual place. Usual functionality.

### Fixed
- Forcefully loads Narcissus (when installed and enabled) before entering the world to work around an issue that sometimes can occur when entering the world or reloading the user interface while engaged in combat.

## [2.0.22-Beta] 2022-03-17
### Changed
- The plus buttons to toggle additional actionbars are now by default hidden from view, but will become visible either when hovering the mouse cursor above them, or when holding down the `Ctrl` and `Shift` modifier keys at the same time.

## [2.0.21-Beta] 2022-03-16
### Added
- Added the new simpler chat commands `/enablesecondary`, `/disablesecondary` and `/togglesecondary` to toggle the secondary actionbar. As with `/setbars` these commands only have any effect when not engaged in combat. You cannot toggle bars through these commands in combat.

### Fixed
- Fixed broken and deprecated saved settings that caused all sorts of weird actionbar behaviors. Bar count and player aura positions should save between sessions and update properly again now.

## [2.0.20-Beta] 2022-03-16
- Updated the major addon version to reflect this is the second iteration of this user interface.

### Added
- Added a bunch of sidebars available from currently constantly visible toggle buttons. They will eventually be visible only on hover or when holding down a modifier combo, this is just a test build.

### Changed
- Changed the tooltip border texture to a new one based on the actionbar artwork.
- Player buffs can now be right-click removed out of combat.

## [0.0.18-Alpha] 2022-02-18
### Added
- Added the dungeon finder eye to the minimap.

### Fixed
- Opening the calendar is considered a protected action by the Blizzard API, so we will no longer allow it to be opened during combat by clicking on our clock button. Note that the Blizzard chat command `/calendar` works even when engaged in combat.

## [0.0.17-Alpha] 2022-02-08
### Changed
- Absorb shields are now only shown as a number, not as part of the health orbs. Absorb shield texture will be added later!

## [0.0.16-Alpha] 2022-02-06
### Added
- Added a new mail notifier to the minimap.

### Changed
- Moved the Blizzard boss frames to a better position. This is just a temporrary measure until our own boss frames are ready.

## [0.0.15-Alpha] 2022-02-02
### Added
- Added icons to nameplate castbars.

### Changed
- Number of actionbars visible is now stored per character and between sessions.
- Player cast bar should change color to red for uninterruptable casts now.
- Nameplate cast bars should change color to red for uninterruptable casts now.

## [0.0.14-Alpha] 2022-02-01
### Added
- Added a clock. Clicking it will toggle the calendar. Options will be added later.

### Changed
- Added safezone to the player cast bar.

## [0.0.13-Alpha] 2022-01-30
### Changed
- Daily tweaks. No idea what, actually.

## [0.0.12-Alpha] 2022-01-26
### Changed
- Slightly adjusted bar and text sizes on the new player cast bar.

## [0.0.11-Alpha] 2022-01-25
### Added
- Added first skeleton draft of the floating player cast bar. Currently only shows time and text, no icons or shielded cast indicators as of yet.

## [0.0.10-Alpha] 2022-01-25
### Fixed
- Fixed faulty pkgmeta file.
- Added CurseForge and Wago project versions to toc file.
- Fixed a bug related to comparison tooltips that sometimes would occur when hovering over items in the adventure guide.

## [0.0.7-Alpha] 2021-12-16
### Changed
- The number of actionbars will now only be (re)set on login and reloads that resets the user interface, not on portal loading screens.

## [0.0.6-Alpha] 2021-12-09
### Changed
- Raised the frame level of the player status tracking bars like experience a few levels, to make sure the secondary bar usually containing rested bonus experience is still raised above the actionbar backdrop artwork.

## [0.0.5-Alpha] 2021-12-08
- Started counting the build numbers, and will keep this log updated from now on.
- Started merging and updating daily patch notes as I write them.

### Changed
- Our nameplate module will now auto-disable itself if other known nameplate addons are loaded.

### Fixed
- Fixed the weird `/setbars` behavior.
- Fixed an issue where uninitialized bars counted as manually disabled, causing leaving a vehicle to forcefully show both bars, even though just one was selected.
- Fixed a double local syntax bug in the actionbars module. Thanks Siggy!
