// Copyright © 2021 Brad Howes. All rights reserved.

import CoreAudioKit
import os

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc public final class FilterViewController: AUViewController {
    private let log = Logging.logger("FilterViewController")

    private var viewConfig: AUAudioUnitViewConfiguration!
    private var parameterObserverToken: AUParameterObserverToken?
    private var keyValueObserverToken: NSKeyValueObservation?

    private let logSliderMinValue: Float = 0.0
    private let logSliderMaxValue: Float = 9.0
    private lazy var logSliderMaxValuePower2Minus1 = Float(pow(2, logSliderMaxValue) - 1)

    @IBOutlet weak var controlsView: View!

    @IBOutlet weak var rateControl: Knob!
    @IBOutlet weak var rateValueLabel: Label!

    @IBOutlet weak var depthControl: Knob!
    @IBOutlet weak var depthValueLabel: Label!

    @IBOutlet weak var dryMixControl: Knob!
    @IBOutlet weak var dryMixValueLabel: Label!

    @IBOutlet weak var wetMixControl: Knob!
    @IBOutlet weak var wetMixValueLabel: Label!

    @IBOutlet weak var squareWaveformSwitch: Switch!
    @IBOutlet weak var odd90Switch: Switch!

    #if os(iOS)
    @IBOutlet weak var rateTapEdit: UIView!
    @IBOutlet weak var depthTapEdit: UIView!
    @IBOutlet weak var dryMixTapEdit: UIView!
    @IBOutlet weak var wetMixTapEdit: UIView!

    @IBOutlet weak var editingView: View!
    @IBOutlet weak var editingBoxView: UIView!
    @IBOutlet weak var editingLabel: Label!
    @IBOutlet weak var editingValue: UITextField!
    #endif

    var controls = [FilterParameterAddress : AUParameterControl]()

    public var audioUnit: FilterAudioUnit? {
        didSet {
            performOnMain {
                if self.isViewLoaded {
                    self.connectViewToAU()
                }
            }
        }
    }

    #if os(macOS)

    public override init(nibName: NSNib.Name?, bundle: Bundle?) {
        os_log(.info, log: log, "init(nibName:bundle)")
        super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
    }

    #endif

    required init?(coder: NSCoder) {
        os_log(.info, log: log, "init(coder)")
        super.init(coder: coder)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        os_log(.info, log: log, "viewDidLoad")
        view.backgroundColor = .black
        if audioUnit != nil {
            connectViewToAU()
        }

        #if os(iOS)

        editingBoxView.layer.cornerRadius = 8.0
        editingView.isHidden = true

        for view in [rateTapEdit, depthTapEdit, dryMixTapEdit, wetMixTapEdit] {
            addTapGesture(view!)
        }

        #endif

        for knob in [rateControl, depthControl] {
            knob!.trackLineWidth = 10
            knob!.progressLineWidth = 8
            knob!.indicatorLineWidth = 8
        }

        for knob in [dryMixControl, wetMixControl] {
            knob!.trackLineWidth = 8;
            knob!.progressLineWidth = 6;
            knob!.indicatorLineWidth = 6;
        }
    }

    public func selectViewConfiguration(_ viewConfig: AUAudioUnitViewConfiguration) {
        guard self.viewConfig != viewConfig else { return }
        self.viewConfig = viewConfig
    }

    @IBAction public func rateChanged(control: Knob) {
        controls[.rate]?.controlChanged()
    }

    @IBAction public func depthChanged(control: Knob) {
        controls[.depth]?.controlChanged()
    }

    @IBAction public func dryChanged(control: Knob) {
        controls[.dryMix]?.controlChanged()
    }

    @IBAction public func wetChanged(control: Knob) {
        controls[.wetMix]?.controlChanged()
    }

    @IBAction public func squareWaveChanged(control: Switch) { controls[.squareWave]?.controlChanged() }

    @IBAction public func odd90Changed(control: Switch) { controls[.odd90]?.controlChanged() }

    #if os(macOS)
    override public func mouseDown(with event: NSEvent) {
        // Allow for clicks on the common NSView to end editing of values
        NSApp.keyWindow?.makeFirstResponder(nil)
    }
    #endif

}

extension FilterViewController: AUAudioUnitFactory {

