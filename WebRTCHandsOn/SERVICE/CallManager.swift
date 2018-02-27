//
//  CallManager.swift
//  WebRTCHandsOn
//
//  Created by dang nguyenhuu on 2018/02/13.
//  Copyright © 2018 tnoho. All rights reserved.
//

import Foundation
import UIKit
import CallKit


class CallManager: NSObject {
    
    private var provider: CXProvider
    
    override init() {
        self.provider = CXProvider(configuration: CXProviderConfiguration(localizedName: "My App"))
        super.init()
        provider.setDelegate(self, queue: nil)

    }
    
    
    func receiveCall() {
        
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: "Pete Za")
        provider.reportNewIncomingCall(with: UUID(), update: update, completion: { error in })
        
    }
    
    
    func sendCall() {
        
        let controller = CXCallController()
        let transaction = CXTransaction(action: CXStartCallAction(call: UUID(), handle: CXHandle(type: .generic, value: "Pete Za")))
        controller.request(transaction, completion: { error in })
        
    }
    
    
}






extension CallManager: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        
        print(#function)
    }
    
    
    func providerDidBegin(_ provider: CXProvider) {
        print(#function)
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        print("CXStartCallAction")
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("CXSetMutedCallAction")
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        print("CXSetHeldCallAction")
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
        print("CXPlayDTMFCallAction")
    }
    
    
    
    
    
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        print("Answer")
    }
    
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        print("Cancel")
    }
    
    
    
}








