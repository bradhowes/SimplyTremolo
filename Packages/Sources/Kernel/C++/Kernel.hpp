// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <iostream>
#import <string>

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#import "DSPHeaders/BusBuffers.hpp"
#import "DSPHeaders/DelayBuffer.hpp"
#import "DSPHeaders/EventProcessor.hpp"
#import "DSPHeaders/LFO.hpp"
#import "DSPHeaders/Parameters/Bool.hpp"
#import "DSPHeaders/Parameters/Milliseconds.hpp"
#import "DSPHeaders/Parameters/Percentage.hpp"

/**
 The audio processing kernel that generates a "flange" effect by combining an audio signal with a slightly delayed copy
 of itself. The delay value oscillates at a defined frequency which causes the delayed audio to vary in pitch due to it
 being sped up or slowed down.
 */
struct Kernel : public DSPHeaders::EventProcessor<Kernel> {
  using super = DSPHeaders::EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   */
  Kernel(std::string name) noexcept : super(), name_{name}, log_{os_log_create(name_.c_str(), "Kernel")}
  {
    lfo_.setWaveform(LFOWaveform::sinusoid);
    registerParameter(depth_);
    registerParameter(dry_);
    registerParameter(wet_);
    registerParameter(odd90_);
    registerParameter(squareWave_);
    registerParameter(lfo_.frequencyParameter());
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param busCount number of busses to support
   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) noexcept {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate, maxFramesToRender);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValuePending(AUParameterAddress address, AUValue value) noexcept;

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValuePending(AUParameterAddress address) const noexcept;

  /**
   Process an AU parameter value change from host or external device.

   @param address the address of the parameter to set
   @param value the new value to use
   @param duration how many samples to ramp from current to new value

   @returns duration value that was used
   */
  AUAudioFrameCount setParameterValueRamping(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Intialize the kernel with audio settings.

   @param channelCount number of audio channels to expect (usually 1 or 2).
   @param sampleRate the number of samples per second to render
   @param maxFramesToRender the maximum number of frames to render in one shot
   */
  void initialize(int channelCount, double sampleRate, AUAudioFrameCount maxFramesToRender) {
    lfo_.setSampleRate(sampleRate);
    modulations_.resize(maxFramesToRender * 2, 0.0);
  }

private:

  void doMIDIEvent(const AUMIDIEvent& midiEvent) noexcept {}

  bool doParameterEvent(const AUParameterEvent& event, AUAudioFrameCount duration) {
    setParameterValueRamping(event.parameterAddress, event.value, duration);
  }

  void doRenderingStateChanged(bool rendering) {}

  /**
   Perform rendering of samples. Generate all modulations first and then use vDSP routine to generate samples in one
   operation per channel.
   */
  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {
    if (frameCount == 1) [[unlikely]] {

      // Ramping case

      auto depth = depth_.frameValue();
      auto wet = wet_.frameValue();
      auto dry = dry_.frameValue();

      auto even = lfo_.value();
      auto odd = odd90_ ? lfo_.quadPhaseValue() : even;
      lfo_.increment();

      for (auto channel = 0; channel < ins.size(); ++channel) {
        *outs[channel]++ = filter(*ins[channel]++, depth, wet, dry, channel & 1 ? odd : even);
      }
    } else [[likely]] {
      auto depth = depth_.get();
      auto wet = wet_.get();
      auto dry = dry_.get();

      for (auto index  = 0; index < frameCount; ++index) {
        modulations_[index] = modulation(depth, wet, dry, lfo_.value());
        modulations_[index + frameCount] = modulation(depth, wet, dry, lfo_.quadPhaseValue());
        lfo_.increment();
      }

      auto evens = &modulations_[0];
      auto odds = &modulations_[frameCount];

      vDSP_Stride stride{1};
      for (int channel = 0; channel < ins.size(); ++channel) {
        auto& input = ins[channel];
        auto& output = outs[channel];
        auto modulations = (odd90_ && (channel & 1)) ? odds : evens;
        // Do vector multiply of the attenuation and the input samples. Store in the output buffer.
        vDSP_vmul(modulations, stride, input, stride, output, stride, vDSP_Length(frameCount));
        ins[channel] += frameCount;
        outs[channel] += frameCount;
      }
    }
  }

  static AUValue modulation(AUValue depth, AUValue wet, AUValue dry, AUValue lfo) {
    return (dry + wet * depth * (1.0 - DSPHeaders::DSP::bipolarToUnipolar(lfo))) / 2.0;
  }

  static AUValue filter(AUValue sample, AUValue depth, AUValue wet, AUValue dry, AUValue lfo) {
    return sample * modulation(depth, wet, dry, lfo);
  }

  DSPHeaders::Parameters::Percentage depth_;
  DSPHeaders::Parameters::Percentage dry_;
  DSPHeaders::Parameters::Percentage wet_;
  DSPHeaders::Parameters::Bool squareWave_;
  DSPHeaders::Parameters::Bool odd90_;
  std::vector<AUValue> modulations_;
  DSPHeaders::LFO<AUValue> lfo_;
  std::string name_;
  os_log_t log_;
};
