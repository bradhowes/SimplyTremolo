// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import Knob_iOS
import ParameterAddress
import Parameters
import os.log

extension Knob: AUParameterValueProvider, RangedControl {}

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController : AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = Parameters()
  private let kernel = KernelBridge(Bundle.main.auBaseName)
  private var viewConfig: AUAudioUnitViewConfiguration!

  private let logSliderMinValue: Float = 0.0
  private let logSliderMaxValue: Float = 9.0
  private lazy var logSliderMaxValuePower2Minus1 = Float(pow(2, logSliderMaxValue) - 1)

  @IBOutlet weak var controlsView: View!

  @IBOutlet weak var rateControl: Knob!
  @IBOutlet weak var rateValueLabel: Label!
  @IBOutlet weak var rateTapEdit: UIView!

  @IBOutlet weak var depthControl: Knob!
  @IBOutlet weak var depthValueLabel: Label!
  @IBOutlet weak var depthTapEdit: UIView!

  @IBOutlet weak var dryMixControl: Knob!
  @IBOutlet weak var dryMixValueLabel: Label!
  @IBOutlet weak var dryMixTapEdit: UIView!

  @IBOutlet weak var wetMixControl: Knob!
  @IBOutlet weak var wetMixValueLabel: Label!
  @IBOutlet weak var wetMixTapEdit: UIView!

  @IBOutlet weak var squareWaveformSwitch: Switch!
  @IBOutlet weak var odd90Switch: Switch!

  private lazy var controls: [ParameterAddress: (Knob, Label, UIView)] = [
    .rate: (rateControl, rateValueLabel, rateTapEdit),
    .depth: (depthControl, depthValueLabel, depthTapEdit),
    .wet: (wetMixControl, wetMixValueLabel, wetMixTapEdit),
    .dry: (dryMixControl, dryMixValueLabel, dryMixTapEdit)
  ]

  private lazy var switches: [ParameterAddress: Switch] = [
    .squareWave: squareWaveformSwitch,
    .odd90: odd90Switch
  ]

  // Holds all of the other editing views and is used to end editing when tapped.
  @IBOutlet weak var editingContainerView: View!
  // Background that contains the label and value editor field. Always appears just above the keyboard view.
  @IBOutlet weak var editingBackground: UIView!
  // Shows the name of the value being edited
  @IBOutlet weak var editingLabel: Label!
  // Shows the name of the value being edited
  @IBOutlet weak var editingValue: UITextField!

  // The top constraint of the editingView. Set to 0 when loaded, but otherwise not used.
  @IBOutlet weak var editingViewTopConstraint: NSLayoutConstraint!
  // The bottom constraint of the editingBackground that controls the vertical position of the editor
  @IBOutlet weak var editingBackgroundBottomConstraint: NSLayoutConstraint!

  private var editors = [AUParameterEditor]()
  private var editorMap = [ParameterAddress : AUParameterEditor]()

  public var audioUnit: FilterAudioUnit? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.createEditors()
        }
      }
    }
  }
}

public extension ViewController {

  override func viewDidLoad() {
    os_log(.info, log: log, "viewDidLoad BEGIN")
    super.viewDidLoad()

    view.backgroundColor = .black
    if audioUnit != nil {
      createEditors()
    }
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension ViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension ViewController: AUAudioUnitFactory {
  @objc public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    let kernel = KernelBridge(Bundle.main.auBaseName)
    let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                      parameters: parameters, kernel: kernel,
                                                      viewConfigurationManager: self)
    self.audioUnit = audioUnit
    return audioUnit
  }
}

extension ViewController: AUParameterEditorDelegate {
  public func parameterEditorEditingDone(changed: Bool) {
    audioUnit?.clearCurrentPresetIfFactoryPreset()
  }
}

// MARK: - Private

extension ViewController {

  private func createEditors() {
    os_log(.info, log: log, "createEditors BEGIN")

    let knobColor = UIColor(named: "knob")!

    let valueEditor = ValueEditor(containerView: editingContainerView, backgroundView: editingBackground,
                                  parameterName: editingLabel, parameterValue: editingValue,
                                  containerViewTopConstraint: editingViewTopConstraint,
                                  backgroundViewBottomConstraint: editingBackgroundBottomConstraint,
                                  controlsView: controlsView)

    for (parameterAddress, (knob, label, tapEdit)) in controls {
      knob.progressColor = knobColor
      knob.indicatorColor = knobColor
      knob.addTarget(self, action: #selector(handleKnobChanged(_:)), for: .valueChanged)

      let editor = FloatParameterEditor(parameter: parameters[parameterAddress],
                                        formatting: parameters[parameterAddress],
                                        rangedControl: knob, label: label)
      editor.delegate = self
      editors.append(editor)
      editorMap[parameterAddress] = editor
      editor.setValueEditor(valueEditor: valueEditor, tapToEdit: tapEdit)
    }

    os_log(.info, log: log, "createEditors - creating bool parameter editors")
    for (parameterAddress, control) in switches {
      os_log(.info, log: log, "createEditors - before BooleanParameterEditor")
      control.addTarget(self, action: #selector(handleSwitchChanged(_:)), for: .valueChanged)
      let editor = BooleanParameterEditor(parameter: parameters[parameterAddress], booleanControl: control)
      editors.append(editor)
      editorMap[parameterAddress] = editor
    }

    os_log(.info, log: log, "createEditors END")
  }

  @objc public func handleKnobChanged(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  @objc public func handleSwitchChanged(_ control: Switch) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  func handleControlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    os_log(.debug, log: log, "controlChanged BEGIN - %d %f %f", address.rawValue, control.value,
           parameters[address].value)

    guard let audioUnit = audioUnit else {
      os_log(.debug, log: log, "controlChanged END - nil audioUnit")
      return
    }

    guard let editor = editorMap[address] else {
      os_log(.debug, log: log, "controlChanged END - nil editor")
      return
    }

    if editor.differs {
      // When user changes something and a factory preset was active, clear it.
      if let preset = audioUnit.currentPreset, preset.number >= 0 {
        os_log(.debug, log: log, "controlChanged - clearing currentPreset")
        audioUnit.currentPreset = nil
      }
    }

    editor.controlChanged(source: control)
  }
}
