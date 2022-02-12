#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

void Kernel::setParameterValue(AUParameterAddress address, AUValue value) {
  os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "setParameterValue - %llul %f", address, value);
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequency(value, 0); break;
    case ParameterAddressDepth: depth_.set(value, 0); break;
    case ParameterAddressDry: dry_.set(value, 0); break;
    case ParameterAddressWet: wet_.set(value, 0); break;
    case ParameterAddressSquareWave: lfo_.setWaveform(value ? LFOWaveform::square : LFOWaveform::sinusoid); break;
    case ParameterAddressOdd90: odd90_.set(value); break;
  }
}

void Kernel::setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) {
  os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "setRampedParameterValue - %llul %f %d", address, value, duration);
  switch (address) {
    case ParameterAddressRate: lfo_.setFrequency(value, duration); break;
    case ParameterAddressDepth: depth_.set(value, duration); break;
    case ParameterAddressDry: dry_.set(value, duration); break;
    case ParameterAddressWet: wet_.set(value, duration); break;
    case ParameterAddressSquareWave: lfo_.setWaveform(value ? LFOWaveform::square : LFOWaveform::sinusoid); break;
    case ParameterAddressOdd90: odd90_.set(value); break;
  }
}

AUValue Kernel::getParameterValue(AUParameterAddress address) const {
  switch (address) {
    case ParameterAddressRate: return lfo_.frequency();
    case ParameterAddressDepth: return depth_.get();
    case ParameterAddressDry: return dry_.get();
    case ParameterAddressWet: return wet_.get();
    case ParameterAddressSquareWave: return lfo_.waveform() == LFOWaveform::square ? 1.0 : 0.0;
    case ParameterAddressOdd90: return odd90_.get();
  }
  return 0.0;
}
