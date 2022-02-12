import XCTest
@testable import Parameters

final class FilterPresetTests: XCTestCase {

  func testInit() throws {

    let a = FilterPreset(rate: 1.0, depth: 2.0, dry: 3.0, wet: 4.0, squareWave: 1.0, odd90: 0.0)

    XCTAssertEqual(a.rate, 1.0)
    XCTAssertEqual(a.depth, 2.0)
    XCTAssertEqual(a.dry, 3.0)
    XCTAssertEqual(a.wet, 4.0)
    XCTAssertEqual(a.squareWave, 1.0)
    XCTAssertEqual(a.odd90, 0.0)
  }
}
