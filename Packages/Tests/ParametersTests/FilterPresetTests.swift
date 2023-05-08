import XCTest
@testable import Parameters
import Kernel
import ParameterAddress
import AUv3Support

final class AudioUnitParametersTests: XCTestCase {

  func testParameterAddress() throws {
    XCTAssertEqual(ParameterAddress.rate.rawValue, 0)
    XCTAssertEqual(ParameterAddress.odd90.rawValue, 5)

    // Unfortunately, there is no init? for Obj-C enums
    // XCTAssertNil(ParameterAddress(rawValue: ParameterAddress.odd90.rawValue + 1))

    XCTAssertEqual(ParameterAddress.allCases.count, 6)
    XCTAssertTrue(ParameterAddress.allCases.contains(.rate))
    XCTAssertTrue(ParameterAddress.allCases.contains(.depth))
    XCTAssertTrue(ParameterAddress.allCases.contains(.dry))
    XCTAssertTrue(ParameterAddress.allCases.contains(.wet))
    XCTAssertTrue(ParameterAddress.allCases.contains(.squareWave))
    XCTAssertTrue(ParameterAddress.allCases.contains(.odd90))
  }

  func testParameterDefinitions() throws {
    let aup = Parameters()
    for (index, address) in ParameterAddress.allCases.enumerated() {
      XCTAssertTrue(aup.parameters[index] == aup[address])
    }
  }
}
