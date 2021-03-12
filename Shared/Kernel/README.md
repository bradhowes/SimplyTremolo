# Kernel Directory

This directory contains the files involved in doing the audio filtering and digital signal processing (DSP).

- [DSP](DSP) -- contains various C++ classes and functions that are useful when working with audio signals.

- [SimplyTremoloKernel](SimplyTremoloKernel.h) -- holds the main processing block that acts on individual audio samples.

- [SimplyTremoloKernelAdapter](SimplyTremoloKernelAdapter.h) -- _very_ tiny Objective-C wrapper for the
  [SimplyTremoloKernel](SimplyTremoloKernel.h) so that Swift can communicate with it. Note that most of the integration
  work is done elsewhere via AUParameter values. This adapter is mainly in charge of creating a new
  SimplyTremoloKernel and forwarding rendering requests to it.
