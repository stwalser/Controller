//
//  Shutdown.swift
//  
//
//  Created by Stefan Walser on 10.07.22.
//

import Foundation

@discardableResult func shell(args: String...) async -> Int32 {
    let task = Process()
    task.executableURL = URL(string: "/usr/bin/env")
    task.arguments = args
    try! task.run()
    task.waitUntilExit()
    return task.terminationStatus
}
