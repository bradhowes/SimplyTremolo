#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

void Kernel::setParameterValuePending(AUParameterAddress address, AUValue value) noexcept {
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequencyPending(value); break;
    case ParameterAddressDepth: depth_.setPending(value); break;
    case ParameterAddressDry: dry_.setPending(value); break;
    case ParameterAddressWet: wet_.setPending(value); break;
    case ParameterAddressSquareWave: lfo_.setWaveform(value ? LFOWaveform::square : LFOWaveform::sinusoid); break;
    case ParameterAddressOdd90: odd90_.set(value, 0); break;
  }
}

AUAudioFrameCount Kernel::setParameterValueRamping(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "setParameterValueRamping - %llul %f %d", address, value, duration);
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequency(value, duration); return duration;
    case ParameterAddressDepth: depth_.set(value, duration); return duration;
    case ParameterAddressDry: dry_.set(value, duration); return duration;
    case ParameterAddressWet: wet_.set(value, duration); return duration;
    case ParameterAddressSquareWave: lfo_.setWaveform(value ? LFOWaveform::square : LFOWaveform::sinusoid); return 0;
    case ParameterAddressOdd90: odd90_.set(value, 0); return 0;
  }
  return 0;
}

AUValue Kernel::getParameterValuePending(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressRate: return lfo_.frequencyPending();
    case ParameterAddressDepth: return depth_.getPending();
    case ParameterAddressDry: return dry_.getPending();
    case ParameterAddressWet: return wet_.getPending();
    case ParameterAddressSquareWave: return lfo_.waveform() == LFOWaveform::square ? 1.0 : 0.0;
    case ParameterAddressOdd90: return odd90_.getPending();
  }
  return 0.0;
}
