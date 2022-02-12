// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <string>

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#import "BoolParameter.hpp"
#import "DelayBuffer.hpp"
#import "EventProcessor.hpp"
#import "MillisecondsParameter.hpp"
#import "LFO.hpp"
#import "PercentageParameter.hpp"

/**
 The audio processing kernel that generates a "flange" effect by combining an audio signal with a slightly delayed copy
 of itself. The delay value oscillates at a defined frequency which causes the delayed audio to vary in pitch due to it
 being sped up or slowed down.
 */
class Kernel : public EventProcessor<Kernel> {
public:
  using super = EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   */
  Kernel(const std::string& name)
  : super(os_log_create(name.c_str(), "Kernel"))
  {
    lfo_.setWaveform(LFOWaveform::sinusoid);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void setRenderingFormat(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
    super::setRenderingFormat(format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate, maxFramesToRender);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value);

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const;

private:

  void initialize(int channelCount, double sampleRate, AUAudioFrameCount maxFramesToRender) {
    lfo_.setSampleRate(sampleRate);
    attenuationBuffer_.resize(maxFramesToRender * 2, 0.0);
  }

  void setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration);

  void setParameterFromEvent(const AUParameterEvent& event) {
    if (event.rampDurationSampleFrames == 0) {
      setParameterValue(event.parameterAddress, event.value);
    } else {
      setRampedParameterValue(event.parameterAddress, event.value, event.rampDurationSampleFrames);
    }
  }

  void generateModulations(AUAudioFrameCount frameCount, bool odd90) {

    // LFO ranges from [-1.0, +1] (bipolar). Convert to unipolar and multiply by depth to get a scaled
    // attenuation value. We subtract that value from 1.0 so that at small depth values there is not much
    // attenuation, but at higher values the affect on the amplitude becomes much more pronounced.
    //
    // If enabled, we calculate attenuations using the out-of-phase LFO value. The two are not interleaved; the "even"
    // attenuations are always in positions [0, frameCount) and the "odd" attenuations are at
    // [frameCount, 2 x frameCount)
    //
    size_t oddPos = odd90 ? frameCount : 0;
    for (auto index = 0; index < frameCount; ++index) {
      auto depth = depth_.frameValue();
      auto wet = depth_.frameValue();
      auto dry = depth_.frameValue();

      // output = input * dry + input * wet * (1.0 - LFO * depth)
      //        = input * (dry + wet - wet * LFO * depth)
      // attenuation = dry + wet - wet * LFO * depth
      //
      attenuationBuffer_[index] = dry + wet - wet * DSP::bipolarToUnipolar(lfo_.value()) * depth;
      if (oddPos > 0) {
        attenuationBuffer_[oddPos++] = dry + wet - wet * DSP::bipolarToUnipolar(lfo_.quadPhaseValue()) * depth;
      }

      lfo_.increment();
    }
  }

  void doRendering(std::vector<AUValue*>& ins, std::vector<AUValue*>& outs, AUAudioFrameCount frameCount) {
    bool odd90 = odd90_;
    vDSP_Stride stride{1};

    generateModulations(frameCount, odd90);
    for (int channel = 0; channel < ins.size(); ++channel) {
      auto& input = ins[channel];
      auto& output = outs[channel];

      // Attenuations for 'odd' channels when enabled are in the second half of the attenuation buffer.
      AUValue* attenuation = (odd90 && (channel & 1)) ? &(attenuationBuffer_[frameCount]) : &(attenuationBuffer_[0]);

      // Do vector multiply of the attenuation and the input samples. Store in the output buffer.
      vDSP_vmul(attenuation, stride, input, stride, output, stride, vDSP_Length(frameCount));
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

  PercentageParameter<AUValue> depth_;
  PercentageParameter<AUValue> dry_;
  PercentageParameter<AUValue> wet_;
  BoolParameter squareWave_;
  BoolParameter odd90_;
  std::vector<AUValue> attenuationBuffer_;
  LFO<AUValue> lfo_;
};
