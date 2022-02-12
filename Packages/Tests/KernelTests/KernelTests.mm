// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>
#import <iomanip>
#import <iostream>

#import "../../Sources/Kernel/C++/Kernel.hpp"

@import ParameterAddress;

@interface KernelTests : XCTestCase

@end

@implementation KernelTests

- (void)setUp {}

- (void)tearDown {}

- (void)testKernelParams {
  Kernel* kernel = new Kernel("blah");
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  kernel->setRenderingFormat(format, 100);

  kernel->setParameterValue(ParameterAddressRate, 30.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressRate), 30.0, 0.001);

  kernel->setParameterValue(ParameterAddressDepth, 10.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressDepth), 10.0, 0.001);

  kernel->setParameterValue(ParameterAddressDry, 50.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressDry), 50.0, 0.001);

  kernel->setParameterValue(ParameterAddressWet, 60.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressWet), 60.0, 0.001);

  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressSquareWave), 0.0, 0.001);
  kernel->setParameterValue(ParameterAddressSquareWave, 1.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressSquareWave), 1.0, 0.001);

  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressOdd90), 0.0, 0.001);
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);
  XCTAssertEqualWithAccuracy(kernel->getParameterValue(ParameterAddressOdd90), 1.0, 0.001);
}

- (void)testRendering_NoEffect {
  Kernel* kernel = new Kernel("blah");
  int samplesPerSecond = 20;
  // 20 samples per second in 2 channels
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:samplesPerSecond channels:2];
  // 20 maxFrames
  kernel->setRenderingFormat(format, samplesPerSecond);
  // 1 cycle per second for LFO
  kernel->setParameterValue(ParameterAddressRate, 1);
  // 100% attenuation
  kernel->setParameterValue(ParameterAddressDepth, 0.0);
  // 0% original signal
  kernel->setParameterValue(ParameterAddressDry, 100.0);
  // 100% processed signal
  kernel->setParameterValue(ParameterAddressWet, 0.0);
  // sine wave
  kernel->setParameterValue(ParameterAddressSquareWave, 1.0);
  // channel 1 is 90° out of phase with channel 2
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);

  std::vector<AUValue> in0;
  std::vector<AUValue> in1;

  auto theta = 3 * M_PI * 2.0 / samplesPerSecond;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    auto sample = sin(index * theta);
    in0.push_back(sample);
    in1.push_back(sample);
  }

  std::vector<AUValue> out0(samplesPerSecond, 0.0);
  std::vector<AUValue> out1(samplesPerSecond, 0.0);

  std::vector<AUValue*> inputs{in0.data(), in1.data()};
  std::vector<AUValue*> outputs{out0.data(), out1.data()};

  dump("in0", in0);
  dump("in1", in1);

  kernel->doRendering(inputs, outputs, samplesPerSecond);

  dump("out0", out0);
  dump("out1", out1);
  dump("att", kernel->attenuationBuffer_);

  AUValue epsilon = 1e-4;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    XCTAssertEqualWithAccuracy(in0[index], out0[index], epsilon);
    XCTAssertEqualWithAccuracy(in1[index], out1[index], epsilon);
  }
}

- (void)testRendering_AllWetNoDepth {
  Kernel* kernel = new Kernel("blah");
  int samplesPerSecond = 20;
  // 20 samples per second in 2 channels
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:samplesPerSecond channels:2];
  // 20 maxFrames
  kernel->setRenderingFormat(format, samplesPerSecond);
  // 1 cycle per second for LFO
  kernel->setParameterValue(ParameterAddressRate, 1);
  // 100% attenuation
  kernel->setParameterValue(ParameterAddressDepth, 0.0);
  // 0% original signal
  kernel->setParameterValue(ParameterAddressDry, 0.0);
  // 100% processed signal
  kernel->setParameterValue(ParameterAddressWet, 100.0);
  // sine wave
  kernel->setParameterValue(ParameterAddressSquareWave, 1.0);
  // channel 1 is 90° out of phase with channel 2
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);

  std::vector<AUValue> in0;
  std::vector<AUValue> in1;

  auto theta = 3 * M_PI * 2.0 / samplesPerSecond;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    auto sample = sin(index * theta);
    in0.push_back(sample);
    in1.push_back(sample);
  }

  std::vector<AUValue> out0(samplesPerSecond, 0.0);
  std::vector<AUValue> out1(samplesPerSecond, 0.0);

  std::vector<AUValue*> inputs{in0.data(), in1.data()};
  std::vector<AUValue*> outputs{out0.data(), out1.data()};

  dump("in0", in0);
  dump("in1", in1);

  kernel->doRendering(inputs, outputs, samplesPerSecond);

  dump("out0", out0);
  dump("out1", out1);
  dump("att", kernel->attenuationBuffer_);

  AUValue epsilon = 1e-4;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    XCTAssertEqualWithAccuracy(in0[index], out0[index], epsilon);
    XCTAssertEqualWithAccuracy(in1[index], out1[index], epsilon);
  }
}

