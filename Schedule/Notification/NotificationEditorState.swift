//
//  NotificationEditorState.swift
//  Schedule
//
//  Created by jackson on 10/31/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation

enum NotificationEditorViewType
{
    case none
    case period
    case time
    case beforeAfterStartEnd
}

class NotificationEditorState
{
    static var notificationPeriodArray: [Bool]?
    static var notificationTimeOffset: Int?
    static var notificationTimeHour: Int?
    static var notificationTimeMinute: Int?
    static var shouldFireWhenPeriodStarts: Bool?
    static var shouldFireDayBefore: Bool?
    static var displayTimeAsOffset: Bool?
    
    static var editorViewType: NotificationEditorViewType = .none
}
