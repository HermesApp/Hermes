# Releasing Hermes

Create the following structure on disk:

- `Hermes/` — `git clone git@github.com:HermesApp/Hermes`
- `hermes-pages/` — `git clone git@github.com:HermesApp/hermesapp.github.io hermes-pages`
- `hermes.key` — DSA key for Sparkle signing (only if you need to make a final release; obtain from a project administrator)

You can make the following types of releases:

* Private releases, generally only to one or two people, which don't get distributed through the Web site
* Public beta releases, which do get distributed through the Web site
* Final releases

The work involved in each release type generally encompasses those above it.

Assuming your account can commit to the Hermes repository, to make a public beta or final release, you will also need an access token for the GitHub API, which you can generate [here](https://github.com/settings/tokens/) — click **Generate new token**, then set the scope to **repo**.  Make sure to save the key locally as it only gets shown to you at the time of generation.

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

Next, make and push a commit to clearly mark the release.

    % git commit -am $(agvtool mvers -terse1)
    [master 0f6078f] 1.2.8b1
    [...]
    % git push
    [...]

At this point, `master` on GitHub should contain the bits you want to release.

Now you're ready to create and upload the release. You'll need your GitHub access token.

    % make upload-release GITHUB_ACCESS_TOKEN=[...]
    >>> INFO: Building archive [...]/Hermes/build/Release/Hermes-1.2.8b1.zip
    >>> INFO: Not signing for Sparkle distribution for prerelease version
    >>> INFO: Not building versions.xml fragment for prerelease version
    >>> INFO: Not updating website for prerelease version
    >>> INFO: Creating release for 1.2.8b1
    [...]
    >>> INFO: Uploading Hermes-1.2.8b1.zip to GitHub
    [...]

    ** BUILD SUCCEEDED **

Your Web browser will open to a draft release (unpublished, with no corresponding Git tag yet). Try out the download, make sure it's working and so forth. If something is wrong, click **Delete** and try again. Otherwise, click **Edit draft** then **Publish release**. This will create a Git tag named the same as the release — `v` followed by the marketing version.

Finally, pull your newly created tag from GitHub with `git pull -t`.

## Making a final release

This is very much like making a beta release, except you need to update the changelog, Sparkle appcast and the public Web site (hermesapp.org).

Documentation forthcoming.