- (void)testRendering_AllWetAllDry {
  Kernel* kernel = new Kernel("blah");
  int samplesPerSecond = 20;
  // 20 samples per second in 2 channels
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:samplesPerSecond channels:2];
  // 20 maxFrames
  kernel->setRenderingFormat(format, samplesPerSecond);
  // 1 cycle per second for LFO
  kernel->setParameterValue(ParameterAddressRate, 1);
  // 100% attenuation
  kernel->setParameterValue(ParameterAddressDepth, 0.0);
  // 0% original signal
  kernel->setParameterValue(ParameterAddressDry, 100.0);
  // 100% processed signal
  kernel->setParameterValue(ParameterAddressWet, 100.0);
  // sine wave
  kernel->setParameterValue(ParameterAddressSquareWave, 1.0);
  // channel 1 is 90° out of phase with channel 2
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);

  std::vector<AUValue> in0;
  std::vector<AUValue> in1;

  auto theta = 3 * M_PI * 2.0 / samplesPerSecond;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    auto sample = sin(index * theta);
    in0.push_back(sample);
    in1.push_back(sample);
  }

  std::vector<AUValue> out0(samplesPerSecond, 0.0);
  std::vector<AUValue> out1(samplesPerSecond, 0.0);

  std::vector<AUValue*> inputs{in0.data(), in1.data()};
  std::vector<AUValue*> outputs{out0.data(), out1.data()};

  dump("in0", in0);
  dump("in1", in1);

  kernel->doRendering(inputs, outputs, samplesPerSecond);

  dump("out0", out0);
  dump("out1", out1);
  dump("att", kernel->attenuationBuffer_);

  AUValue epsilon = 1e-4;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    XCTAssertEqualWithAccuracy(in0[index] * 2, out0[index], epsilon);
    XCTAssertEqualWithAccuracy(in1[index] * 2, out1[index], epsilon);
  }
}

- (void)testRendering_50Wet50DryAllDepth {
  Kernel* kernel = new Kernel("blah");
  int samplesPerSecond = 20;
  // 20 samples per second in 2 channels
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:samplesPerSecond channels:2];
  // 20 maxFrames
  kernel->setRenderingFormat(format, samplesPerSecond);
  // 1 cycle per second for LFO
  kernel->setParameterValue(ParameterAddressRate, 1);
  // 100% attenuation
  kernel->setParameterValue(ParameterAddressDepth, 100.0);
  // 0% original signal
  kernel->setParameterValue(ParameterAddressDry, 50.0);
  // 100% processed signal
  kernel->setParameterValue(ParameterAddressWet, 50.0);
  // sine wave
  kernel->setParameterValue(ParameterAddressSquareWave, 0.0);
  // channel 1 is 90° out of phase with channel 2
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);

  std::vector<AUValue> in0;
  std::vector<AUValue> in1;

  auto theta = 3 * M_PI * 2.0 / samplesPerSecond;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    auto sample = sin(index * theta);
    in0.push_back(sample);
    in1.push_back(sample);
  }

  std::vector<AUValue> out0(samplesPerSecond, 0.0);
  std::vector<AUValue> out1(samplesPerSecond, 0.0);

  std::vector<AUValue*> inputs{in0.data(), in1.data()};
  std::vector<AUValue*> outputs{out0.data(), out1.data()};

  dump(" in0", in0);
  dump(" in1", in1);

  kernel->doRendering(inputs, outputs, samplesPerSecond);

  dump("out0", out0);
  dump("out1", out1);
  dump("att", kernel->attenuationBuffer_);

  std::vector<AUValue> attenuation{
    0.750000, 0.672960, 0.602960, 0.547560, 0.512160, 0.500000, 0.512160, 0.547560, 0.602960, 0.672960,
    0.750000, 0.827040, 0.897040, 0.952440, 0.987840, 1.000000, 0.987840, 0.952440, 0.897040, 0.827040,
    0.500000, 0.512160, 0.547560, 0.602960, 0.672960, 0.750000, 0.827040, 0.897040, 0.952440, 0.987840,
    1.000000, 0.987840, 0.952440, 0.897040, 0.827040, 0.750000, 0.672960, 0.602960, 0.547560, 0.512160
  };

  AUValue epsilon = 1e-4;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    XCTAssertEqualWithAccuracy(in0[index] * attenuation[index], out0[index], epsilon);
    XCTAssertEqualWithAccuracy(in1[index] * attenuation[index + samplesPerSecond], out1[index], epsilon);
  }
}

