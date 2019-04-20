//
//  ScheduleNotificationManager.swift
//  Schedule
//
//  Created by jackson on 12/23/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation
import CoreData
import UserNotifications

class ScheduleNotificationManager: NSObject, ScheduleInfoDelegate
{
    var scheduleInfoManager: ScheduleInfoManager?
    var tomorrowSchoolCodes = Array<String>()
    var nextDayCounts = Array<Int>()
    var nextWeekCounts = Array<Int>()
    
    let numberOfStartTimeNotifications = 5
    
    override init() {
        super.init()
    }
    
    func gatherNotificationData()
    {
        tomorrowSchoolCodes = []
        nextDayCounts = []
        nextWeekCounts = []
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        Logger.println("SNM: Gathering notification data...")
        
        scheduleInfoManager = ScheduleInfoManager(delegate: self, downloadData: false, onlyFindOneDay: true)
        scheduleInfoManager?.startInfoManager()
        
        if let todaySchedule = scheduleInfoManager?.queryTodaySchedule(weekSchedules: scheduleInfoManager?.queryWeekSchedule() ?? Array<String>()), let schoolNotifications = CoreDataStack.fetchLocalObjects(type: "SchoolNotification", predicate: NSPredicate(value: true)) as? [SchoolNotification], let periodTimes = CoreDataStack.decodeArrayFromJSON(object: todaySchedule, field: "periodTimes") as? Array<String>, let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: todaySchedule, field: "periodNumbers") as? Array<Int>
        {
            for notification in schoolNotifications
            {
                if notification.isEnabled && notification.shouldFireDayBefore == false
                {
                    setupScheduledNotification(notification: notification, periodTimes: periodTimes, periodNumbers: periodNumbers, nextDayCount: 0, nextWeekCount: 0, scheduleCode: todaySchedule.scheduleCode ?? "+")
                }
            }
        }
    }
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject) {
        return
    }
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>) {
        return
    }
    
    func printCurrentMessage(message: String) {
        return
    }
    
    func printInternalError(message: String, labelNumber: Int) {
        //findNextSchoolStartTime(nextDayCount: nextDayCounts.count+1, nextWeekCount: nextWeekCounts.count)
    }
    
    func printSchoolStartEndMessage(message: String) {
        return
    }
    
    func printSchoolStartEndTime(schoolStartTime: String, schoolEndTime: String) {
        return
    }
    
    func printTomorrowStartTime(tomorrowSchoolStartTime: String, tomorrowSchedule: Schedule, nextWeekCount: Int, nextDayCount: Int) {
        /*if let tomorrowPeriodTimes = self.decodeArrayFromJSON(object: tomorrowSchedule, field: "periodTimes") as? Array<String>
        {
            //let tomorrowSchoolStartTime = String(tomorrowPeriodTimes[0].split(separator: "-")[0])
        }*/
        
        if scheduleInfoManager?.offBlocks != nil || scheduleInfoManager?.getUserID() == nil
        {
            tomorrowSchoolCodes.append(tomorrowSchedule.scheduleCode ?? "H")
            nextDayCounts.append(nextDayCount)
            nextWeekCounts.append(nextWeekCount)
            
            findNextSchoolStartTime(nextDayCount: nextDayCount, nextWeekCount: nextWeekCount)
        }
    }
    
    func noSchoolTomorrow(nextDayCount: Int, nextWeekCount: Int) {
        tomorrowSchoolCodes.append("H")
        nextDayCounts.append(nextDayCount)
        nextWeekCounts.append(nextWeekCount)
        
        findNextSchoolStartTime(nextDayCount: nextDayCount, nextWeekCount: nextWeekCount)
    }
    
    func findNextSchoolStartTime(nextDayCount: Int, nextWeekCount: Int)
    {
        Logger.println("SNM: \(tomorrowSchoolCodes.count)/\(numberOfStartTimeNotifications)")
        if tomorrowSchoolCodes.count < numberOfStartTimeNotifications && scheduleInfoManager?.nextDayOn != nil
        {
            let loadedNextWeek = nextWeekCount > 0
            scheduleInfoManager!.nextDayOn! += 1
            
            if let tomorrowScheduleData = scheduleInfoManager!.queryTomorrowSchedule(weekSchedules: scheduleInfoManager!.nextWeekSchedules!, addDays: nextDayCount+1, loadedNextWeek: loadedNextWeek), let tomorrowSchedule = tomorrowScheduleData.schedule
            {
                self.printTomorrowStartTime(tomorrowSchoolStartTime: "", tomorrowSchedule: tomorrowSchedule, nextWeekCount: tomorrowScheduleData.nextWeekOn ?? 0, nextDayCount: (tomorrowScheduleData.nextDayOn ?? 0))
            }
        }
        else
        {
            setupNotifications()
        }
    }
    
    func setupNotifications()
    {
        Logger.println("SNM: Setting up notifications...")
                
        var scheduleCodeOn = 0
        for scheduleCode in tomorrowSchoolCodes
        {
            if scheduleCode != "H", let scheduleObject = CoreDataStack.fetchLocalObjects(type: "Schedule", predicate: NSPredicate(format: "scheduleCode == %@", scheduleCode)) as? [Schedule], scheduleObject.count > 0, let periodTimes = CoreDataStack.decodeArrayFromJSON(object: scheduleObject[0], field: "periodTimes") as? Array<String>, let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: scheduleObject[0], field: "periodNumbers") as? Array<Int>
            {
                setupStartTimeNotification(periodTimes: periodTimes, periodNumbers: periodNumbers, scheduleCodeOn: scheduleCodeOn)
                
                if let schoolNotifications = CoreDataStack.fetchLocalObjects(type: "SchoolNotification", predicate: NSPredicate(value: true)) as? [SchoolNotification]
                {
                    for notification in schoolNotifications
                    {
                        if notification.isEnabled
                        {
                            setupScheduledNotification(notification: notification, periodTimes: periodTimes, periodNumbers: periodNumbers, nextDayCount: nextDayCounts[scheduleCodeOn] + (notification.shouldFireDayBefore ? 0 : 1), nextWeekCount: nextWeekCounts[scheduleCodeOn], scheduleCode: scheduleCode)
                        }
                    }
                }
            }
            
            scheduleCodeOn += 1
        }
        
        Logger.println("SNM: Set up notifications!")
    }
    
    func get12HourTime(hour: Int, minute: Int) -> String
    {
        let hourString = (hour == 0 ? "12" : (hour > 12 ? String(hour-12) : String(hour)))
        let minuteString = (minute < 10 ? "0" : "") + String(minute)
        let AMPMString = (hour == 12 ? "PM" : (hour > 12 ? "PM" : "AM"))
        
        return hourString + ":" + minuteString + " " + AMPMString
    }
    
    func setupStartTimeNotification(periodTimes: Array<String>, periodNumbers: Array<Int>, scheduleCodeOn: Int)
    {
        let startingPeriodIndex = scheduleInfoManager?.findNextClassBlock(currentPeriodIndex: 0, periodNumbers: periodNumbers) ?? 0
        let schoolStartTime = String(periodTimes[startingPeriodIndex].split(separator: "-")[0])
        
        let schoolStartTimeNotificationContent = UNMutableNotificationContent()
        schoolStartTimeNotificationContent.title = "Tomorrow School Start Time"
        schoolStartTimeNotificationContent.body = "School starts at \(schoolStartTime) tomorrow"
        
        let notificationAlertTime = (UserDefaults.standard.object(forKey: "notificationAlertTime") as? String) ?? "21:00"
        
        let triggerDateComponents = getDate(nextDay: nextDayCounts[scheduleCodeOn], nextWeek: nextWeekCounts[scheduleCodeOn], alertTime: notificationAlertTime, addingOffset: 0)
        
        let schoolStartTimeNotificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
        
        let schoolStartTimeNotification = UNNotificationRequest(identifier: UUID().uuidString,  content: schoolStartTimeNotificationContent, trigger: schoolStartTimeNotificationTrigger)
        
        addNotification(schoolNotification: schoolStartTimeNotification)
    }
    
    func setupScheduledNotification(notification: SchoolNotification, periodTimes: Array<String>, periodNumbers: Array<Int>, nextDayCount: Int, nextWeekCount: Int, scheduleCode: String)
    {
        if let notificationPeriodArray = CoreDataStack.decodeArrayFromJSON(object: notification, field: "notificationPeriodArray") as? Array<Bool>, notification.schedulesToFireOn != nil, let notificationScheduleCodes = (try? JSONSerialization.jsonObject(with: notification.schedulesToFireOn!, options: JSONSerialization.ReadingOptions.allowFragments) as? Dictionary<String,Bool>)
        {
            var periodOn = 1
            for period in notificationPeriodArray
            {
                if period && (notificationScheduleCodes.keys.contains(scheduleCode) ? notificationScheduleCodes[scheduleCode] : notificationScheduleCodes["+"]) ?? true
                {
                    if let schoolPeriodTimeIndex = periodNumbers.firstIndex(of: Int(periodOn))
                    {
                        let schoolPeriodTime = periodTimes[schoolPeriodTimeIndex]
                        
                        let alertTime = notification.displayTimeAsOffset ?  (String(schoolPeriodTime.split(separator: "-")[(notification.shouldFireWhenPeriodStarts ? 0 : 1)])) : (String(notification.notificationTimeHour) + ":" + String(notification.notificationTimeMinute))
                        let triggerDateComponents = getDate(nextDay: nextDayCount, nextWeek: nextWeekCount, alertTime: alertTime, addingOffset: notification.displayTimeAsOffset ? Int(notification.notificationTimeOffset) : 0)
                        let schoolNotificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
                        
                        let schoolNotificationContent = UNMutableNotificationContent()
                        schoolNotificationContent.title = "Block \(periodOn)"
                        schoolNotificationContent.body = get12HourTime(hour: Int(schoolPeriodTime.split(separator: "-")[0].split(separator: ":")[0]) ?? 0, minute: Int(schoolPeriodTime.split(separator: "-")[0].split(separator: ":")[1]) ?? 0) + " - " + get12HourTime(hour: Int(schoolPeriodTime.split(separator: "-")[1].split(separator: ":")[0]) ?? 0, minute: Int(schoolPeriodTime.split(separator: "-")[1].split(separator: ":")[1]) ?? 0)
                        
                        let schoolNotification = UNNotificationRequest(identifier: UUID().uuidString, content: schoolNotificationContent, trigger: schoolNotificationTrigger)
                        
                        addNotification(schoolNotification: schoolNotification)
                    }
                }
                
                periodOn += 1
            }
        }
    }
    
    func addNotification(schoolNotification: UNNotificationRequest)
    {
        Logger.println("Added notification at: " + String(describing: (schoolNotification.trigger as! UNCalendarNotificationTrigger).dateComponents) + "-- " + schoolNotification.content.title + " / " + schoolNotification.content.body)
        
        UNUserNotificationCenter.current().add(schoolNotification) { (error) in
            
        }
    }
    
    func getDate(nextDay: Int, nextWeek: Int, alertTime: String, addingOffset: Int) -> DateComponents
    {
        var calculatedDate = Date().getStartOfNextWeek(nextWeek: nextWeek)
        var calculatedNextDay = nextDay
        if nextWeek == 0
        {
            calculatedNextDay += Date().getDayOfWeek()
        }
        calculatedDate = Date.Gregorian.calendar.date(byAdding: .day, value: calculatedNextDay, to: calculatedDate) ?? Date()
        
        var calculatedDateComponents = Date.Gregorian.calendar.dateComponents([.day, .month, .year, .hour, .minute, .timeZone], from: calculatedDate)
        
        calculatedDateComponents.hour = Int(alertTime.split(separator: ":")[0])
        calculatedDateComponents.minute = Int(alertTime.split(separator: ":")[1])
        
        calculatedDateComponents = Date.Gregorian.calendar.dateComponents([.day, .month, .year, .hour, .minute, .timeZone], from: Date.Gregorian.calendar.date(byAdding: .minute, value: addingOffset, to: Date.Gregorian.calendar.date(from: calculatedDateComponents) ?? Date()) ?? Date())
        
        return calculatedDateComponents
    }
}
