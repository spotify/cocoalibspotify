# CocoaLibSpotify #

CocoaLibSpotify is an Objective-C wrapper around our libspotify library. It provides easy access to libspotify's features in a friendly, KVC/O compliant Objective-C wrapper.

CocoaLibSpotify requires libspotify.framework, which isn't included in the repository. The Mac Framework and iOS Library  Xcode projects include a build step to download and unpack it from developer.spotify.com automatically. If this fails for some reason, download it manually from developer.spotify.com and unpack it into the project folder.

## Note for CocoaLibSpotify Users Prior To LibSpotify 10 ##

The playlist API changed in CocoaLibSpotify for libspotify 10. `SPPlaylist` no longer has a `tracks` property, but instead has `items`, which can contain tracks, albums, artists or playlists. Please consult the documentation for more information. 

## Building -  Mac OS X ##

The Xcode project was built in Xcode 4.0, but should also work fine in Xcode 3.2.x.

The built CocoaLibSpotify.framework contains libspotify.framework as a child framework. Sometimes, Xcode gives build errors complaining it can't find <libspotify/api.h>. If you get this, manually add the directory libspotify.framework is in to your project's "Framework Search Paths" build setting. For example, if you're building the CocoaLibSpotify project alongside your application as an embedded Xcode project then copying it into your bundle, you'd have this:

`$CONFIGURATION_BUILD_DIR/CocoaLibSpotify.framework/Versions/Frameworks`

Otherwise, you'd point to the downloaded libspotify.framework manually, something like this:

`../../libspotify-10.1.16-Darwin-universal`

## Building - iOS ##

The built libCocoaLibSpotify contains libspotify internally as a static library, as well as all of the required header files in a directory called "include".

When including libCocoaLibSpotify in your application, you must also link to the following frameworks:

- SystemConfiguration.framework
- CFNetwork.framework
- libstdc++

In addition, you must add the following two items to the "Other Linker Flags" build setting:

- -all_load
- -ObjC

If you're building the CocoaLibSpotify project alongside your application as an embedded Xcode project then linking it with your application in a build step, you can tell Xcode where the header files are by adding the following setting to the "Framework Search Paths" build setting of your project:

`$CONFIGURATION_BUILD_DIR/include`

Otherwise, you can simply add all of the header files to your project manually. 

Once everything is set up, simply import the following header to get started with CocoaLibSpotify!

`#import "CocoaLibSpotify.h"`

## Playback Helper Classes ##

If you want to use the provided playback helper classes, you also need to link to the following framworks in your project:

Mac

- CoreAudio.framework
- AudioUnit.framework

iOS

- CoreAudio.framework
- AudioToolbox.framework
- AVFoundation.framework

## Documentation ##

The headers of CocoaLibSpotify are well documented, and we've provided an Xcode DocSet to provide documentation right in Xcode. With these and the sample projects, you should have everything you need to dive right in!

## Contact ##

If you have any problems or find any bugs, see our GitHub page for known issues and discussion. Otherwise, we may be available in irc://irc.freenode.net/spotify. 