// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Foundation
import ParameterAddress
import os.log

private extension Array where Element == AUParameter {
  subscript(index: ParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class Parameters: NSObject, ParameterSource {

  private let log = Shared.logger("AudioUnitParameters")

  /// Array of AUParameter entities created from ParameterAddress value definitions.
  public let parameters: [AUParameter] = ParameterAddress.allCases.map { $0.parameterDefinition.parameter }

  /// Array of 2-tuple values that pair a factory preset name and its definition
  public let factoryPresetValues: [(name: String, preset: Configuration)] = [
    ("Strange", .init(rate: 2.0, depth: 50, dry: 0, wet: 100, squareWave: 0.0, odd90: 1.0)),
    ("Clover", .init(rate: 10.0, depth: 100, dry: 0, wet: 100, squareWave: 0.0, odd90: 0.0)),
    ("Chopper", .init(rate: 5.0, depth: 100, dry: 0, wet: 100, squareWave: 1.0, odd90: 0.0)),
    ("Spinner", .init(rate: 1.5, depth: 100, dry: 25, wet: 100, squareWave: 0.0, odd90: 1.0)),
    ("Ponger", .init(rate: 3.5, depth: 100, dry: 0, wet: 100, squareWave: 1.0, odd90: 1.0)),
    ("Trills", .init(rate: 20.0, depth: 62.0, dry: 50, wet: 100, squareWave: 0.0, odd90: 0.0)),
  ]

  /// Array of `AUAudioUnitPreset` for the factory presets.
  public var factoryPresets: [AUAudioUnitPreset] {
    factoryPresetValues.enumerated().map { .init(number: $0.0, name: $0.1.name ) }
  }

  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree

  public var rate: AUParameter { parameters[.rate] }
  public var depth: AUParameter { parameters[.depth] }
  public var dry: AUParameter { parameters[.dry] }
  public var wet: AUParameter { parameters[.wet] }
  public var squareWave: AUParameter { parameters[.squareWave] }
  public var odd90: AUParameter { parameters[.odd90] }

  /**
   Create a new AUParameterTree for the defined filter parameters.
   */
  override public init() {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
    installParameterValueFormatter()
  }
}

extension Parameters {

  private var missingParameter: AUParameter { fatalError() }

  /// Apply a factory preset -- user preset changes are handled by changing AUParameter values through the audio unit's
  /// `fullState` attribute.
  public func useFactoryPreset(_ preset: AUAudioUnitPreset) {
    if preset.number >= 0 {
      setValues(factoryPresetValues[preset.number].preset)
    }
  }

  public subscript(address: ParameterAddress) -> AUParameter {
    parameterTree.parameter(withAddress: address.parameterAddress) ?? missingParameter
  }

  private func installParameterValueFormatter() {
    parameterTree.implementorStringFromValueCallback = { param, valuePtr in
      let value: AUValue
      if let valuePtr = valuePtr {
        value = valuePtr.pointee
      } else {
        value = param.value
      }
      return param.displayValueFormatter(value)
    }
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  public func setValues(_ preset: Configuration) {
    rate.value = preset.rate
    depth.value = preset.depth
    dry.value = preset.dry
    wet.value = preset.wet
    squareWave.value = preset.squareWave
    odd90.value = preset.odd90
  }
}

extension AUParameter: @retroactive AUParameterFormatting {

  /// Obtain string to use to separate a formatted value from its units name
  public var unitSeparator: String { parameterAddress == .rate || parameterAddress == .depth ? " " : "" }
  /// Obtain the suffix to apply to a formatted value
  public var suffix: String { makeFormattingSuffix(from: unitName) }
  /// Obtain the format to use in String(format:value) when formatting a values
  public var stringFormatForDisplayValue: String {
    switch self.parameterAddress {
    case .dry, .wet: return "%.0f"
    default: return "%.2f"
    }
  }
}

