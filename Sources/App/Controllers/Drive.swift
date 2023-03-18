//
//  Drive.swift
//  
//
//  Created by Stefan Walser on 10.07.22.
//

import Foundation
import Vapor

var currentTarget: (Instruction?, Instruction?)
let stopInstruction = (Instruction(rpm: 0, dir: .forward, side: .left), Instruction(rpm: 0, dir: .forward, side: .right))
var currentInstruction = stopInstruction

private let queue = DispatchQueue(label: "com.rtplatform.gpiocontrol")
private var timer = DispatchSource.makeTimerSource(queue: queue)

let gpioController = GPIOController()
// Every 0.1 seconds the PWM signal is updated
let PWMUpdateInterval = 0.1

private let limitContrary = 50.0
private let limitUnary = 125.0
let increaseRPMAMount = 8.0
let decreaseRPMAmount = 25.0

func initializeDriveController() {
    timer.schedule(deadline: .now(), repeating: PWMUpdateInterval, leeway: .seconds(0))
    timer.setEventHandler {
        updatePWM()
    }
    timer.resume()
}

/// Reads the current target for either track, calcualtes the steps that are necessary to reach it, makes sure the RPM limits are respeceted, gets the microsteps and sets the pins and the PWM.
func updatePWM() {
    if currentTarget.0 != nil {
        currentInstruction.0 = calculateNewIntermediateStep(from: currentInstruction.0, to: currentTarget.0!)
    }
    
    if currentTarget.1 != nil {
        currentInstruction.1 = calculateNewIntermediateStep(from: currentInstruction.1, to: currentTarget.1!)
    }
    
    limitRPMs()
    
    let µSteps = (getµSteps(rpm: currentInstruction.0.rpm), getµSteps(rpm: currentInstruction.1.rpm))
    let stepsPerSecond = (getStepsPerSecond(for: currentInstruction.0.rpm, with: µSteps.0), getStepsPerSecond(for: currentInstruction.1.rpm, with: µSteps.1))
            
    gpioController.setDirectionAndMicrostepping(at: currentInstruction.0.side, to: currentInstruction.0.dir, and: µSteps.0)
    gpioController.setDirectionAndMicrostepping(at: currentInstruction.1.side, to: currentInstruction.1.dir, and: µSteps.1)

    gpioController.changePWM(at: currentInstruction.0.side, to: stepsPerSecond.0)
    gpioController.changePWM(at: currentInstruction.1.side, to: stepsPerSecond.1)
        }

func stopVehicle() {
    currentTarget = stopInstruction
}

private func getStepsPerSecond(for rpm: Double, with microsteps: Double) -> Double {
    rpm / 60.0 * 200.0 * microsteps
}

/// These limits are necessaray to prevent the tracks from blocking.
private func limitRPMs() {
    if currentInstruction.0.dir == currentInstruction.1.dir || currentInstruction.0.rpm == 0 || currentInstruction.1.rpm == 0 {
        currentInstruction.0.rpm = min(currentInstruction.0.rpm, currentInstruction.1.rpm + limitUnary)
        currentInstruction.1.rpm = min(currentInstruction.1.rpm, currentInstruction.0.rpm + limitUnary)
    } else {
        currentInstruction.0.rpm = min(currentInstruction.0.rpm, limitContrary)
        currentInstruction.1.rpm = min(currentInstruction.1.rpm, limitContrary)
    }
}

private func calculateNewIntermediateStep(from cur: Instruction, to target: Instruction) -> Instruction {
    var newCurrent = cur
    
    if target.dir == cur.dir {
        if target.rpm > cur.rpm { // increase RPM
            if cur.rpm + increaseRPMAMount <= target.rpm { // limit will not be reached
                newCurrent.rpm = cur.rpm + increaseRPMAMount
            } else { // limit will be reached
                newCurrent.rpm = target.rpm
            }
        } else if target.rpm < cur.rpm { // decrease RPM
            if cur.rpm - decreaseRPMAmount >= target.rpm { // limit will not be reached
                newCurrent.rpm = cur.rpm - decreaseRPMAmount
            } else { // limit will be reached
                newCurrent.rpm = target.rpm
            }
        }
    } else {
        if cur.rpm - decreaseRPMAmount >= 0 { // limit will not be reached
            newCurrent.rpm = cur.rpm - decreaseRPMAmount
        } else { // limit will be reached
            newCurrent.rpm = 0
            newCurrent.dir = target.dir
        }
    }
    
    return newCurrent
}

private func getµSteps(rpm: Double) -> Double {
    if rpm <= 50 {
        return 16
    } else if rpm <= 100 {
        return 8
    } else if rpm <= 200 {
        return 4
    } else {
        return 2
    }
}

/// An enumeration for the two sides
enum MotorSide: Int, Codable {
    case left
    case right
}

/// An enumeration for the two sides
enum MotorDirection: String, Codable {
    case forward = "Vorwärts"
    case backward = "Rückwärts"
}

/// A struct that represents an instruction. Consist of Rpm and direction of the motor
struct Instruction: Content {
    var rpm: Double
    var dir: MotorDirection
    var side: MotorSide
}
