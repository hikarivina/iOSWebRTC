//
//  CallViewController.swift
//  WebRTCHandsOn
//
//  Created by dang nguyenhuu on 2018/02/13.
//  Copyright © 2018 tnoho. All rights reserved.
//

import UIKit
import CallKit

class CallViewController: UIViewController, CXProviderDelegate {

    override func viewDidLoad() {

    }
    
    func providerDidReset(_ provider: CXProvider) {
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
    }

}
