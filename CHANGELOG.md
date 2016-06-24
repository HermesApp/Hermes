# Version 1.2.8 (6/24/16)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.7...v1.2.8)

* [changed by @nriley] Fix a regression introduced in 1.2.7 which degraded audio quality for non-Pandora One users (#263)
* [changed by @nriley] Always display Shuffle (formerly QuickMix) at the top of the station list, more like the Pandora Web site
* [changed by @reedloden] Scrobble securely where possible
* [added by @nriley] Only display song/artist/album arrows in the playback screen on mouseover
* [added by @nriley] Allow double-clicking seeds or genres to create a station or add a seed
* [added by @nriley] Allow the likes/dislikes lists in the Edit Station window to be sorted (#266)
* [added by @nriley] Save the size and position of the Edit Station window
* [added by @nriley] Sort station genres and improve their display
* [added by @nriley] Show playback date/time with tooltips in history drawer
* [added by @nriley] Sign with Developer ID for Gatekeeper
* [fixed by @nriley] Don’t allow the drawer or toolbar to be used before you’re logged into Pandora (#170)
* [fixed by @nriley] Display the station drawer when asking the user to “Choose a station” (#170)
* [fixed by @nriley] Don’t crash when adding or removing seeds from a station
* [fixed by @nriley] Don’t show the add station sheet after dismissing another sheet
* [fixed by @nriley] Fix search results showing up in unexpected places
* [fixed by @nriley] Allow clicking on album art in the history drawer (#178)
* [fixed by @nriley] Improve history display (e.g. no longer scrolls to/selects the oldest song)
* [fixed by @nriley] Better handle deleting the current station
* [fixed by @nriley] Allow editing seeds in genre stations (#267)
* [fixed by @nriley] Immediately reflect changes to likes/dislikes in the Edit Station window
* [fixed by @nriley] Display a progress indicator rather than appearing to get “stuck” when changing stations

# Version 1.2.7 (5/11/16)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.6...v1.2.7)

* [changed by @nriley] Dropped support for OS X 10.9 and earlier
* [changed by @winny-] Removed “Tired of Song” from default toolbar
* [added by @ericmason] Support for high quality, 192 Kbps MP3 streams
* [added by @obycode] Add distributed notification for state changes
* [added by @nriley] Only enable station menu items/buttons where appropriate (#240)
* [fixed by @jmjones88] Update to build with Xcode 7.3 and fix for OS X 10.11
* [fixed by @dwaite] Fix truncation at 1024 bytes of response, usually impacting the ability to log in (#244)
* [fixed by @reedloden] Update Sparkle and use SSL to retrieve Hermes’ appcast to address a Sparkle security vulnerability (#254)
* [fixed by @nriley] Make lyrics button work again (LyricWikia API change)
* [fixed by @nriley] Make Last.fm authorization work again (#242)
* [fixed by @nriley] Rename QuickMix to Shuffle to be consistent with current Pandora terminology (#201)
* [fixed by @nriley] Use monospaced numbers in OS X 10.11 for song progress
* [fixed by @nriley] Better handle errors when opening a connection
* [fixed by @nriley] Fix an error when handling media keys

# Version 1.2.6 (5/6/15)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.5...v1.2.6)

* [changed by @winny-] Dropped support for OS X 10.8 and earlier
* [changed by @winny-] Use Apple’s JSON parser instead of SBJSON (#213)
* [fixed by @nriley] Station sort-by-date works again (#209)
* [fixed by @Aahung] Toolbar “Stations” button’s text now correctly reads as “Stations” (#224)
* [added by @Aahung] Playback progress bar replaced with iTunes-like progress bar (#223)

# Version 1.2.5 (12/28/14)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.4...v1.2.5)

* [fixed by @nriley] Restore OS X 10.7 support

# Version 1.2.4 (12/26/14)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.3...v1.2.4)

* [fixed by @nriley] General UI cleanup of the seed editor and main Hermes window
* [added by @Djspaceg, @nriley] Play/pause menubar icons
* [changed by @winny-] Stop asking for donations

# Version 1.2.3 (11/9/14)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.2...v1.2.3)

* [fixed by @vadimpanin] Fix HTTPS proxy support (#193)
* [fixed by @cazierb] Fix issue with the Hermes menubar icon and the Yosemite dark theme (#198)
* [added by @winny-] Add menu item Window → Main Window ⌘1
* [changed by @winny-] Default to only show notifications for track change

# Version 1.2.2 (7/12/14)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.1...v1.2.2)

* [fixed by @gbooker] Always re-grab media keys after opening other app that uses media keys (#184)
* [changed by @winny-] Default to Notification Center type notifications
* [fixed by @winny-] Small improvements to logging and the login UI
* [added by @winny-, @nriley] Document keyboard shortcuts in [Documentation/KeyboardShortcuts.md](https://github.com/HermesApp/Hermes/blob/master/Documentation/KeyboardShortcuts.md)

# Version 1.2.1 (5/29/14)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.2.0...v1.2.1)

* [added by @winny-] Internal support to switch device partner logins. Currently uses
          Android for regular Pandora users, and Pandora One Desktop for
          Pandora One users.
* [fixed by @winny-] Set volume even if paused (#169).
* [fixed by @nriley, @winny-] Various UI improvements including sanity-checking login
          credentials and adding transparency to music note icon.
* [fixed by @nriley] Resolve issue with SPMediaKeyTap (media keys library) (#172).
* [added by @winny-] Show album art in non-Growl notifications on Mavericks.
* [fixed by @winny-] Issue where non-Growl notification clicked does not raise Hermes.
* [added by @winny-] Optional debug logging to `~/Library/Logs/Hermes/` enabled at startup
          — hold down Option (⌥) and look for ladybug emoji (🐞) in menubar.
* [fixed by @nriley, @winny-] Do not disable Like/Dislike in menu bar and Dock menu,
          instead simply show status using a checkmark — this way one may “undo” Like
          or Dislike from any menu item.

# Version 1.2.0 (4/4/14)

[Full changelog](https://github.com/HermesApp/Hermes/compare/v1.1.20...v1.2.0)

* [fixed] Always display the menubar on startup, thanks @nriley!
* [fixed] Several improvements to the menubar including reclaiming ⌘M for
          minimize, show liked status (#146), rename ambiguious menu items.
          Thanks @nriley!
* [added] Pause on Screen lock (Try Control-Shift-Power) (#154), thanks @Elemecca!
* [fixed] Spacebar always pauses even when drawer visible except when searching
          for a station (#150), thanks @winny-!
* [added] AppleScript variables to get current playback progress
          `playback position` and song length `current song duration`
          (#157) Thanks @winny-!
* [fixed] Preferences window now resizes to fit contents, shows current section
          title, cleaner layout. Thanks @nriley!
* [fixed] Do not show menubar when Hermes is a status bar item and expose
          functionality in status bar item dropdown menu (#134), thanks @nriley!
* [added] Show tooltips for now playing title, artist, and album. Thanks @nriley!
* [fixed] Only show display current song in Notification Center. Thanks @winny-!
* [fixed] Support PC media keys (#122). Thanks @winny-!
* [fixed] The “Help” dropdown now has functionality. (Reported by @nriley)
          Thanks @winny- & @nriley!
* [fixed] Show authors and contributors in the “About” window. Also show links
          from the previously mentioned “Help” dropdown menu. (Reported by
          @nriley) Thanks @winny- & @nriley!

# Version 1.1.20 (9/16/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.19...v1.1.20)

This release entirely brought to you through the fantastic contributions of
@nriley.

* [added] Various improvements to managing the drawer of songs/stations, thanks
          @nriley!
* [fixed] Don’t switch to the discrete graphics card (#144), thanks to @nriley

# Version 1.1.19 (9/4/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.18...v1.1.19)

* [fixed] Actually fixed for 10.6 (retargeting AudioStreamer as well as SBJson),
          thanks again to @nriley

# Version 1.1.18 (9/3/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.17...v1.1.18)

* [added] Pause playback on screensaver start, optionally resume on stop, thanks
          @winny-!
* [added] New shortcuts for increasing/decreasing volume, thanks @winny-!
* [added] The window title is now the station title, thanks @nriley!
* [added] The progress bar is no longer animated and fits the theme better,
          thanks @nriley!
* [added] The album art is now clickable to zoom it and get a nicer preview,
          thanks @nriley!
* [fixed] Now runs on 10.6 again, thanks @nriley!

# Version 1.1.17 (7/30/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.16...v1.1.17)

* [fixed] No longer crashes when switching stations

# Version 1.1.16 (7/30/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.15...v1.1.16)

* [fixed] Increase stability when running for a long time
* [fixed] Other various bug fixes

# Version 1.1.15 (6/26/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.14...v1.1.15)

* [fixed] The nrating property for AppleScript has been fixed, thanks to @dlh
* [fixed] The state of buttons in both the drawer and main playback view are now
          better synchronized with each other, thanks to @dlh
* [fixed] Attempted to fix issues associated with a few assertions cropping up

# Version 1.1.14 (4/10/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.13...v1.1.14)

* [added] Added the option of using a black/white status bar icon instead of one
          which has color, thanks to @bradmkjr
* [fixed] Be sure a blank process name doesn’t show up in the Activity Monitor
* [fixed] The ⌘H shortcut now works again

# Version 1.1.13 (1/4/13)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.12...v1.1.13)

* [added] On 10.7+, use a thumbs-up emoji, thanks to @kirbylover4000
* [added] Option to have Hermes be purely a status-bar app (not in dock)
* [added] Thumbs up/down are now selectable buttons (which means they can be
          de-selected to remove feedback)
* [added] There is now an option to have Hermes always be on top of all other
          windows
* [added] Hermes automatically retries failed requests in addition to showing an
          error screen
* [fixed] Don’t show extra labels on the auth view by default, thanks to
          @kirbylover4000
* [fixed] Resolve a problem where the application could not be quit through
          applescript

# Version 1.1.12 (11/11/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.11...v1.1.12)

* [fixed] Fix a few crashes related to loading lists of songs saved from the
          last session of Hermes
* [fixed] Song notifications are now only displayed if the song is actually
          playing
* [added] Changed how liked songs are displayed in notifications, thanks to
          @viveksjain

# Version 1.1.11 (9/21/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.10...v1.1.11)

* [fixed] Do not drop the last few seconds of audio periodically
* [fixed] Resume in the middle of a song across application instances fixed

# Version 1.1.10 (8/10/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.9...v1.1.10)

* [added] Ability to sort stations list by name or date of creation
* [added] Receive notifications through Growl or Mountain Lion’s new
          Notification Center
* [fixed] Reduced memory retained over time

# Version 1.1.9 (7/30/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.8...v1.1.9)

* [fixed] Last.fm scrobbling time stamps are now correct again
* [fixed] Fix a duplication of a UI item in preferences

# Version 1.1.8 (7/30/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.7...v1.1.8)

* [added] The internal timer to update the GUI is now paused when the
          application is not visible
* [added] Respect permissions on pandora stations for liking/disliking songs,
          renaming stations, and adding seeds to stations
* [added] Growl notifications now indicate whether a song is liked
* [fixed] The tooltip on the station/history toolbar item now correctly reflects
          the current state of the button

# Version 1.1.7 (7/4/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.6...v1.1.7)

* [added] New UI for viewing song history in a drawer instead of a popup
* [added] Stations can now be created by genre as well as by seed
* [added] Button in history view to view the lyrics of a song
* [fixed] Disliking the current song in the history skips it and moves on

# Version 1.1.6 (6/17/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.5...v1.1.6)

* [added] Add an option to not proxy audio streams because it’s not necessarily
          required by Pandora. Thanks to @osener for the suggestion.
* [fixed] Switching stations no longer plays two songs

# Version 1.1.5 (6/16/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.4...v1.1.5)

* [added] Proxy configuration for just the Hermes application. Be aware that
          software updates will still go through the system proxy instead of the
          Hermes-configured proxy
* [added] If network connectivity is lost, and then regained, automatically
          resume playback if playback was previously happening.
* [fixed] Improve error handling in cases of intermittent network connectivity
          by providing a way to maintain listening to the last song as soon as
          the network connection is restored
* [fixed] An assertion no longer trips when re-authenticating with Pandora
* [misc ] massive internal cleanup across the code base

# Version 1.1.4 (6/5/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.3...v1.1.4)

* [added] Preferences for tweaking how software update works
* [fixed] Toolbar items no longer randomly disable themselves
* [fixed] Fix a bug fetching songs from pandora with bad formats specified

# Version 1.1.3 (6/2/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.2...v1.1.3)

* [added] When an error happens because the network is having trouble, there is
          now a button to retry the last request
* [fixed] Stations no longer randomly remove themselves when a new
          authentication token is fetched

# Version 1.1.2 (5/26/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.1...v1.1.2)

* [added] Remember stations drawer width across application restarts
* [added] Keyboard shortcut to edit a station (⇧+⌘+d)
* [fixed] General UI tweaks for better quality and a better application
* [fixed] When deletion of a seed fails, have a better notification
* [fixed] Error handling (reauthentication and during authentication) working
          again

# Version 1.1.1 (5/20/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.1.0...v1.1.1)

* [added] New UI for editing a station
* [fixed] Fix an issue where non-Pandora One users couldn’t play more than four
          songs without a crash happening, thanks to @viveksjain

# Version 1.1.0 (5/18/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.22...v1.1.0)

* [added] Move to using Pandora’s JSON API instead of the XMLRPC one in hopes of
          being more stable and requiring fewer updates
* [added] After creating a station, immediately begin playback of the station
* [added] Preference option for high/medium/low quality audio
* [fixed] Always make sure that toolbar items are enabled when a new song plays
* [fixed] Ensure the station drawer opens when there’s no saved station

# Version 1.0.22 (4/27/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.21...v1.0.22)

* [added] Preference option to not send liked tracks as “loved” to last.fm,
          thanks to @tresni
* [fixed] Updated to Pandora’s v34 protocol
* [fixed] `track.unlove` now properly sent to last.fm
* [fixed] Fixed a memory leak with the dock menu opening/closing

# Version 1.0.21 (3/22/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.20...v1.0.21)

* [added] Fine-grained control for which Growl notifications are received,
          configurable through Hermes’ preferences, or also through Growl’s
* [added] Tell last.fm when a track starts playing via the
          `track.updateNowPlaying` API method, thanks to @tresni
* [added] Tell last.fm about liked/disliked tracks via the `track.love` and
          `track.unlove` methods, thanks to @ginader for the idea
* [added] Add a preference for only scrobbling liked tracks, thanks to
          @ginader for the idea.
* [added] Dock menu now displays the playing song, if there is one, thanks to
          @viveksjain
* [added] Preserve stations drawer state across launches, thanks to @viveksjain
* [fixed] Fixed scrobbling in some situations where the saved session key was
          wrong, thanks to @tresni
* [fixed] Growl notifications now globally coalesce, instead of on a song-level,
          thanks to @viveksjain

# Version 1.0.20 (2/23/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.19...v1.0.20)

* [added] Keyboard shortcut to play selected station, bring Hermes to the front
          as selected application, and to show history thanks to @Sheyne
* [fixed] Pandora wants all requests over https now

# Version 1.0.19 (2/17/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.18...v1.0.19)

* [fixed] AppleScript “tired of song” now actually performs the right action,
          thanks to @tresni
* [fixed] Creating stations clears the search field from the previous search
* [fixed] Updated Growl to 1.3, thanks to @terinjokes

# Version 1.0.18 (1/12/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.17...v1.0.18)

* [fixed] Parsing error messages works again to correctly refetch a token with
          Pandora

# Version 1.0.17 (1/10/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.16...v1.0.17)

* [fixed] Don’t use “https” on most API requests to Pandora
* [fixed] Use smaller request IDs to appease Pandora

# Version 1.0.16 (1/6/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.15...v1.0.16)

* [added] Dock icon menu now has options for play/pause/like/dislike
* [added] AppleScript for getting/setting the station playing
* [added] AppleScript for getting the current song and attributes about it

# Version 1.0.15 (12/17/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.14...v1.0.15)

* [fixed] Volume control works again

# Version 1.0.14 (12/15/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.13...v1.0.14)

* [added] `tired of song` command in AppleScript
* [added] `current volume` read/write attribute in AppleScript
* [added] `unmute` command in AppleScript
* [added] `playback state` read/write attribute in AppleScript
* [fixed] A few memory leaks have been resolved
* [fixed] Use Pandora’s `sync` API for real

# Version 1.0.13 (11/20/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.12...v1.0.13)

* [added] Broadcast new songs with NSDistributedNotificationCenter so programs
  can listen in if they’d like. The notification name is `hermes.song` and the
  object sending the notification is `hermes`
* [added] The stations drawer is now manually collapsible and preserves state
  when the window loses focus
* [added] AppleScript support. See the
  [README](https://github.com/alexcrichton/hermes/blob/master/README.md) for
  more information
* [fixed] Don’t use `@throw`, it doesn’t play nicely with ARC. Fixes a crash
  on startup if first time running.

# Version 1.0.12 (11/18/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.11...v1.0.12)

* [fixed] Logging out and then back in works much better now

# Version 1.0.11 (11/16/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.10...v1.0.11)

* [added] Support OSX 10.6
* [fixed] Fix an intermittent crash occuring upon resume.

# Version 1.0.10 (11/9/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.9...v1.0.10)

* [fixed] Pandora prefers SSL connections
* [fixed] Enable the logout menu item

# Version 1.0.9 (11/9/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.8...v1.0.9)

* [fixed] Pandora protocol version bump

# Version 1.0.8 (10/31/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.7...v1.0.8)

* [fixed] Scrobbler correctly gets session key from user’s keychain
* [added] Growl notifications occur when songs play (can be turned off)
* [added] Growl and media keys turned on by default
* [added] History view for seeing past songs and liking/disliking past songs
* [added] On application restore, don’t start playing music

# Version 1.0.6 (9/21/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.5...v1.0.6)

* [fixed] Updated to Pandora’s v32 API (no changes yet)

# Version 1.0.5 (8/16/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.4...v1.0.5)

* [added] Much better error handling/reporting
* [added] App now slides between windows instead of appearing
* [fixed] Much more developer-friendly interface design
* [fixed] Addressed some issues with receiving a station list from Pandora
* [changed] Supporting 10.7+ now

# Version 1.0.4 (7/9/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.3...v1.0.4)

* [fixed] Correctly escape characters when submitting to last.fm
* [fixed] Removed some memory leaks in FMEngine
* [fixed] Removed memory leaks in Scrobbler
* [fixed] Removed multiple release bug when deleting a station
* [fixed] Smoother updating of progress on the time lapse bar
* [fixed] Updated to new Pandora API version
* [added] Don’t log debug messages in the Release build target
* [added] Better resuming of interrupted streams
* [added] Updated for Xcode 4

# Version 1.0.3 (4/29/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.2...v1.0.3)

* [fixed] Updated the JSON framework to support OSX 10.5+

# Version 1.0.2 (4/29/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.1...v1.0.2)

* [added] Scrobbling via last.fm
* [added] Binding of media keys on apple keyboards
* [added] Preferences pane for tweaking configuration

# Version 1.0.1 (4/28/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.0...v1.0.1)

* [fixed] Pandora crypto keys updated to newer versions
* [fixed] Pandora protocol now uses v30 (no API changes, however)

# Version 1.0.0 (3/25/11)

* Initial release
