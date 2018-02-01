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
    var tomorrowSchoolStartTimes = Array<String>()
    var nextDayCounts = Array<Int>()
    var nextWeekCounts = Array<Int>()
    
    override init() {
        super.init()
    }
    
    func gatherNotificationData()
    {
        Logger.println("SNM: Gathering notification data...")
        
        scheduleInfoManager = ScheduleInfoManager(delegate: self, downloadData: false, onlyFindOneDay: true)
        scheduleInfoManager?.startInfoManager()
    }
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject, periodNames: Array<String>?) {
        return
    }
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>) {
        return
    }
    
    func printCurrentMessage(message: String) {
        return
    }
    
    func printInternalError(message: String, labelNumber: Int) {
        return
    }
    
    func printSchoolStartEndMessage(message: String) {
        return
    }
    
    func printSchoolStartEndTime(periodTimes: Array<String>) {
        return
    }
    
    func printTomorrowStartTime(tomorrowSchedule: NSManagedObject, nextWeekCount: Int, nextDayCount: Int) {
        if let tomorrowPeriodTimes = self.decodeArrayFromJSON(object: tomorrowSchedule, field: "periodTimes") as? Array<String>
        {
            let tomorrowSchoolStartTime = String(tomorrowPeriodTimes[0].split(separator: "-")[0])
            
            tomorrowSchoolStartTimes.append(tomorrowSchoolStartTime)
            nextDayCounts.append(nextDayCount)
            nextWeekCounts.append(nextWeekCount)
            
            findNextSchoolStartTime(nextDayCount: nextDayCount, nextWeekCount: nextWeekCount)
        }
    }
    
    func noSchoolTomorrow(nextDayCount: Int, nextWeekCount: Int) {
        tomorrowSchoolStartTimes.append("H")
        nextDayCounts.append(nextDayCount)
        nextWeekCounts.append(nextWeekCount)
        
        findNextSchoolStartTime(nextDayCount: nextDayCount, nextWeekCount: nextWeekCount)
    }
    
    func findNextSchoolStartTime(nextDayCount: Int, nextWeekCount: Int)
    {
        Logger.println("SNM: \(tomorrowSchoolStartTimes.count)/5")
        if tomorrowSchoolStartTimes.count < 5
        {
            let loadedNextWeek = nextWeekCount > 0
            scheduleInfoManager!.nextDayOn! += 1
            
            scheduleInfoManager!.queryTomorrowSchedule(weekSchedules: scheduleInfoManager!.nextWeekSchedules!, addDays: nextDayCount+1, loadedNextWeek: loadedNextWeek)
        }
        else
        {
            setupNotifications()
        }
    }
    
    func setupNotifications()
    {
        Logger.println("SNM: Setting up notifications...")
        
        var notificationsAdded = 0
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        var schoolStartTimeOn = 0
        for schoolStartTime in tomorrowSchoolStartTimes
        {
            if schoolStartTime != "H"
            {
                let schoolStartTimeNotificationContent = UNMutableNotificationContent()
                schoolStartTimeNotificationContent.title = "School starts at \(schoolStartTime) tomorrow"
                schoolStartTimeNotificationContent.body = "Open..."
                
                let triggerDateComponents = getDate(nextDay: nextDayCounts[schoolStartTimeOn], nextWeek: nextWeekCounts[schoolStartTimeOn])
                
                let schoolStartTimeNotificationTrigger = UNCalendarNotificationTrigger(dateMatching: triggerDateComponents, repeats: false)
                
                let schoolStartTimeNotification = UNNotificationRequest(identifier: UUID().uuidString,  content: schoolStartTimeNotificationContent, trigger: schoolStartTimeNotificationTrigger)
                
                UNUserNotificationCenter.current().add(schoolStartTimeNotification) { (error) in
                    Logger.println("Added notification at: " + String(describing: (schoolStartTimeNotification.trigger as! UNCalendarNotificationTrigger).dateComponents) + "-- " + schoolStartTimeNotificationContent.title)
                    notificationsAdded += 1
                    if notificationsAdded == schoolStartTimeOn
                    {
                        UNUserNotificationCenter.current().getPendingNotificationRequests { (notificationRequests) in
                            //Logger.println(notificationRequests)
                        }
                    }
                }
            }
            
            schoolStartTimeOn += 1
        }
        
        Logger.println("SNM: Set up notifications!")
    }
    
    func getDate(nextDay: Int, nextWeek: Int) -> DateComponents
    {
        var calculatedDate = Date().getStartOfNextWeek(nextWeek: nextWeek)
        var calculatedNextDay = nextDay
        if nextWeek > 0
        {
            calculatedNextDay += 1*nextWeek
        }
        calculatedDate.addTimeInterval(TimeInterval(nextDay*86400))
        
        var calculatedDateComponents = Date.Gregorian.calendar.dateComponents([.day, .month, .year, .hour, .minute], from: calculatedDate)
        
        let notificationAlertTime = (UserDefaults.standard.object(forKey: "notificationAlertTime") as? String) ?? "21:00"
        
        calculatedDateComponents.hour = Int(notificationAlertTime.split(separator: ":")[0])
        calculatedDateComponents.minute = Int(notificationAlertTime.split(separator: ":")[1])
        
        return calculatedDateComponents
    }
    
    func decodeArrayFromJSON(object: NSManagedObject, field: String) -> Array<Any>?
    {
        let JSONdata = object.value(forKey: field) as! Data
        do
        {
            let array = try JSONSerialization.jsonObject(with: JSONdata, options: .allowFragments) as! Array<Any>
            return array
        }
        catch
        {
            Logger.println(error)
            return nil
        }
    }
}
