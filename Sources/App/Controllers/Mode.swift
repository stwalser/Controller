//
//  Mode.swift
//  
//
//  Created by Stefan Walser on 16.07.22.
//

import Foundation
import Vapor

var platformMode = PlatformMode.None {
    willSet {
        if newValue != .HTTPManual {
            stopVehicle()
        }
    }
}

/// Steering mode of the platform
enum PlatformMode: String, Content {
    case None
    case Bluetooth
    case HTTPManual
    case HTTPAutomatic
}
