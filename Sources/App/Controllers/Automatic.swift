//
//  Automatic.swift
//  
//
//  Created by Stefan Walser on 19.07.22.
//

import Foundation
import Vapor

var currentLLProgram: LLProgram?

typealias AutoProgram = [HighLevelInstruction]
typealias LLProgram = [LowLevelInstruction]

var autoProgramTimer: DispatchSourceTimer?

private let straightRPM = 100.0
private let trackCircumference = 0.47 / 2.5 / 2 // m
private let oneDegreeDistance = 0.205 * Double.pi / 360

private let spacerInstruction = LowLevelInstruction(duration: 0.5, instructions: stopInstruction)

private let autoProgramQueue = DispatchQueue(label: "com.rtplatform.autoProgramTimer")

struct HighLevelInstruction: Content {
    init(type: DrivingType, duration: TimeInterval, direction: MotorDirection) {
        self.type = type
        self.duration = duration
        self.direction = direction
    }
    
    init(type: DrivingType, distance: Double, direction: MotorDirection) {
        self.type = type
        self.distance = distance
        self.direction = direction
    }
    
    init(type: DrivingType, degrees: Double) {
        self.type = type
        self.degrees = degrees
    }
    
    var type: DrivingType
    var duration: TimeInterval?
    var degrees: Double?
    var direction: MotorDirection?
    var distance: Double?
}

struct LowLevelInstruction {
    var duration: TimeInterval
    var instructions: (Instruction, Instruction)
}

fileprivate func highSpeedTime(for d: Double, speed s: Double) -> Double {
    return (d / trackCircumference) * (60 / s)
}

func parseAutoProgram(_ program: AutoProgram) {
    var lowLevelProgram = LLProgram()
    
    for highLevelInst in program {
        switch highLevelInst.type {
        case .straightTime:
            let slowDownDuration = ((straightRPM / decreaseRPMAmount).rounded(.up) - 1) * PWMUpdateInterval
            
            lowLevelProgram.append(
                LowLevelInstruction(duration: highLevelInst.duration! - slowDownDuration,
                                    instructions: (Instruction(rpm: straightRPM, dir: highLevelInst.direction!, side: .left),
                                                   Instruction(rpm: straightRPM, dir: highLevelInst.direction!, side: .left)
                                                  )
                                   )
            )
            
            lowLevelProgram.append(
                LowLevelInstruction(duration: slowDownDuration,
                                    instructions: (Instruction(rpm: 0, dir: highLevelInst.direction!, side: .left),
                                                   Instruction(rpm: 0, dir: highLevelInst.direction!, side: .right)
                                                  )
                                   )
            )
            
        case .straightDistance:
            var accelarationTime = 0.0
            var brakeTime = 0.0
            var rpm = 0.0
            var distanceLeft = 0.0
            
            calculateParameters(&rpm, &accelarationTime, highLevelInst.distance!, &brakeTime, &distanceLeft, limit: straightRPM)
            let highSpeedTime = highSpeedTime(for: distanceLeft, speed: rpm)

            lowLevelProgram.append(
                LowLevelInstruction(duration: accelarationTime + highSpeedTime,
                                    instructions: (Instruction(rpm: rpm, dir: highLevelInst.direction!, side: .left),
                                                   Instruction(rpm: rpm, dir: highLevelInst.direction!, side: .right)
                                                  )
                                   )
            )
            lowLevelProgram.append(
                LowLevelInstruction(duration: brakeTime,
                                    instructions: (Instruction(rpm: 0, dir: highLevelInst.direction!, side: .left),
                                                   Instruction(rpm: 0, dir: highLevelInst.direction!, side: .right)
                                                  )
                                   )
            )
        case .turn:
            let turnRight = highLevelInst.degrees! > 0
            let distanceToDrive = oneDegreeDistance * abs(highLevelInst.degrees!)
            
            var accelarationTime = 0.0
            var brakeTime = 0.0
            var rpm = 0.0
            var distanceLeft = 0.0
            calculateParameters(&rpm, &accelarationTime, distanceToDrive, &brakeTime, &distanceLeft, limit: 50.0)
            let highSpeedTime = highSpeedTime(for: distanceLeft, speed: rpm)
            
            lowLevelProgram.append(
                LowLevelInstruction(duration: accelarationTime + highSpeedTime,
                                    instructions: (Instruction(rpm: rpm, dir: turnRight ? .forward : .backward, side: .left),
                                                   Instruction(rpm: rpm, dir: turnRight ? .backward : .forward, side: .right)
                                                  )
                                   )
            )
            lowLevelProgram.append(
                LowLevelInstruction(duration: brakeTime,
                                    instructions: (Instruction(rpm: 0, dir: turnRight ? .forward : .backward, side: .left),
                                                   Instruction(rpm: 0, dir: turnRight ? .backward : .forward, side: .right)
                                                  )
                                   )
            )
        }
        
        lowLevelProgram.append(spacerInstruction)
    }
    
    currentLLProgram = lowLevelProgram
}

private var index = 0

private func doAutoProgramStep(_ ws: WebSocket) {
    if index == currentLLProgram!.count {
        _ = ws.close(code: .goingAway)
        index = 0
        return
    }
    
    let lowLevelInst = currentLLProgram![index]
    index += 1
    currentTarget = lowLevelInst.instructions
    
    ws.send("\(Double(index) / Double(currentLLProgram!.count))")
    
    autoProgramTimer = DispatchSource.makeTimerSource(queue: autoProgramQueue)
    autoProgramTimer!.schedule(deadline: .now() + lowLevelInst.duration, repeating: .never)
    
    autoProgramTimer!.setEventHandler {
        doAutoProgramStep(ws)
    }
    
    autoProgramTimer?.setCancelHandler {
        index = 0
    }
    
    autoProgramTimer!.resume()
}

func startAutoRunAndUpdateVia(websocket ws: WebSocket) {
    doAutoProgramStep(ws)
}

fileprivate func distanceFor(_ rpm: Double) -> Double {
    return (rpm / 60) * trackCircumference * PWMUpdateInterval
}

fileprivate func calculateParameters(_ rpm: inout Double, _ accelarationTime: inout Double, _ distance: Double, _ breakTime: inout Double, _ distanceLeft: inout Double, limit: Double) {
    var accelarationDistance = 0.0
    var brakeDistance = 0.0
    
    while rpm < limit {
        accelarationTime += PWMUpdateInterval
        rpm = min(rpm + increaseRPMAMount, limit)
        
        accelarationDistance += distanceFor(rpm)
        let result = breakingTimeAndDistance(for: rpm)
        brakeDistance = result.1

        if accelarationDistance + brakeDistance > distance {
            accelarationTime -= PWMUpdateInterval
            rpm -= increaseRPMAMount
            accelarationDistance -= distanceFor(rpm)
            break
        }
        breakTime = result.0
    }
    
    distanceLeft = distance - accelarationDistance - brakeDistance
}

fileprivate func breakingTimeAndDistance(for rpm: Double) -> (Double, Double) {
    var currentRPM = rpm
    var timePassed = 0.0
    var distanceDriven = 0.0
    
    while currentRPM > 0  {
        timePassed += PWMUpdateInterval
        currentRPM = max(currentRPM - decreaseRPMAmount, 0)
        
        distanceDriven += distanceFor(currentRPM)
    }
    
    return (timePassed - PWMUpdateInterval, distanceDriven) // correction necessary because the last step after zero rpm is reached takes no time
}

enum DrivingType: String, Codable {
    case straightTime
    case straightDistance
    case turn
}
