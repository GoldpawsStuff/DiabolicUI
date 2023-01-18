# DiabolicUI2 Change Log
All notable changes to this project will be documented in this file. Be aware that the [Unreleased] features are not yet available in the official tagged builds.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [2.0.10-RC] 2023-01-18 (Wrath)
### Fixed
- More fixes for the new checked/highlight action button textures in WoW 3.4.1.

## [2.0.9-RC] 2023-01-18 (Wrath)
### Fixed
- Fixed issues related to API changes in WoW 3.4.1.

## [2.0.8-RC] 2022-12-14
### Fixed
- Chat bubbles are now disabled when Prat is loaded. They just don't play nice together.

## [2.0.79-RC] 2022-12-09
### Fixed
- Chat bubble font sizes should now be more sane.

## [2.0.78-RC] 2022-12-09
### Fixed
- Our micro menu module should no longer interfere with ConsolePort.

## [2.0.77-RC] 2022-12-09
### Fixed
- The wrath quest tracker once again works today and all the animals in the forest are happy!

## [2.0.76-RC] 2022-12-08
### Changed
- The chat module will now auto-disable if the addons Prat or Glass are enabled.

### Fixed
- Fixed the extra action buttons for 10.0.2.
- Fixed the objectives tracker for 10.0.2.
- Fixed the chat frames for 10.0.2.
- Fixed the minimap for 10.0.2.
- Stopped tainting the edit mode.

## [2.0.75-RC] 2022-12-07
### Fixed
- Fixed a bug related to faulty event registration when handling compatibility and interactions with Bartender4.

## [2.0.74-RC] 2022-12-01
### Changed
- Updated TaintLess.xml to 22-11-27.

## [2.0.73-RC] 2022-12-01
### Added
- Added chat bubble styling.

## [2.0.72-RC] 2022-12-01
### Fixed
- Fixed minimap left clicks in retail.

## [2.0.71-RC] 2022-11-28
### Fixed
- Fixed a bug that would render primary action bar keybinds useless after leaving a vehicle or petbattle.

## [2.0.70-RC] 2022-11-25
- Fuck you editmode.

### Fixed
- Fixed wrong upvalues causing bugs in the Retail alertframe (achievement popups, loot popups etc) handling.
- Removed the last remnants of a failed Wrath watchframe experiment causing bugs.

## [2.0.69-RC] 2022-11-24
### Fixed
- Fixed incorrect usage of the monk stagger element.
- Added the missing color entry for evoker essence.

## [2.0.67-RC] 2022-11-21
### Fixed
- Fixed vehicle page switching for retail.
- Fixed bartender integration for retail.

## [2.0.66-RC] 2022-11-18
### Fixed
- Fixed aura filters for retail.

## [2.0.65-RC] 2022-11-16
- Bump to retail client patch 10.0.2.

### Added
- Added raid target icons to the nameplates.

### Changed
- The orb artwork should no longer temporarily disappear when entering a vehicle, and will always remain visible even when the "player" unit does not exist.

### Fixed
- Fixed the sometimes faulty opacity of runes.
- Fixed some inconsistencies on prediction textures on the health orbs.

## [2.0.64-RC] 2022-11-05
### Added
- Added a compatibility module that handles the conflict with Bartender's blizzard vehicle setting and keybinds in vehicles.
- Working versions of the pet- and stance bars has been added to the development mode. Their functionality is now as intended. Will be made public once the artwork is done.

### Changed
- Moved all Bartender compatibility handling into the new module dedicated to this.

### Fixed
- Fixed the retail reputation tracking bar and how it interacts with friendship reputations.
- Fixed an issue with extra action button textures in WoW 10.0.2.

## [2.0.63-RC] 2022-10-31
### Added
- Added health preview and heal prediction to the player health orb.
- Added health preview and heal prediction to nameplates.
- Added combat feedback text to the pet- and focus unit frames.
- Added mouseover text to the xp- and reputation tracking bars.

### Changed
- Overhauled the orb library and unit frame code for brighter and more colorful orbs.
- The power orb is now clickthrough, allowing more interaction with the world while still reacting to mouseover scripts to toggle the out of combat value display.
- Moved all action button edits to the front-end and reverted to a fully baseline button library.
- Moved the target unit frame combat feedback to its left side, to leave more room between the right side of the frame and the new buff display.

### Fixed
- Fixed the reputation tracking bar to work with Wrath.

## [2.0.62-RC] 2022-10-26
### Changed
- The power orb value display now uses frequent updates for more accurate values.

### Fixed
- The blizzard debuff frame has once again been hidden in retail.
- Aura buttons are once again styled properly in retail.

## [2.0.61-RC] 2022-10-25
- Bumped retail version to the 10.0.0 client patch.

### Added
- Added combat feedback text to the player health orb.
- Added combat feedback text to the right of the target unit frame.
- Added health preview and heal prediction to the target frame.

