// Copyright © 2021 Brad Howes. All rights reserved.

import AudioToolbox
import os

/**
 Address definitions for AUParameter settings.
 */
@objc public enum FilterParameterAddress: UInt64, CaseIterable {
    case rate = 0
    case depth
    case dryMix
    case wetMix
    case squareWave
    case odd90
}

private extension Array where Element == AUParameter {
    subscript(index: FilterParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject {

    private let log = Logging.logger("FilterParameters")

    static public let maxDelayMilliseconds: AUValue = 15.0

    public let parameters: [AUParameter] = [
        AUParameterTree.createParameter("rate", name: "Rate", address: .rate, min: 0.01, max: 20.0, unit: .hertz),
        AUParameterTree.createParameter("depth", name: "Depth", address: .depth, min: 0.0, max: 100.0, unit: .percent),
        AUParameterTree.createParameter("dry", name: "Dry", address: .dryMix, min: 0.0, max: 100.0, unit: .percent),
        AUParameterTree.createParameter("wet", name: "Wet", address: .wetMix, min: 0.0, max: 100.0, unit: .percent),
        AUParameterTree.createParameter("squareWave", name: "SquareWave", address: .squareWave, min: 0.0, max: 1.0, unit: .boolean),
        AUParameterTree.createParameter("odd90", name: "Odd 90°", address: .odd90, min: 0.0, max: 1.0, unit: .boolean)
    ]

    /// AUParameterTree created with the parameter definitions for the audio unit
    public let parameterTree: AUParameterTree

    public var rate: AUParameter { parameters[.rate] }
    public var depth: AUParameter { parameters[.depth] }
    public var dryMix: AUParameter { parameters[.dryMix] }
    public var wetMix: AUParameter { parameters[.wetMix] }
    public var squareWave: AUParameter { parameters[.squareWave] }
    public var odd90: AUParameter { parameters[.odd90] }

    /**
     Create a new AUParameterTree for the defined filter parameters.

     Installs three closures in the tree:
     - one for providing values
     - one for accepting new values from other sources
     - and one for obtaining formatted string values

     - parameter parameterHandler the object to use to handle the AUParameterTree requests
     */
    init(parameterHandler: AUParameterHandler) {
        parameterTree = AUParameterTree.createTree(withChildren: parameters)
        super.init()

        parameterTree.implementorValueObserver = { parameterHandler.set($0, value: $1) }
        parameterTree.implementorValueProvider = { parameterHandler.get($0) }
        parameterTree.implementorStringFromValueCallback = { param, value in
            let formatted = self.formatValue(param.address.filterParameter, value: param.value)
            os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
                   param.address, param.value, formatted)
            return formatted
        }
    }
}

extension AudioUnitParameters {

    public subscript(address: FilterParameterAddress) -> AUParameter { parameters[address] }

    public func valueFormatter(_ address: FilterParameterAddress) -> (AUValue) -> String {
        let unitName = self[address].unitName ?? ""

        let separator: String = {
            switch address {
            case .rate: return " "
            default: return ""
            }
        }()

        let format: String = formatting(address)

        return { value in String(format: format, value) + separator + unitName }
    }

    public func formatValue(_ address: FilterParameterAddress?, value: AUValue) -> String {
        guard let address = address else { return "?" }
        let format = formatting(address)
        return String(format: format, value)
    }

    /**
     Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
     AudioUnit.
     */
    public func setValues(_ preset: FilterPreset) {
        rate.value = preset.rate
        depth.value = preset.depth
        dryMix.value = preset.dryMix
        wetMix.value = preset.wetMix
        squareWave.value = preset.squareWave
        odd90.value = preset.odd90
    }
}

extension AudioUnitParameters {
    private func formatting(_ address: FilterParameterAddress) -> String {
        switch address {
        case .rate: return "%.2f"
        case .depth: return "%.2f"
        case .squareWave, .odd90: return "%.0f"
        case .dryMix, .wetMix: return "%.0f"
        default: return "?"
        }
    }
}
