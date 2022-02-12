import XCTest
@testable import ParameterAddress

final class ParameterAddressTests: XCTestCase {

  func testParameterAddress() throws {
    XCTAssertEqual(ParameterAddress.rate.rawValue, 0)
    XCTAssertEqual(ParameterAddress.odd90.rawValue, 5)
    XCTAssertEqual(ParameterAddress.allCases.count, 6)
  }

  func testParameterDefinitions() throws {
    let depth = ParameterAddress.depth.parameterDefinition
    XCTAssertEqual(depth.range.lowerBound, 0.0)
    XCTAssertEqual(depth.range.upperBound, 100.0)
    XCTAssertEqual(depth.unit, .percent)
    XCTAssertTrue(depth.ramping)
    XCTAssertFalse(depth.logScale)

    let rate = ParameterAddress.rate.parameterDefinition
    XCTAssertEqual(rate.range.lowerBound, 0.01)
    XCTAssertEqual(rate.range.upperBound, 20.0)
    XCTAssertEqual(rate.unit, .hertz)
    XCTAssertTrue(rate.ramping)
    XCTAssertTrue(rate.logScale)

    let squareWave = ParameterAddress.squareWave.parameterDefinition
    XCTAssertEqual(squareWave.range.lowerBound, 0.0)
    XCTAssertEqual(squareWave.range.upperBound, 1.0)
    XCTAssertEqual(squareWave.unit, .boolean)
    XCTAssertFalse(squareWave.ramping)
    XCTAssertFalse(squareWave.logScale)

    let odd90 = ParameterAddress.odd90.parameterDefinition
    XCTAssertEqual(odd90.range.lowerBound, 0.0)
    XCTAssertEqual(odd90.range.upperBound, 1.0)
    XCTAssertEqual(odd90.unit, .boolean)
    XCTAssertFalse(odd90.ramping)
    XCTAssertFalse(odd90.logScale)
  }

  func testAUParameterGeneration() throws {
    var address: ParameterAddress = .depth
    var definition = address.parameterDefinition
    var parameter = definition.parameter
    XCTAssertEqual(parameter.address, address.rawValue)
    XCTAssertEqual(parameter.identifier, definition.identifier)
    XCTAssertEqual(parameter.displayName, definition.localized)
    XCTAssertTrue(parameter.flags.contains(.flag_CanRamp))
    XCTAssertFalse(parameter.flags.contains(.flag_DisplayLogarithmic))

    address = .odd90
    definition = address.parameterDefinition
    parameter = definition.parameter
    XCTAssertFalse(parameter.flags.contains(.flag_CanRamp))
    XCTAssertFalse(parameter.flags.contains(.flag_DisplayLogarithmic))
  }
}
