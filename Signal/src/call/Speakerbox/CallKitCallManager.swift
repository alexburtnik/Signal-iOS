//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

import UIKit
import CallKit
import SignalServiceKit

/**
 * Requests actions from CallKit
 *
 * @Discussion:
 *   Based on SpeakerboxCallManager, from the Apple CallKit Example app. Though, it's responsibilities are mostly 
 *   mirrored (and delegated from) CallKitCallUIAdaptee.
 *   TODO: Would it simplify things to merge this into CallKitCallUIAdaptee?
 */
@available(iOS 10.0, *)
final class CallKitCallManager: NSObject {

    let callController = CXCallController()
    static let kAnonymousCallHandlePrefix = "Signal:"

    override required init() {
        AssertIsOnMainThread()

        super.init()

        SwiftSingletons.register(self)
    }

    // MARK: Actions

    func startCall(_ call: SignalCall) {
        var handle: CXHandle
        if Environment.current().preferences.isCallKitPrivacyEnabled() {
            let callKitId = CallKitCallManager.kAnonymousCallHandlePrefix + call.localId.uuidString
            handle = CXHandle(type: .generic, value: callKitId)
            TSStorageManager.shared().setPhoneNumber(call.remotePhoneNumber, forCallKitId:callKitId)
        } else {
            handle = CXHandle(type: .phoneNumber, value: call.remotePhoneNumber)
        }

        let startCallAction = CXStartCallAction(call: call.localId, handle: handle)

        startCallAction.isVideo = call.hasLocalVideo

        let transaction = CXTransaction()
        transaction.addAction(startCallAction)

        requestTransaction(transaction)
    }

    func localHangup(call: SignalCall) {
        let endCallAction = CXEndCallAction(call: call.localId)
        let transaction = CXTransaction()
        transaction.addAction(endCallAction)

        requestTransaction(transaction)
    }

    func setHeld(call: SignalCall, onHold: Bool) {
        let setHeldCallAction = CXSetHeldCallAction(call: call.localId, onHold: onHold)
        let transaction = CXTransaction()
        transaction.addAction(setHeldCallAction)

        requestTransaction(transaction)
    }

    func setIsMuted(call: SignalCall, isMuted: Bool) {
        let muteCallAction = CXSetMutedCallAction(call: call.localId, muted: isMuted)
        let transaction = CXTransaction()
        transaction.addAction(muteCallAction)

        requestTransaction(transaction)
    }

    func answer(call: SignalCall) {
        let answerCallAction = CXAnswerCallAction(call: call.localId)
        let transaction = CXTransaction()
        transaction.addAction(answerCallAction)

        requestTransaction(transaction)
    }

    private func requestTransaction(_ transaction: CXTransaction) {
        callController.request(transaction) { error in
            if let error = error {
                Logger.error("\(self.logTag) Error requesting transaction: \(error)")
            } else {
                Logger.debug("\(self.logTag) Requested transaction successfully")
            }
        }
    }

    // MARK: Call Management

    private(set) var calls = [SignalCall]()

    func callWithLocalId(_ localId: UUID) -> SignalCall? {
        guard let index = calls.index(where: { $0.localId == localId }) else {
            return nil
        }
        return calls[index]
    }

    func addCall(_ call: SignalCall) {
        calls.append(call)
    }

    func removeCall(_ call: SignalCall) {
        calls.removeFirst(where: { $0 === call })
    }

    func removeAllCalls() {
        calls.removeAll()
    }
}

fileprivate extension Array {

    mutating func removeFirst(where predicate: (Element) throws -> Bool) rethrows {
        guard let index = try index(where: predicate) else {
            return
        }

        remove(at: index)
    }
}