## [2.0.60-RC] 2022-10-23
### Fixed
- The side action bars should once again have different buttons, and not all be copies of the same one.

## [2.0.59-RC] 2022-10-23
### Changed
- New and prettier addon naming pattern.

### Fixed
- Fixed some inconsistencies with the Wrath consolidation counter and buff frame alpha.
- Removed tooltip widget handlers that no longer exist in Dragonflight.

## [2.0.58-RC] 2022-10-23
### Fixed
- Weapon enchants should no longer cause non-stop bugs in Wrath.
- Added custom unit drivers for the player- and pet unit frames in Wrath to work around the Wrath bug where these frames refuse to toggle for vehicles.

## [2.0.57-RC] 2022-10-21
### Added
- Added the `/auras hide` command to always hide the full buff display.
- Added the `/auras show` command to always show the full buff display. This is the default setting.
- Added the `/auras auto` command to mostly hide the full buff display. It is shown while holding the Ctrl and Shift modifiers at the same time. It will also be shown in Wrath while grouped and not engaged in combat. Consider this a mode useful for Wrath raiders that prefer less spam but still need to have it visible for the sake of buffing.
- Some stuff I'd rather not talk about. Currently only available to git users running in dev mode. Which you shouldn't do.

### Changed
- Made the full buff display permanently visible and moved it to its expected location up next to the minimap. This is an experiment, and I'm not yet fully convinced I'll leave it in there. It does however allow me to more aggressively filter the centered aura display above the actionbars without too many complaints. In Wrath some auras will be consolidated.
- Moved the default position of the tooltip slightly.
- Changed how the minimap and quest tracker are anchored and moved.
- Changed how width and the general handling of the Wrath quest tracker is done, in an affort to work against the annoying taint where quest buttons will become unclickable if they are spawned during combat. Untested, as it's a bit hard to test this out in Wrath, at least until I hit max level and get some dailies that suit my testing purposes.

### Fixed
- The bug in 2.0.56-RC causing the secondary bar to spawn underneath the primary bar has been fixed.

## [2.0.55-RC] 2022-10-16
### Changed
- Updated action button library to be closer to its baseline version, moved a lot of customizations into the front-end.

## [2.0.54-RC] 2022-10-15
### Changed
- Debuffs on the player should no longer be desaturated.
- Various back-end updates and fixes, both in preparation for the upcoming retail expansion and upcoming addon extensions to this user interface.

## [2.0.53-RC] 2022-10-04
### Changed
- Changed the Wrath tracker's scaling slightly, to avoid truncated text and weird spaces.

### Fixed
- The exit button at the end of the primary action bar while inside a vehicle now also gets a fitting texture in Wrath.

## [2.0.52-RC] 2022-09-30
### Added
- Attached the keyring to the bag buttons beneath the backpack in Wrath.

### Changed
- Changed the sort order of nameplate and target auras to show the ones with the shortest time remaining first.

### Fixed
- Prevented the WatchFrame from opening the questlog during combat, as a workaround to a taint I have yet to discover the source of. Normal keybinds to open the log still work just fine.

## [2.0.51-RC] 2022-09-29
### Changed
- Prettied up the color used for combo points to match the more pleasing one in SimpleClassPower.

## [2.0.50-RC] 2022-09-28
### Fixed
- Fixed various wrong client version checks that could cause issues with amongst other things the minimap and the quest tracker.

## [2.0.49-RC] 2022-09-25
### Added
- Added general Dragonflight support. But don't report bugs yet, I have not officially started on this, this is just a bonus.
- Added the updated version of TaintLess.xml from Sep 15th 2022.

### Changed
- The player filtered aura display above the actionbars now shows buffs that will expire in 30 seconds or less.
- Integrated Player Alternate Power into the normal power orb. This is an experimental feature and I might add a temporary text tracking the standard power while the Player Alternate Power is visible.

### Fixed
- Fixed various texture creation syntax errors that Retail and Classic ignores but Dragonflight really have an issue with.

## [2.0.48-RC] 2022-09-22
### Added
- Added timer bars and text to the full buff display.

### Changed
- Changed the Wrath nameplate aura filter to include actual auras.
- Tweaked the retail nameplate aura display to also show short buffs like HoTs.
- Reversed the order of the full buff display to show timeless buffs first, then ordered by remaining time.
- The micro menu backdrop will now adjust itself when blizzard change visible buttons.
- Tweaked the look of the instance countdown timers as well as the mirror timers (fatigue, breath, etc) to look more like our castbars. Not the prettiest.

## [2.0.47-RC] 2022-09-21
### Added
- Added Druid/Rogue/Vehicle Combo Points, Mage Arcane Charges, Monk Chi, Paladin Holy Power and Warlock Soul Shards.
- Added Monk Stagger.

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
