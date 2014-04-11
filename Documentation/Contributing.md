Contributing
============

Style
-----

Follow the general style of Apple's official work. Some important points:

* We use two-space indentation. Worry not, XCode knows!
* Don't introduce unnecessary whitespace in message passing or function
  declarations.
* Add space after control statements (`if (aCondition)`, not
  `if(aCondition)`).
* Always include braces with control flow statements.
* Prefer English readable variables to short single letters names — even for
  throw away variables.
* Do not use parenthesis in the `return` statement (`return playbackStatus;`,
  not `return (playbackStatus);`).
* Pointer operators have a space on their left, and the variable name on their
  right (`NSString *userName`, not `NSString* userName`).

When in doubt, do what Apple does.
