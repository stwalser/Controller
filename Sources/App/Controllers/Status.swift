//
//  Status.swift
//  
//
//  Created by Stefan Walser on 18.07.22.
//

import Foundation
import Vapor

struct Status: Content {
    var faultLeft: Int
    var faultRight: Int
    var currentTargetLeft: Instruction?
    var currentTargetRight: Instruction?
    var currentInstructionLeft: Instruction
    var currentInstructionRight: Instruction
    var mode: PlatformMode
}