- (void)testRendering_50Wet50DryAllDepthSquare {
  Kernel* kernel = new Kernel("blah");
  int samplesPerSecond = 20;
  // 20 samples per second in 2 channels
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:samplesPerSecond channels:2];
  // 20 maxFrames
  kernel->setRenderingFormat(format, samplesPerSecond);
  // 1 cycle per second for LFO
  kernel->setParameterValue(ParameterAddressRate, 1);
  // 100% attenuation
  kernel->setParameterValue(ParameterAddressDepth, 100.0);
  // 0% original signal
  kernel->setParameterValue(ParameterAddressDry, 50.0);
  // 100% processed signal
  kernel->setParameterValue(ParameterAddressWet, 50.0);
  // sine wave
  kernel->setParameterValue(ParameterAddressSquareWave, 1.0);
  // channel 1 is 90° out of phase with channel 2
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);

  std::vector<AUValue> in0;
  std::vector<AUValue> in1;

  auto theta = 3 * M_PI * 2.0 / samplesPerSecond;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    auto sample = sin(index * theta);
    in0.push_back(sample);
    in1.push_back(sample);
  }

  std::vector<AUValue> out0(samplesPerSecond, 0.0);
  std::vector<AUValue> out1(samplesPerSecond, 0.0);

  std::vector<AUValue*> inputs{in0.data(), in1.data()};
  std::vector<AUValue*> outputs{out0.data(), out1.data()};

  dump(" in0", in0);
  dump(" in1", in1);

  kernel->doRendering(inputs, outputs, samplesPerSecond);

  dump("out0", out0);
  dump("out1", out1);
  dump("att", kernel->attenuationBuffer_);

  std::vector<AUValue> attenuation{
    1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000,
    0.500000, 0.500000, 0.500000, 0.500000, 0.500000, 0.500000, 0.500000, 0.500000, 0.500000, 0.500000,
    1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 0.500000, 0.500000, 0.500000, 0.500000, 0.500000,
    0.500000, 0.500000, 0.500000, 0.500000, 0.500000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000
  };

  AUValue epsilon = 1e-4;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    XCTAssertEqualWithAccuracy(in0[index] * attenuation[index], out0[index], epsilon);
    XCTAssertEqualWithAccuracy(in1[index] * attenuation[index + samplesPerSecond], out1[index], epsilon);
  }
}

- (void)testRendering_100Wet0DryAllDepthSquare {
  Kernel* kernel = new Kernel("blah");
  int samplesPerSecond = 20;
  // 20 samples per second in 2 channels
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:samplesPerSecond channels:2];
  // 20 maxFrames
  kernel->setRenderingFormat(format, samplesPerSecond);
  // 1 cycle per second for LFO
  kernel->setParameterValue(ParameterAddressRate, 1);
  // 100% attenuation
  kernel->setParameterValue(ParameterAddressDepth, 100.0);
  // 0% original signal
  kernel->setParameterValue(ParameterAddressDry, 0.0);
  // 100% processed signal
  kernel->setParameterValue(ParameterAddressWet, 100.0);
  // sine wave
  kernel->setParameterValue(ParameterAddressSquareWave, 1.0);
  // channel 1 is 90° out of phase with channel 2
  kernel->setParameterValue(ParameterAddressOdd90, 1.0);

  std::vector<AUValue> in0;
  std::vector<AUValue> in1;

  auto theta = 3 * M_PI * 2.0 / samplesPerSecond;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    auto sample = sin(index * theta);
    in0.push_back(sample);
    in1.push_back(sample);
  }

  std::vector<AUValue> out0(samplesPerSecond, 0.0);
  std::vector<AUValue> out1(samplesPerSecond, 0.0);

  std::vector<AUValue*> inputs{in0.data(), in1.data()};
  std::vector<AUValue*> outputs{out0.data(), out1.data()};

  dump(" in0", in0);
  dump(" in1", in1);

  kernel->doRendering(inputs, outputs, samplesPerSecond);

  dump("out0", out0);
  dump("out1", out1);
  dump("att", kernel->attenuationBuffer_);

  std::vector<AUValue> attenuation{
    1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000,
    0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
    1.000000, 1.000000, 1.000000, 1.000000, 1.000000, 0.000000, 0.000000, 0.000000, 0.000000, 0.000000,
    0.000000, 0.000000, 0.000000, 0.000000, 0.000000, 1.000000, 1.000000, 1.000000, 1.000000, 1.000000
  };

  AUValue epsilon = 1e-4;
  for (auto index = 0; index < samplesPerSecond; ++index) {
    XCTAssertEqualWithAccuracy(in0[index] * attenuation[index], out0[index], epsilon);
    XCTAssertEqualWithAccuracy(in1[index] * attenuation[index + samplesPerSecond], out1[index], epsilon);
  }
}

void
dump(const std::string& name, const std::vector<AUValue>& vec) {
  std::cout << name << ": ";
  std::cout << std::fixed << std::showpoint << std::setprecision(6);
  for (auto v : vec) { std::cout << v << ", "; }
  std::cout << '\n';
}

@end
