# Releasing Hermes

You can make the following types of releases:

* Private releases, generally only to one or two people, which don't get distributed through the Web site
* Public beta releases, which do get distributed through the Web site
* Final releases

The work involved in each release type generally encompasses those above it.

## If you need to make a public release

Assuming your account can commit to the Hermes repository, to make a public beta or final release, you will also need an access token for the GitHub API, which you can generate [here](https://github.com/settings/tokens/) — click **Generate new token**, then set the scope to **repo**.  Make sure to save the key locally as it only gets shown to you at the time of generation.

Before making a final release, you will need the following structure on disk:

- `Hermes/` — `git clone git@github.com:HermesApp/Hermes`
- `hermes-pages/` — `git clone git@github.com:HermesApp/hermesapp.github.io hermes-pages`
- `hermes.key` — DSA private key for Sparkle updates (obtain from a project administrator)

Also for final releases, you also need to install the `redcarpet` Ruby gem in order to process the Markdown-formatted changelog into HTML.  Just `sudo gem install redcarpet`, or do something more sophisticated if you're better at Ruby than I am.

## About version numbers

Hermes uses Apple generic versioning, maintained by `agvtool`.  Each release of Hermes has two versions.

The **project version** is a floating-point number which increases with each release.  It is `$CURRENT_PROJECT_VERSION` during the build process and `CFBundleVersion` in `Info.plist`.

The **marketing version** is formatted like `x.y.z`, possibly with a letter-number suffix for prerelease versions, and is `CFBundleShortVersionString` in `Info.plist`.  It is what most users consider to be the version.

Both of these show up in Hermes’ About box, for example "Version 1.2.7 (2040)".

## Always bump before you release

Every time you distribute a new version of Hermes beyond the confines of your computer(s), first `bump` the project version as follows:

    % cd Hermes/
    % agvtool bump -all
    Setting version of project Hermes to: 
        2041.

    Also setting CFBundleVersion key (assuming it exists)

    Updating CFBundleVersion in Info.plist(s)...

    Updated CFBundleVersion in "Hermes.xcodeproj/../Resources/Hermes-Info.plist" to 2041

## Making a private release

    % cd Hermes/
    % make archive
    [...]
    >>> INFO: Building archive [...]/Hermes/build/Release/Hermes-1.2.7.zip

    ** BUILD SUCCEEDED **

The Hermes zip file is then ready for distribution.

## Making a beta release

First, make sure you've committed and pushed all your intended changes to GitHub.

Create an archive (`make archive` as above) and *test it* before proceeding.  Fix, commit, push and repeat until you're satisfied.

Pick a marketing version for your beta release and use `agvtool` to set it (in addition to `bump`ing the project version as discussed above).

    % cd Hermes/
    % agvtool mvers -terse1
    1.2.7
    % agvtool new-marketing-version 1.2.8b1
    Setting CFBundleShortVersionString of project Hermes to: 
        1.2.8b1.

    Updating CFBundleShortVersionString in Info.plist(s)...

    Updated CFBundleShortVersionString in "Hermes.xcodeproj/../Resources/Hermes-Info.plist" to 1.2.8b1

Next, make sure the [changelog](https://github.com/HermesApp/Hermes/blob/master/CHANGELOG.md) is up to date.  Create a section for the next non-beta version if needed, include "unreleased" for the release date, link to the Git history between the last `v` tag and `HEAD` and document the meaningful changes (see an example [here](https://raw.githubusercontent.com/HermesApp/Hermes/308d81f7b16540742e6398371cde38e46b14755f/CHANGELOG.md)).

Now you're ready to create and upload the release. You'll need your GitHub access token.

    % make upload-release GITHUB_ACCESS_TOKEN=[...]
    [...]
    >>> INFO: Building archive [...]/Hermes/build/Release/Hermes-1.2.8b1.zip
    >>> INFO: Not signing for Sparkle distribution for prerelease version
    >>> INFO: Not building versions.xml fragment for prerelease version
    >>> INFO: Not updating website for prerelease version
    >>> INFO: Creating release for 1.2.8b1
    [...]
    >>> INFO: Uploading Hermes-1.2.8b1.zip to GitHub
    [...]

    ** BUILD SUCCEEDED **

Your Web browser will open to a draft release (unpublished, with no corresponding Git tag yet). Try out the download, make sure it's working and so forth. If it doesn't work, click **Delete**, make changes and commit as usual.

Once you're convinced the download works, make and push a commit to mark the release.  

    % git commit -am v$(agvtool mvers -terse1)
    [master 0f6078f] v1.2.8b1
    [...]
    % git push
    [...]

At this point, `master` on GitHub should contain the bits you want to release.  Now, back in your browser, click **Edit draft** then **Publish release**. This will create a Git tag pointing at `master` named the same as the release — `v` followed by the marketing version.

Finally, pull your newly created tag from GitHub with `git pull -t`.

## Making a final release

Then follow the instructions above under **Making a beta release** to commit and push your changes, make and test an archive, use `agvtool` to bump the project version and set the marketing version, and upload your release.  When editing the [changelog](https://github.com/HermesApp/Hermes/blob/master/CHANGELOG.md), create a section for the version you're about to release if it doesn't already exist, link to the Git history between `v` tags, and add today's date.

    % make upload-release GITHUB_ACCESS_TOKEN=[...]
    [...]
    >>> INFO: Building archive [...]/Hermes/build/Release/Hermes-1.2.8.zip
    >>> INFO: Signing for Sparkle distribution
    >>> INFO: Building versions.xml fragment
    >>> INFO: Updating website in [...]/hermes-pages
    + ruby [...]/hermes-pages/_config/release.rb 1.2.8 [...]/Hermes/build/Release/versions.xml [...]/Hermes/CHANGELOG.md 10.10
    ==>>> INFO: Updating Hermes release information in release.yml to 1.2.8
    ==>>> INFO: Injecting new xml fragment ([...]/Hermes/build/Release/versions.xml) into [...]/hermes-pages/versions.xml
    ==>>> INFO: Rendering changelog ([...]/Hermes/CHANGELOG.md -> [...]/hermes-pages/changelog.html)
    + set +x
    >>> INFO: Creating release for 1.2.8
    [...]
    >>> INFO: Uploading Hermes-1.2.8.zip to GitHub
    [...]

As you see above, this will also update your local copy of the Sparkle appcast and the public Web site, but not make any changes yet.

Finally, `cd` into the `hermes-pages` repository, commit and push to update the Web site.
