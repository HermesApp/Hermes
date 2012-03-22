# Version 1.0.21 (unreleased)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.20...master)

* [added] Fine-grained control for which growl notifications are received,
          configurable through Hermes' preferences, or also through Growl's
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

* [fixed] AppleScript "tired of song" now actually performs the right action,
          thanks to @tresni
* [fixed] Creating stations clears the search field from the previous search
* [fixed] Updated Growl to 1.3, thanks to @terinjokes

# Version 1.0.18 (1/12/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.17...v1.0.18)

* [fixed] Parsing error messages works again to correctly refetch a token with
          Pandora

# Version 1.0.17 (1/10/12)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.16...v1.0.17)

* [fixed] Don't use 'https' on most API requests to Pandora
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
* [fixed] Use Pandora's `sync` API for real

# Version 1.0.13 (11/20/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.12...v1.0.13)

* [added] Broadcast new songs with NSDistributedNotificationCenter so programs
  can listen in if they'd like. The notification name is `hermes.song` and the
  object sending the notification is `hermes`
* [added] The stations drawer is now manually collapsible and preserves state
  when the window loses focus
* [added] Applescript support. See the
  [README](https://github.com/alexcrichton/hermes/blob/master/README.md) for
  more information
* [fixed] Don't use `@throw`, it doesn't play nicely with ARC. Fixes a crash
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

* [fixed] Scrobbler correctly gets session key from user's keychain
* [added] Growl notifications occur when songs play (can be turned off)
* [added] Growl and media keys turned on by default
* [added] History view for seeing past songs and liking/disliking past songs
* [added] On application restore, don't start playing music

# Version 1.0.6 (9/21/11)

[Full changelog](https://github.com/alexcrichton/hermes/compare/v1.0.5...v1.0.6)

* [fixed] Updated to Pandora's v32 API (no changes yet)

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
* [added] Don't log debug messages in the Release build target
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
