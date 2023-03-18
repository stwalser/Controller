import Vapor

// Signalizes if a websocket connection is active. They are needed for manual steering and automatic steering.
var connectionActive = false
// The websocket for the current connection.
var currentWebSocket: WebSocket?

func routes(_ app: Application) throws {
//    Entry point for the status information of the vehicle.
    app.get("status") { _ -> Status in
        Status(faultLeft: gpioController.getFaultPin(side: .left),
               faultRight: gpioController.getFaultPin(side: .right),
               currentTargetLeft: currentTarget.0,
               currentTargetRight: currentTarget.1,
               currentInstructionLeft: currentInstruction.0,
               currentInstructionRight: currentInstruction.1,
               mode: platformMode
        )
    }
    
//    Entry point to stop the vehicle.
    app.put("quit") { _ -> Int  in
        quit()
    }
    
//    Entry point to shut down the RaspberryPi.
    app.put("shutdown") { _ in
        await shell(args: "sudo", "shutdown", "now")
    }
    
//    Entry point to connect to the vehicle for manual steering.
    app.webSocket("connect", shouldUpgrade: { req -> EventLoopFuture<HTTPHeaders?> in
        if !connectionActive && platformMode == .HTTPManual {
            connectionActive = true
            return req.eventLoop.makeSucceededFuture([:])
        } else {
            return req.eventLoop.makeSucceededFuture(nil)
        }
        
    }) { _, ws in
        currentWebSocket = ws
        
        ws.onBinary { ws, bytes in
            do {
                let instructionMessage = try JSONDecoder().decode(Instruction.self, from: bytes)
                if instructionMessage.side == .left {
                    currentTarget.0 = instructionMessage
                } else {
                    currentTarget.1 = instructionMessage
                }
            } catch {
                ws.send("Invalid message")
            }
        }
        
        ws.onClose.whenComplete { result in
            currentWebSocket = nil
            connectionActive = false
        }
    }
    
//    Entry point for starting an automatic program. When the connection is closed, the vehicle stops automatically.
    app.webSocket("auto", "start", shouldUpgrade: { req -> EventLoopFuture<HTTPHeaders?> in
        if !connectionActive && platformMode == .HTTPAutomatic {
            connectionActive = true
            return req.eventLoop.makeSucceededFuture([:])
        } else {
            return req.eventLoop.makeSucceededFuture(nil)
        }
    }) { _, ws in
        currentWebSocket = ws
        
        if currentLLProgram != nil {
            startAutoRunAndUpdateVia(websocket: currentWebSocket!)
        } else {
            _ = ws.close(code: .policyViolation)
        }
        
        ws.onClose.whenComplete { result in
            print("Closed")
            if autoProgramTimer != nil {
                if !autoProgramTimer!.isCancelled {
                    autoProgramTimer!.cancel()
                    autoProgramTimer = nil
                    stopVehicle()
                }
            }
            
            currentWebSocket = nil
            connectionActive = false
        }
    }
    
//    Entry point for uploading an automatic program to the vehicle.
    app.put("auto", "program") { req -> HTTPStatus in
        if platformMode == .HTTPAutomatic && !connectionActive {
            let autoProgram = try req.content.decode(AutoProgram.self)
            parseAutoProgram(autoProgram)
            return HTTPStatus.ok
        } else {
            return HTTPStatus.methodNotAllowed
        }
    }
    
//    Entry point for changing the driving mode of the vehicle.
    app.put("mode") { req -> HTTPStatus in
            let mode = try req.content.decode(PlatformMode.self)
            platformMode = mode
            if mode != .HTTPManual {
                if let ws = currentWebSocket {
                    ws.close(promise: nil)
                    currentWebSocket = nil
                    connectionActive = false
                }
            }
            return HTTPStatus.ok
    }
}
