//
//  Logger.swift
//  Schedule
//
//  Created by jackson on 10/16/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation

class Logger: NSObject
{
    static var printedData = ""
    
    static func println(_ message: Any)
    {
        print(message)
        Logger.printedData = printedData + String(describing: message) + "\n"
        NotificationCenter.default.post(name: Notification.Name(rawValue: "loggerChangedData"), object: nil)
    }
}