    /**
     Create a new FilterAudioUnit instance to run in an AVu3 container.

     - parameter componentDescription: descriptions of the audio environment it will run in
     - returns: new FilterAudioUnit
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        os_log(.info, log: log, "creating new audio unit")
        componentDescription.log(log, type: .debug)
        audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
        return audioUnit!
    }
}

extension FilterViewController {

    private func connectViewToAU() {
        os_log(.info, log: log, "connectViewToAU")

        guard parameterObserverToken == nil else { return }
        guard let audioUnit = audioUnit else { fatalError("logic error -- nil audioUnit value") }
        guard let paramTree = audioUnit.parameterTree else { fatalError("logic error -- nil parameterTree") }

        keyValueObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
            self.performOnMain { self.updateDisplay() }
        }

        let parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] _, _ in
            guard let self = self else { return }
            self.performOnMain { self.updateDisplay() }
        })

        self.parameterObserverToken = parameterObserverToken

        let params = audioUnit.parameterDefinitions
        controls[.rate] = KnobController(parameterObserverToken: parameterObserverToken, parameter: params[.rate],
                                         formatter: params.valueFormatter(.rate), knob: rateControl,
                                         label: rateValueLabel, logValues: false)
        controls[.depth] = KnobController(parameterObserverToken: parameterObserverToken, parameter: params[.depth],
                                          formatter: params.valueFormatter(.depth), knob: depthControl,
                                          label: depthValueLabel, logValues: false)
        controls[.dryMix] = KnobController(parameterObserverToken: parameterObserverToken, parameter: params[.dryMix],
                                           formatter: params.valueFormatter(.dryMix), knob: dryMixControl,
                                           label: dryMixValueLabel, logValues: false)
        controls[.wetMix] = KnobController(parameterObserverToken: parameterObserverToken, parameter: params[.wetMix],
                                           formatter: params.valueFormatter(.wetMix), knob: wetMixControl,
                                           label:  wetMixValueLabel, logValues: false)
        controls[.squareWave] = SwitchController(parameterObserverToken: parameterObserverToken, parameter: params[.squareWave],
                                                 control: squareWaveformSwitch)
        controls[.odd90] = SwitchController(parameterObserverToken: parameterObserverToken, parameter: params[.odd90],
                                                 control: odd90Switch)
    }

    private func updateDisplay() {
        os_log(.info, log: log, "updateDisplay")
        for address in FilterParameterAddress.allCases {
            controls[address]?.parameterChanged()
        }
    }

    private func performOnMain(_ operation: @escaping () -> Void) {
        (Thread.isMainThread ? operation : { DispatchQueue.main.async { operation() } })()
    }
}

#if os(iOS)

extension FilterViewController: UITextFieldDelegate {

    @IBAction func beginEditing(sender: UITapGestureRecognizer) {
        guard editingView.isHidden,
              let view = sender.view,
              let address = FilterParameterAddress(rawValue: UInt64(view.tag)),
              let param = controls[address]?.parameter else { return }

        os_log(.info, log: log, "beginEditing - %d", view.tag)
        editingView.tag = view.tag
        editingLabel.text = param.displayName
        editingValue.text = "\(param.value)"
        editingValue.becomeFirstResponder()
        editingValue.delegate = self

        editingView.alpha = 0.0
        editingView.isHidden = false

        os_log(.info, log: log, "starting animation")
        UIView.animate(withDuration: 0.4, delay: 0.0, options: [.curveEaseIn]) {
            self.editingView.alpha = 1.0
            self.controlsView.alpha = 0.25
        } completion: { _ in
            self.editingView.alpha = 1.0
            self.controlsView.alpha = 0.25
            os_log(.info, log: self.log, "done animation")
        }
    }

    private func endEditing() {
        guard let address = FilterParameterAddress(rawValue: UInt64(editingView.tag)) else { fatalError() }
        os_log(.info, log: log, "endEditing - %d", editingView.tag)

        editingValue.resignFirstResponder()

        os_log(.info, log: log, "starting animation")
        UIView.animate(withDuration: 0.4, delay: 0.0, options: [.curveEaseIn]) {
            self.editingView.alpha = 0.0
            self.controlsView.alpha = 1.0
        } completion: { _ in
            self.editingView.alpha = 0.0
            self.controlsView.alpha = 1.0
            self.editingView.isHidden = true
            if let stringValue = self.editingValue.text,
               let value = Float(stringValue) {
                self.controls[address]?.setEditedValue(value)
            }
            os_log(.info, log: self.log, "done animation")
        }
    }

    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !editingView.isHidden {
            endEditing()
        }
        super.touchesBegan(touches, with: event)
    }

    private func addTapGesture(_ view: UIView) {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(beginEditing))
        gesture.numberOfTouchesRequired = 1
        gesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(gesture)
        view.isUserInteractionEnabled = true
    }

    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        os_log(.info, log: log, "textFieldShouldReturn")
        endEditing()
        return false
    }

    public func textFieldDidEndEditing(_ textField: UITextField) {
        os_log(.info, log: log, "textFieldDidEndEditing")
        if textField.isFirstResponder {
            endEditing()
        }
    }
}

#endif

