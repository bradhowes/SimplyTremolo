// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DelayBuffer.h"
#import "SimplyTremoloFramework/SimplyTremoloFramework-Swift.h"
#import "KernelEventProcessor.h"
#import "LFO.h"

class SimplyTremoloKernel : public KernelEventProcessor<SimplyTremoloKernel> {
public:
    using super = KernelEventProcessor<SimplyTremoloKernel>;
    friend super;

    SimplyTremoloKernel(const std::string& name)
    : super(os_log_create(name.c_str(), "SimplyTremoloKernel")), lfo_()
    {
        lfo_.setWaveform(LFOWaveform::sinusoid);
    }

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
        super::startProcessing(format, maxFramesToRender);
        initialize(format.channelCount, format.sampleRate);
    }

    void initialize(int channelCount, double sampleRate) {
        lfo_.initialize(sampleRate, rate_);
    }

    void stopProcessing() { super::stopProcessing(); }

    void setParameterValue(AUParameterAddress address, AUValue value) {
        double tmp;
        switch (address) {
            case FilterParameterAddressRate:
                if (value == rate_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "rate - %f", value);
                rate_ = value;
                lfo_.setFrequency(rate_);
                break;
            case FilterParameterAddressDepth:
                tmp = value / 200.0; // !!!
                if (tmp == depth_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "depth - %f", tmp);
                depth_ = tmp;
                break;
            case FilterParameterAddressSquareWave:
                squareWave_ = value > 0.0 ? true : false;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "squareWave: %d", squareWave_);
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
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const {
        switch (address) {
            case FilterParameterAddressRate: return rate_;
            case FilterParameterAddressDepth: return depth_ * 200.0; // !!!
            case FilterParameterAddressSquareWave: return squareWave_ * 1.0;
            case FilterParameterAddressDryMix: return dryMix_ * 100.0;
            case FilterParameterAddressWetMix: return wetMix_ * 100.0;
        }
        return 0.0;
    }

private:

    void doParameterEvent(const AUParameterEvent& event) { setParameterValue(event.parameterAddress, event.value); }

    void doRendering(std::vector<AUValue const*> ins, std::vector<AUValue*> outs, AUAudioFrameCount frameCount) {
        auto lfoState = lfo_.saveState();
        for (int channel = 0; channel < ins.size(); ++channel) {
            auto& inputs = ins[channel];
            auto& outputs = outs[channel];
            if (channel > 0) lfo_.restoreState(lfoState);
            for (int frame = 0; frame < frameCount; ++frame) {
                auto inputSample = inputs[frame];
                auto modulation = lfo_.valueAndIncrement();
                auto outputSample = (modulation + 1) * depth_ * inputSample;
                outputs[frame] = dryMix_ * inputSample + wetMix_ * outputSample;
            }
        }
    }

    void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

    double rate_;
    double depth_;
    bool squareWave_;
    double dryMix_;
    double wetMix_;
    LFO<double> lfo_;
};
