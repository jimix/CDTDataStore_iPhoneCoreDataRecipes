# Recipes

This project is a complete rip off of
[Apple's iPhoneCoreDataRecipes][recipe] sample application.  The
original is the initial `git` checkin and can also be found in branch
[apple/original](6eeb628). You can read the original [ReadMe.txt](ReadMe.txt).

## Summary of changes:

You can see all the changes by diffing agains `apple/original`.  The
chainges are confined to a few files:
- [Classes/RecipesAppDelegate.m](Classes/RecipesAppDelegate.m)
  - changes are denoted by `#ifdef NSIS_TYPE`
- [Classes/RecipeTableViewCell.h](Classes/RecipeTableViewCell.h) and [Classes/RecipeTableViewCell.m](Classes/RecipeTableViewCell.m)
  - simply to to make a private propery external
- [Classes/SyncTableViewController.h](Classes/SyncTableViewController.h) and [Classes/SyncTableViewController.m](Classes/SyncTableViewController.m)
  - New files that implements the Sync control tab
  - This also required changes to the project files, storyboard and assets

# Getting Started

This project depends on [CocoaPods][], so first make sure you have it
installed.

## Installing CocoaPods
### Step 1: Download CocoaPods

[CocoaPods][] is a dependency manager for Objective-C, which automates
and simplifies the process of using 3rd-party libraries. CocoaPods is
distributed as a ruby gem, and is installed by running the following
commands in Terminal.app:
```bash
$ sudo gem install cocoapods
$ pod setup
```
> Depending on your Ruby installation, you may not have to run as
> `sudo` to install the cocoapods gem.

### Step 2: Install Dependencies

A [Podfile](Podfile) exists and assumes that you are using the
`CDTDatastore` git tree.

You can obtain the correct copy using `git` from [ibmbaas][] like so:
```bash
$ git clone git@git.ibmbaas.com:jimix/cdtdatastore.git CDTDatastore
```
Description of the branches:
1. [iPhoneCoreDataRecipes](/jimix/iphonecoredatarecipes)
  1. `apple/original`: Original source from Apple ZIP file
  1. `master`: Which should be stable. ***You want to be on this
     one.***
  1. `jimix/CDTIncrementalStore`: My development branch with newer
      function.
1. [CDTDatastore](/jimix/cdtdatastore.git)
  1. `master`: tracks original [CDTDatastore][] `master`
  1. `CDTIncrementalStore`: "stable" version of work. ***You want to
     be on this one***.
  1. `jimix/CDTIncrementalStore`: My development branch with newer
      function.


The [Podfile](Podfile) expects that the `CDTDatastore` is located in
the parent directory and is called by that name.  If this is not the
case then change the `:path` following line accordingly:
```
pod "CDTDatastore", :path => "../CDTDatastore"
```

To install the necessary pods run:
```bash
$ pod install
```
This creates a workspace directory `Recipe.xcworkspace` that you can
use to start Xcode. From now on, be sure to always open the generated
Xcode workspace instead of the project file when building your
project:

    $ open Recipe.xcworkspace

# Hacking Tips
## Database Corruption

As you develop the code, you will inevitably corrupt the database.
This usually manifests it self with "uncaught exceptions about `nil`
objects. To solve this problem you can just delete the app from the
phone or simulator.

## Debugger Tips
Apple has provided [Technical Note TN2124][debugmagic] that is useful
for all sorts of things, but in particular it describes
`com.apple.CoreData.MigrationDebug` which can be set to `1` in your
Xcode scheme. [NSHipster][] has a great tutorial on how to do this and
more!


<!--- references -->

[recipe]: https://developer.apple.com/library/ios/samplecode/iPhoneCoreDataRecipes/Introduction/Intro.html "iPhoneCoreDataRecipes"
[cocoapods]: http://cocoapods.org "CocoaPods"
[debugmagic]: https://developer.apple.com/library/mac/technotes/tn2124/_index.html "Mac OS X Debugging Magic"
[nshipster]: http://nshipster.com/launch-arguments-and-environment-variables/ "Launch Arguments & Environment Variables"
[ibmbaas]: https://git.ibmbaas.com "ARL Git Lab"
[cdtdatastore]: https://github.com/cloudant/CDTDatastore "CDTDatastore on Github"

<!--  LocalWords:  iPhoneCoreDataRecipes checkin ARL
 -->
<!--  LocalWords:  repo NSIS ifdef endif CocoaPods sudo cocoapods
 -->
<!--  LocalWords:  Podfile CDTDatastore xcworkspace debugmagic cblite
 -->
<!--  LocalWords:  NSHipster nshipster ibmbaas jimix repos workspace
 -->
<!--  LocalWords:  CDTIncrementalStore Xcode
 -->
