Hermes
======

A [Pandora](http://www.pandora.com) client for OS X.

### Develop against Hermes

Thanks to the suggestions by [blalor](https://github.com/blalor), there's a few
ways you can develop against Hermes if you really want to.

1. `NSDistributedNotificationCenter` - Every time a new song plays, a
   notification is posted with the name `hermes.song` under the object `hermes`
   with `userInfo` as a dictionary representing the song being played. See
   [Song.m](https://github.com/alexcrichton/hermes/blob/master/Classes/Pandora/Song.m#L40)
   for the keys available to you.

2. AppleScript - here's an example script:

        tell application "Hermes"
          play          -- resumes playback, does nothing if playing
          pause         -- pauses playback, does nothing if not playing
          playpause     -- toggles playback between pause/play
          next song     -- goes to the next song
          get playback state
          set playback state to playing

          thumbs up     -- likes the current song
          thumbs down   -- dislikes the current song, going to another one
          tired of song -- sets the current song as being "tired of"

          raise volume  -- raises the volume partially
          lower volume  -- lowers the volume partially
          full volume   -- raises volume to max
          mute          -- mutes the volume
          unmute        -- unmutes the volume to the last state from mute

          -- integer 0 to 100 for the volume
          get current volume
          set current volume to 92

          -- Working with the current station
          set stationName to the current station's name
          set stationId to station 2's stationId
          set the current station to station 4

          -- Getting information from the current song
          set title to the current song's title
          set artist to the current song's artist
          set album to the current song's album
          ... etc
        end tell

### Want something new/fixed?

1. [Open a ticket](https://github.com/alexcrichton/hermes/issues)! I'll get
   around to it soon, especially if it sounds appealing to me. I take all
   suggestions/feedback!

2. Take a stab at it yourself if you're brave. Just send me a pull request if
   you've got something fixed. Here's some common things to do at the command
   line:

        make        # build everything
        make run    # build and run the application (logging to stdout)
        make dbg    # build and run inside gdb

        # Build with the 'Release' configuration instead of 'Debug'
        make CONFIGURATION=Release [run|dbg]

## License

Code is available under the [MIT
License](https://github.com/alexcrichton/hermes/blob/master/LICENSE).
