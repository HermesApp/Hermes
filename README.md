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

2. AppleScript - not working yet, hopefully coming soon...

### Want something new/fixed?

1. [Open a ticket](https://github.com/alexcrichton/hermes/issues)! I'll get
   around to it soon, especially if it sounds appealing to me. I take all
   suggestions/feedback!

2. Take a stab at it yourself if you're brave. The project is meant to be built
   with Xcode 4. Just send me a pull request if you've got something fixed.
