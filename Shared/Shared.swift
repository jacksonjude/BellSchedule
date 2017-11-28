//
//  Shared.swift
//  Schedule
//
//  Created by jackson on 11/27/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation
import CloudKit
import CoreData


extension Date {
    struct Gregorian {
        static let calendar = Calendar(identifier: .gregorian)
    }
    var startOfWeek: Date? {
        return Gregorian.calendar.date(from: Gregorian.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))
    }
    func getStartOfNextWeek(nextWeek: Int) -> Date {
        var nextWeekComponents = Gregorian.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekOfMonth], from: self)
        if nextWeekComponents.weekOfYear != nil
        {
            nextWeekComponents.weekOfYear! += nextWeek
        }
        return Gregorian.calendar.date(from: nextWeekComponents)!
    }
    func getDayOfWeek() -> Int {
        let todayDate = Date()
        let calendar = NSCalendar(calendarIdentifier: .gregorian)!
        let components = calendar.components(.weekday, from: todayDate)
        let weekDay = components.weekday
        return weekDay!-1
    }
    func getStringDayOfWeek(day: Int) -> String
    {
        switch day {
        case 0:
            return "Sunday"
        case 1:
            return "Monday"
        case 2:
            return "Tuesday"
        case 3:
            return "Wednesday"
        case 4:
            return "Thursday"
        case 5:
            return "Friday"
        case 6:
            return "Saturday"
        default:
            return ""
        }
    }
    func convertToStandardTime(date: String) -> String!
    {
        var hourMin = date.split(separator: ":")
        var newDate = date
        if Int(hourMin[0])! > 12
        {
            newDate = String(Int(hourMin[0])!-12) + ":" + hourMin[1]
        }
        return newDate
    }
}

protocol ScheduleInfoDelegate
{
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject, periodNames: Array<String>?)
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>)
    
    func printCurrentMessage(message: String)
    
    func printInternalError(message: String, labelNumber: Int)
    
    func printSchoolStartEndMessage(message: String)
    
    func printSchoolStartEndTime(periodTimes: Array<String>)
    
    func printTomorrowStartTime(tomorrowSchedule: NSManagedObject, nextWeekCount: Int, nextDayCount: Int)
}
