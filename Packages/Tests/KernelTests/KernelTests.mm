// Copyright © 2021 Brad Howes. All rights reserved.

#import <XCTest/XCTest.h>
#import <cmath>
#import <iomanip>
#import <iostream>

#import "DSPHeaders/BusBuffers.hpp"
#import "../../Sources/Kernel/C++/Kernel.hpp"

@import ParameterAddress;

@interface KernelTests : XCTestCase
@property float epsilon;
@end

@implementation KernelTests

- (void)setUp {
  _epsilon = 1.0e-8;
}

- (void)tearDown {}

- (void)testKernelParams {
  auto kernel{Kernel("blah")};
  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  kernel.setRenderingFormat(1, format, 100);

  kernel.setParameterValue(ParameterAddressRate, 30.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressRate), 30.0, 0.001);

  kernel.setParameterValue(ParameterAddressDepth, 10.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressDepth), 10.0, 0.001);

  kernel.setParameterValue(ParameterAddressDry, 50.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressDry), 50.0, 0.001);

  kernel.setParameterValue(ParameterAddressWet, 60.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressWet), 60.0, 0.001);

  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressSquareWave), 0.0, 0.001);
  kernel.setParameterValue(ParameterAddressSquareWave, 1.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressSquareWave), 1.0, 0.001);

  kernel.setParameterValue(ParameterAddressOdd90, 0.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressOdd90), 0.0, 0.001);
  kernel.setParameterValue(ParameterAddressOdd90, 1.0);
  XCTAssertEqualWithAccuracy(kernel.getParameterValue(ParameterAddressOdd90), 1.0, 0.001);
}

- (void)testRendering {
  AudioTimeStamp timestamp = AudioTimeStamp();
  AudioUnitRenderActionFlags flags = 0;
  AUAudioUnitStatus (^mockPullInput)(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp,
                                     AUAudioFrameCount frameCount, NSInteger inputBusNumber,
                                     AudioBufferList *inputData) =
  ^(AudioUnitRenderActionFlags *actionFlags, const AudioTimeStamp *timestamp,
    AUAudioFrameCount frameCount, NSInteger inputBusNumber, AudioBufferList *inputData) {
    auto bufferCount = inputData->mNumberBuffers;
    for (int index = 0; index < bufferCount; ++index) {
      auto& buffer = inputData->mBuffers[index];
      auto numberOfChannels = buffer.mNumberChannels;
      assert(numberOfChannels == 1); // not interleaved
      auto bufferSize = buffer.mDataByteSize;
      assert(sizeof(AUValue) * frameCount == bufferSize);
      auto ptr = reinterpret_cast<AUValue*>(buffer.mData);
      for (int pos = 0; pos < frameCount; ++pos) {
        ptr[pos] = AUValue(pos) / (frameCount - 1);
      }
    }

    return 0;
  };

  AUAudioFrameCount maxFrames = 512;

  auto kernel = Kernel("blah");

  AVAudioFormat* format = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
  kernel.setRenderingFormat(1, format, 512);

  kernel.setParameterValue(ParameterAddressRate, 4.0);
  kernel.setParameterValue(ParameterAddressDepth, 13.0);
  kernel.setParameterValue(ParameterAddressDry, 50.0);
  kernel.setParameterValue(ParameterAddressWet, 50.0);
  kernel.setParameterValue(ParameterAddressOdd90, 0.0);

  AUAudioFrameCount frames = maxFrames;
  AVAudioPCMBuffer* buffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:format frameCapacity:maxFrames];
  auto status = kernel.processAndRender(&timestamp, frames, 0, [buffer mutableAudioBufferList], nil, mockPullInput);
  XCTAssertEqual(status, 0);

  auto ptr = buffer.floatChannelData[0];
  dump(ptr, frames);

//  XCTAssertEqualWithAccuracy(ptr[0], 0.0, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[1], 0.001893310109, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[2], 0.003786547808, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[3], 0.005679712631, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[4], 0.007572805975, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[frames-5], 0.950738549232, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[frames-4], 0.952596187592, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[frames-3], 0.954453706741, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[frames-2], 0.956311166286, _epsilon);
//  XCTAssertEqualWithAccuracy(ptr[frames-1], 0.958168506622, _epsilon);
}

void
dump(AUValue* vec, size_t count) {
  std::cout << std::fixed << std::showpoint << std::setprecision(12);
  while (count-- > 0) {
    std::cout << *vec++ << '\n';
  }
}

@end
