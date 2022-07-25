//
//  GPIO.swift
//  
//
//  Created by Stefan Walser on 16.07.22.
//

import Foundation
import SwiftyGPIO

class GPIOController {
    private let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPi3)
    
    private let pwms = SwiftyGPIO.hardwarePWMs(for: .RaspberryPi3)!
    
//    left elements are also on the left side of the robot
    private let faultPins: (GPIOName, GPIOName) = (.P6, .P5)
    
    private let greenLED: GPIOName = .P14
    private let directionPins: (GPIOName, GPIOName) = (.P3, .P2)
    private let stepPins: (PWMOutput, PWMOutput)
    private let sleepPins: (GPIOName, GPIOName) = (.P22, .P23)
    private let µStepping0Pins: (GPIOName, GPIOName) = (.P19, .P9)
    private let µStepping1Pins: (GPIOName, GPIOName) = (.P20, .P10)
    private let µStepping2Pins: (GPIOName, GPIOName) = (.P21, .P11)
    private let µSteppingMapping = [[0, 0, 0],
                              [1, 0, 0],
                              [0, 1, 0],
                              [1, 1, 0],
                              [0, 0, 1],
                              [1, 0, 1]]
    
    init() {
        stepPins.0 = (pwms[0]?[.P18])!
        stepPins.1 = (pwms[1]?[.P13])!
        stepPins.0.initPWM()
        stepPins.1.initPWM()
        
        gpios[greenLED]!.direction = .OUT
        gpios[directionPins.0]!.direction = .OUT
        gpios[directionPins.1]!.direction = .OUT
        gpios[sleepPins.0]!.direction = .OUT
        gpios[sleepPins.1]!.direction = .OUT
        gpios[µStepping0Pins.0]!.direction = .OUT
        gpios[µStepping0Pins.1]!.direction = .OUT
        gpios[µStepping1Pins.0]!.direction = .OUT
        gpios[µStepping1Pins.1]!.direction = .OUT
        gpios[µStepping2Pins.0]!.direction = .OUT
        gpios[µStepping2Pins.1]!.direction = .OUT
        
        //TODO: Make use of the fault pins
        gpios[faultPins.0]!.direction = .IN
        gpios[faultPins.1]!.direction = .IN
    }
    
    func start() {
        gpios[greenLED]!.value = 1
    }
    
    func setDirectionAndMicrostepping(at side: MotorSide, to d: MotorDirection, and m: Double) {
        switch side {
        case .left:
            gpios[directionPins.0]!.value = d.rawValue
            gpios[µStepping0Pins.0]!.value = µSteppingMapping[Int(log2(m))][0]
            gpios[µStepping1Pins.0]!.value = µSteppingMapping[Int(log2(m))][1]
            gpios[µStepping2Pins.0]!.value = µSteppingMapping[Int(log2(m))][2]
        case .right:
            gpios[directionPins.1]!.value = d.rawValue
            gpios[µStepping0Pins.1]!.value = µSteppingMapping[Int(log2(m))][0]
            gpios[µStepping1Pins.1]!.value = µSteppingMapping[Int(log2(m))][1]
            gpios[µStepping2Pins.1]!.value = µSteppingMapping[Int(log2(m))][2]
        }
    }
    
    func changePWM(at side: MotorSide, to amount: Double) {
        switch side {
        case .left:
            if amount == 0 {
                gpios[sleepPins.0]!.value = 0
                stepPins.0.stopPWM()
            } else {
                gpios[sleepPins.0]!.value = 1
                stepPins.0.startPWM(period: Int(Double(1.0 / amount) * 1_000_000_000), duty: 50)
            }
        case .right:
            if amount == 0 {
                gpios[sleepPins.1]!.value = 0
                stepPins.1.stopPWM()
            } else {
                gpios[sleepPins.1]!.value = 1
                stepPins.1.startPWM(period: Int(Double(1.0 / amount) * 1_000_000_000), duty: 50)
            }
        }
    }
    
    func shutdown() {
        gpios[.P14]!.value = 0
        stepPins.0.stopPWM()
        stepPins.1.stopPWM()
        gpios[sleepPins.0]!.value = 0
        gpios[sleepPins.1]!.value = 0
    }
    
    func getFaultPin(side: MotorSide) -> Int {
        if side == .left {
            return gpios[faultPins.0]!.value
        } else {
            return gpios[faultPins.1]!.value
        }
    }
}
