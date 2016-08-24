//
//  VSLCallViewController.swift
//  Copyright © 2016 Devhouse Spindle. All rights reserved.
//

import UIKit

private var myContext = 0

class VSLCallViewController: UIViewController, VSLKeypadViewControllerDelegate {

    // MARK: - Configuration

    private struct Configuration {
        struct Timing {
            static let UnwindTime = 2.0
            static let connectDurationInterval = 1.0
        }
        struct Segues {
            static let UnwindToMakeCall = "UnwindToMakeCallSegue"
            static let ShowKeypad = "ShowKeypadSegue"
            static let SetupTransfer = "SetupTransferSegue"
        }
    }

    // MARK: - Properties

    var activeCall: VSLCall? {
        didSet {
            updateUI()
        }
    }

    var connectDurationTimer: NSTimer?

    // MARK: - Lifecycle

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        updateUI()
        startConnectDurationTimer()
        activeCall?.addObserver(self, forKeyPath: "callState", options: .New, context: &myContext)
        activeCall?.addObserver(self, forKeyPath: "onHold", options: .New, context: &myContext)
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        connectDurationTimer?.invalidate()
        activeCall?.removeObserver(self, forKeyPath: "callState")
        activeCall?.removeObserver(self, forKeyPath: "onHold")
    }

    // MARK: - Outlets

    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var transferButton: UIButton!
    @IBOutlet weak var holdButton: UIButton!
    @IBOutlet weak var bluetoothButton: UIButton!
    @IBOutlet weak var hangupButton: UIButton!
    @IBOutlet weak var keypadButton: UIButton!

    // MARK: - Actions

    @IBAction func hangupButtonPressed(sender: UIButton) {
        endCall()
    }

    @IBAction func muteButtonPressed(sender: UIButton) {
        if let call = activeCall where call.callState == .Confirmed {
            do {
                try call.toggleMute()
                updateUI()
            } catch let error {
                DDLogWrapper.logError("Error muting call: \(error)")
            }
        }
    }

    @IBAction func speakerButtonPressed(sender: UIButton) {
        if let call = activeCall {
            call.toggleSpeaker()
            updateUI()
        } else {
            speakerButton.setTitle("Speaker", forState: .Normal)
        }
    }

    @IBAction func holdButtonPressed(sender: UIButton) {
        if let call = activeCall where call.callState == .Confirmed {
            do {
                try call.toggleHold()
                updateUI()
            } catch let error {
                DDLogWrapper.logError("Error holding call: \(error)")
            }
        }
    }

    @IBAction func bluetoothButtonPressed(sender: UIButton) {
        VSLAudio.sharedInstance().toggleBluetooth()
    }


    @IBAction func keypadButtonPressed(sender: UIButton) {
        if let call = activeCall where call.callState == .Confirmed {
            performSegueWithIdentifier(Configuration.Segues.ShowKeypad, sender: nil)
        }
    }

    @IBAction func transferButtonPressed(sender: UIButton) {
        if let call = activeCall where call.callState == .Confirmed {
            // If the call is on hold, perform segue, otherwise, try put on hold before segue.
            if call.onHold {
                performSegueWithIdentifier(Configuration.Segues.SetupTransfer, sender: nil)
            } else {
                do {
                    try call.toggleHold()
                    performSegueWithIdentifier(Configuration.Segues.SetupTransfer, sender: nil)
                } catch let error {
                    DDLogWrapper.logError("Error holding current call: \(error)")
                }
            }
        }
    }

    @IBAction func backButtonPressed(sender: UIBarButtonItem) {
        if let call = activeCall where call.callState != .Disconnected {
            do {
                try call.hangup()
                performSegueWithIdentifier(Configuration.Segues.UnwindToMakeCall, sender: nil)
            } catch let error {
                DDLogWrapper.logError("error hanging up call: \(error)")
            }
        } else {
            self.navigationController?.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func endCall() {
        if let call = activeCall where call.callState != .Disconnected {
            do {
                try call.hangup()
                self.performSegueWithIdentifier(Configuration.Segues.UnwindToMakeCall, sender: nil)
            } catch let error {
                DDLogWrapper.logError("Couldn't hangup call: \(error)")
            }
        }
    }

    func updateUI() {
        if let call = activeCall {
            updateLabels(call: call, statusLabel: statusLabel, numberLabel: numberLabel)
            let vslAudio = VSLAudio.sharedInstance()

            switch call.callState {
            case .Incoming: fallthrough
            case .Null: fallthrough
            case .Disconnected:
                // No Buttons enabled
                muteButton?.enabled = false
                keypadButton?.enabled = false
                transferButton?.enabled = false
                holdButton?.enabled = false
                hangupButton?.enabled = false
                speakerButton?.enabled = false
                bluetoothButton?.enabled = false
            case .Calling: fallthrough
            case .Early: fallthrough
            case .Connecting:
                // Speaker & hangup can be enabled
                muteButton?.enabled = false
                keypadButton?.enabled = false
                transferButton?.enabled = false
                holdButton?.enabled = false
                hangupButton?.enabled = true
                speakerButton?.enabled = true
                speakerButton?.setTitle(call.speaker ? "On Speaker" : "Speaker", forState: .Normal)
                bluetoothButton?.enabled = false
            case .Confirmed:
                // All buttons enabled
                muteButton?.enabled = !call.onHold
                muteButton?.setTitle(call.muted ? "Muted" : "Mute", forState: .Normal)
                keypadButton?.enabled = !call.onHold
                transferButton?.enabled = true
                holdButton?.enabled = true
                holdButton?.setTitle(call.onHold ? "On Hold" : "Hold", forState: .Normal)
                hangupButton?.enabled = true
                speakerButton?.enabled = true
                speakerButton?.setTitle(call.speaker ? "On Speaker" : "Speaker", forState: .Normal)
                bluetoothButton?.enabled = true
                bluetoothButton.setTitle(vslAudio.bluetoothEnabled ? "BT on" : "BT off", forState: .Normal)
            }
        }
    }

    /**
     Helper function to update the UI for the specific call.

     - parameter call:        VSLCall that stores the status.
     - parameter statusLabel: UILabel that presents the status.
     - parameter numberLabel: UILabel that presents the number.
     */
    func updateLabels(call call: VSLCall, statusLabel: UILabel?, numberLabel: UILabel?) {
        numberLabel?.text = call.callerNumber
        switch call.callState {
        case .Null:
            statusLabel?.text = "Not started"
        case .Calling:
            statusLabel?.text = "Calling..."
        case .Incoming: break
        case .Early: fallthrough
        case .Connecting:
            statusLabel?.text = "Connecting..."
        case .Confirmed:
            if call.onHold {
                statusLabel?.text = "ON HOLD"
            } else {
                let dateComponentsFormatter = NSDateComponentsFormatter()
                dateComponentsFormatter.zeroFormattingBehavior = .Pad
                dateComponentsFormatter.allowedUnits = [.Minute, .Second]
                statusLabel?.text = "\(dateComponentsFormatter.stringFromTimeInterval(call.connectDuration)!)"
            }
        case .Disconnected:
            statusLabel?.text = "Disconnected"
            connectDurationTimer?.invalidate()
        }
    }

    private func startConnectDurationTimer() {
        if connectDurationTimer == nil || !connectDurationTimer!.valid {
            connectDurationTimer = NSTimer.scheduledTimerWithTimeInterval(Configuration.Timing.connectDurationInterval, target: self, selector: #selector(updateUI), userInfo: nil, repeats: true)
        }
    }

    // MARK: - Segues

    @IBAction func unwindToFirstCallInProgressSegue(segue: UIStoryboardSegue) {}

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let keypadVC = segue.destinationViewController as? VSLKeypadViewController {
            keypadVC.call = activeCall
            keypadVC.delegate = self
        } else if let transferCallVC = segue.destinationViewController as? VSLTransferCallViewController {
            transferCallVC.currentCall = activeCall
        }
    }

    // MARK: - KVO

    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &myContext {
            if let call = object as? VSLCall where call.callState == .Disconnected {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(Configuration.Timing.UnwindTime * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                    self.performSegueWithIdentifier(Configuration.Segues.UnwindToMakeCall, sender: nil)
                }
            }
            dispatch_async(GlobalMainQueue) {
                self.updateUI()
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }

    // MARK: - VSLKeypadViewControllerDelegate

    func dismissKeypadViewController() {
        self.navigationController?.popViewControllerAnimated(true)
    }
}
