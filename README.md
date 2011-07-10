Hermes
======

A [Pandora](http://www.pandora.com) client for OS X.

Why play music in really slow flash when you can play it with really fast non-flash?

## Development

This is an Xcode project, so point Xcode to the Hermes.xcodeproj here and build away.
This project is also meant for Xcode 4.

## Build a Release ZIP

Set your current target to the "Distribution" with the "Release" active
configuration, and then build the target. This will create a release zip
file in `build/Release`

There will also be a snippet of XML in `build/Release/versions.xml` to be
inserted into the [feed](http://alexcrichton.com/hermes/versions.xml) of
releases. The [website project](https://github.com/alexcrichton/hermes/tree/gh-pages)
has a [script](https://github.com/alexcrichton/hermes/blob/gh-pages/_config/release.rb)
for automatically inserting this into the XML file before a release.
