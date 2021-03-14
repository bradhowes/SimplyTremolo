// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <string>
#import <vector>

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#import "DelayBuffer.h"
#import "SimplyTremoloFramework/SimplyTremoloFramework-Swift.h"
#import "KernelEventProcessor.h"
#import "LFO.h"

class SimplyTremoloKernel : public KernelEventProcessor<SimplyTremoloKernel> {
public:
    using super = KernelEventProcessor<SimplyTremoloKernel>;
    friend super;

    SimplyTremoloKernel(const std::string& name)
    : super(os_log_create(name.c_str(), "SimplyTremoloKernel")), lfo_(), scratchBuffer_{}
    {
        lfo_.setWaveform(LFOWaveform::sinusoid);
    }

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
        super::startProcessing(format, maxFramesToRender);
        initialize(format.channelCount, format.sampleRate, maxFramesToRender);
    }

    void stopProcessing() { super::stopProcessing(); }

    void setParameterValue(AUParameterAddress address, AUValue value) {
        AUValue tmp;
        bool tmpBool;
        switch (address) {
            case FilterParameterAddressRate:
                if (value == rate_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "rate - %f", value);
                rate_ = value;
                lfo_.setFrequency(rate_);
                break;
            case FilterParameterAddressDepth:
                tmp = value / 200.0; // Divide by factor of 2.0 now so we don't have to when we apply the modulation
                if (tmp == depth_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "depth - %f", tmp);
                depth_ = tmp;
                break;
            case FilterParameterAddressDryMix:
                tmp = value / 100.0;
                if (tmp == dryMix_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "dryMix - %f", tmp);
                dryMix_ = tmp;
                break;
            case FilterParameterAddressWetMix:
                tmp = value / 100.0;
                if (tmp == wetMix_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "wetMix - %f", tmp);
                wetMix_ = tmp;
                break;
            case FilterParameterAddressSquareWave:
                tmpBool = value > 0.0 ? true : false;
                if (tmpBool != squareWave_) {
                    squareWave_ = tmpBool;
                    os_log_with_type(log_, OS_LOG_TYPE_INFO, "squareWave: %d", squareWave_);
                    lfo_.setWaveform(squareWave_ ? LFOWaveform::square : LFOWaveform::sinusoid);
                }
                break;
            case FilterParameterAddressOdd90:
                odd90_ = value > 0.0 ? true : false;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "odd90: %d", odd90_);
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const {
        switch (address) {
            case FilterParameterAddressRate: return rate_;
            case FilterParameterAddressDepth: return depth_ * 200.0; // !!!
            case FilterParameterAddressDryMix: return dryMix_ * 100.0;
            case FilterParameterAddressWetMix: return wetMix_ * 100.0;
            case FilterParameterAddressSquareWave: return squareWave_ * 1.0;
            case FilterParameterAddressOdd90: return odd90_ * 1.0;
        }
        return 0.0;
    }

private:

    void generateModulations(AUAudioFrameCount frameCount, std::function<AUValue()> generator) {

        // LFO ranges from [-1.0, +1] (bipolar) so convert to unipolar (/ 2 already taken care of in depth_ setting)
        // Result then ranges from [0, 1], but if depth_ is set to zero, we want all dry signal. So, swap range to
        // [1.0, 0].
        //
        // NOTE: we have a strong guarantee from CoreAudio that frameCount <= scratchBuffer_.size(), so treat as an
        // array.
        for (auto index = 0; index < frameCount; ++index) {
            scratchBuffer_[index] = 1.0 - (generator() + 1.0) * depth_;
        }
    }

    void doRendering(std::vector<AUValue const*> ins, std::vector<AUValue*> outs, AUAudioFrameCount frameCount) {
        auto lfoState = lfo_.saveState();
        for (int channel = 0; channel < ins.size(); ++channel) {
            auto& inputs = ins[channel];
            auto& outputs = outs[channel];
            if (channel > 0) lfo_.restoreState(lfoState);

            // Generate modulations to apply to input samples.
            if (odd90_ && (channel & 1)) {
                generateModulations(frameCount, [this]{ return lfo_.quadPhaseValue();});
            }
            else {
                generateModulations(frameCount, [this]{ return lfo_.value();});
            }

            auto stride = vDSP_Stride(1);

            // Apply modulation to input samples - scratchBuffer_ *= inputs
            vDSP_vmul(scratchBuffer_.data(), stride,
                      inputs, stride,
                      scratchBuffer_.data(), stride,
                      vDSP_Length(frameCount));

            // Generate outputs - outputs = inputs * dryMix + scratchBuffer_ * wetMix
            vDSP_vsmsma(inputs, stride, &dryMix_,
                        scratchBuffer_.data(), stride, &wetMix_,
                        outputs, stride,
                        vDSP_Length(frameCount));
        }
    }

    void initialize(int channelCount, double sampleRate, AUAudioFrameCount maxFramesToRender) {
        lfo_.initialize(sampleRate, rate_);
        scratchBuffer_.resize(maxFramesToRender, 0.0);
    }

    void doParameterEvent(const AUParameterEvent& event) { setParameterValue(event.parameterAddress, event.value); }

    void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

    AUValue rate_;
    AUValue depth_;
    AUValue dryMix_;
    AUValue wetMix_;
    bool squareWave_;
    bool odd90_;
    LFO<AUValue> lfo_;
    std::vector<AUValue> scratchBuffer_;
};
