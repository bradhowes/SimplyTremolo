![CI](https://github.com/bradhowes/SimplyTremolo/workflows/CI/badge.svg?branch=main)
[![Swift 5.5](https://img.shields.io/badge/Swift-5.5-orange.svg?style=flat)](https://swift.org)
[![AUv3](https://img.shields.io/badge/AUv3-green.svg)](https://developer.apple.com/documentation/audiotoolbox/audio_unit_v3_plug-ins)
[![License: MIT](https://img.shields.io/badge/License-MIT-A31F34.svg)](https://opensource.org/licenses/MIT)

![](image.png)

# About SimplyTremolo

This is a simple audio plugin that generates a tremolo effect on iOS and macOS platforms. It uses the Apple 
Accelerate routine to perform phased attenuation for all frames in one shot.

The code was developed in Xcode 12.4 on macOS 11.2.1. I have tested on both macOS and iOS devices primarily in
GarageBand, but also using test hosts on both devices as well as the excellent
[AUM](https://apps.apple.com/us/app/aum-audio-mixer/id1055636344) app on iOS.

## Quick Guide

* Rate -- controls the low-frequency oscillator (LFO) that changes the amplitude of the input signal. The higher
  the number, the faster the oscillation.
* Depth -- controls how much of the signal is attenuated by the LFO. At its minimum value, there is no
  perceptible change. Going all the way to 100% means the volume will drop to zero when the LFO is at its
  largest value.
* Square -- normally LFO shape is a triangle wave, linearly rising and falling betwen -1.0 and 1.0. When this
  switch is enabled, the shape changes to something that just does -1.0 and 1.0 without any intermediate values.
  Odd and often noisy but might just be the effect you are after.
* Dry -- the amount of original signal that is used in the output signal.
* Wet -- the amount of the modified signal that is used in the output signal.
* Odd 90° -- oscillate all 'odd' channels with an LFO that is out-of-phase (for stereo, left is even and right
  is odd).

The row of buttons at the top of the host demonstration app let you play a prerecorded sample throught the
effect and try out different pre-installed or "factory" presets. Note that these controls are not present in the
audio unit itself, but the factory presets are available from within other AUv3 hosts such as GarageBand -- as
are user presets if the host supports them.

## AUv3 Compliance

This audio unit passes all
[auval](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/AudioUnitProgrammingGuide/AudioUnitDevelopmentFundamentals/AudioUnitDevelopmentFundamentals.html)
tests, so it should work in your AUv3-compatible host application:

```
% auval -v aufx trlo BRay
```

# Building

To successfully compile you will need to edit [Configuration/Common.xcconfig](Configuration/Common.xcconfig) and
change `DEVELOPMENT_TEAM` to hold your own Apple developer account ID so you can sign the binaries. You should
also adjust other settings as well to properly identify you and/or your company if you desire.

> :warning: You are free to use the code according to [LICENSE.md](LICENSE.md), but you must not replicate
> someone's UI, icons, samples, or any other assets if you are going to distribute your effect on the App Store.

There are additional values in this file that you really should change, especially to remove any risk of
collision with other AUv3 effects you may have on your system.

The script [newRelease.sh](newRelease.sh) automates generating new archive versions of both the macOS and iOS
apps and uploads them to the App Store if everything checks out. It uses the DEVELOPMENT_TEAM setting in the
`Common.xcconfig` to handle the authentication and signing.

# App Targets

The macOS and iOS apps are simple AUv3 hosts that demonstrate the functionality of the AUv3 component. In the
AUv3 world, an app serves as a delivery mechanism for an app extension like AUv3. When the app is installed, the
operating system will also install and register any app extensions found in the app.

The apps attempt to instantiate the AUv3 component and wire it up to an audio file player and the output
speaker. When it runs, you can play the sample file and manipulate the effects settings in the components UI.

# Code Layout

Each OS ([macOS](macOS) and [iOS](iOS)) have the same code layout:

* `App` -- code and configuration for the application that hosts the AUv3 app extension
* `Extension` -- code and configuration for the extension itself. It also contains the OS-specific UI layout
  definitions, but the controller for the UI is found in
  [Shared/User Interface/FilterViewController.swift](Shared/User%20Interface/FilterViewController.swift)
* `Framework` -- code configuration for the framework that contains the shared code

The [Shared](Shared) folder holds all of the code that is used by the above products. In it you will find the
files for the audio unit ([FilterAudioUnit](Shared/FilterAudioUnit.swift)), the user changeable parameters for
the audio unit ([AudioUnitParameters](Shared/AudioUnitParameters.swift)), and the audio processing "kernel"
written in C++ ([SimplyTremoloKernel](Shared/Kernel/SimplyTremoloKernel.h)).

There are adidtional details in the individual folders as well.
