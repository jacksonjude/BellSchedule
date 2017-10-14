//
//  ScheduleInfoManager.swift
//  Schedule
//
//  Created by jackson on 10/9/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import CloudKit
import UIKit

class ScheduleInfoManager: NSObject {
    var viewController: ScheduleInfoViewController
    let appDelegate = UIApplication.shared.delegate! as! AppDelegate
    
    var nextWeekSchedules: Array<String>?
    
    var periodNames: Array<String>?
    var periodPrinted = false
    var periodNumber: Int?
    
    var todaySchedule: CKRecord?
    
    var tomorrowDay: Date?
    var nextWeekOn: Int?
    var nextDayOn: Int?
    
    var loadedNextWeekDictionary: Dictionary<String,Bool> = [:]
    
    init(viewController: ScheduleInfoViewController) {
        self.viewController = viewController
        super.init()
    }
    
    func refreshScheduleInfo()
    {
        getUserID()
        queryWeekSchedule()
    }
    
    //MARK: UserSchedule
    
    func getUserID()
    {
        print(" USRID: Fetching userID")
        if let userID = UserDefaults.standard.object(forKey: "userID") as? String
        {
            print(" USRID: userID: " + userID)
            queryUserSchedule(userID: userID)
        }
        else
        {
            print(" USRID: No userID")
        }
    }
    
    func queryUserSchedule(userID: String)
    {
        print(" USRSCH: Fetching periodNamesRecord")
        let userScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUserSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + userScheduleReturnID), object: nil)
        
        let userScheduleQueryPredicate = NSPredicate(format: "userID == %@", userID)
        appDelegate.cloudManager!.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: userScheduleReturnID)
    }
    
    @objc func receiveUserSchedule(notification: NSNotification)
    {
        if let periodNamesRecord = notification.object as? CKRecord
        {
            print(" USRSCH: Received periodNamesRecord")
            periodNames = periodNamesRecord.object(forKey: "periodNames") as? [String]
            
            if periodPrinted
            {
                if periodNames!.count > periodNumber!-1
                {
                    viewController.printPeriodName(todaySchedule: self.todaySchedule!, periodNames: periodNames!)
                }
            }
        }
        else
        {
            print(" USRSCH: Did not receive periodNamesRecord")
        }
    }
    
    //MARK: Week Schedule
    
    func queryWeekSchedule()
    {
        print(" FWSCH: Fetching weekScheduleRecord")
        let weekScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveWeekScheduleRecord(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + weekScheduleReturnID), object: nil)
        
        let startOfWeekRaw = Date().startOfWeek ?? Date()
        let gregorian = Calendar(identifier: .gregorian)
        var components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfWeekRaw)
        components.hour = 12
        let startOfWeekFormatted = gregorian.date(from: components)!
        
        let weekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfWeekFormatted as CVarArg)
        appDelegate.cloudManager!.fetchPublicDatabaseObject(type: "WeekSchedules", predicate: weekScheduleQueryPredicate, returnID: weekScheduleReturnID)
    }
    
    @objc func receiveWeekScheduleRecord(notification: NSNotification)
    {
        if let weekScheduleRecord = notification.object as? CKRecord
        {
            print(" FWSCH: Received weekScheduleRecord")
            viewController.printCurrentStatus(message: "Loading...\nReceived weekScheduleRecord")
            
            let schedules = weekScheduleRecord.object(forKey: "schedules") as! Array<String>
            
            self.nextWeekSchedules = schedules
            queryTodaySchedule(weekSchedules: schedules)
            nextWeekOn = 0
            nextDayOn = 0
            let tomorrowNotificationID = UUID().uuidString
            self.loadedNextWeekDictionary[tomorrowNotificationID] = false
            queryTomorrowSchedule(weekSchedules: schedules, addDays: 0, notificationID: tomorrowNotificationID)
        }
        else
        {
            print(" FWSCH: Did not receive weekScheduleRecord")
            viewController.printCurrentStatus(message: "Error on query")
        }
    }
    
    //MARK: Today Schedule
    
    func queryTodaySchedule(weekSchedules: Array<String>)
    {
        let currentDay = Date().getDayOfWeek()-1
        if currentDay < weekSchedules.count && currentDay >= 0
        {
            let todaySchedule = weekSchedules[currentDay]
            print(" FTODYS: currentDay == " + String(currentDay) + " and todaySchedule == " + todaySchedule)
            
            print(" FTODYS: Fetching todaySchedule")
            
            let todayScheduleReturnID = UUID().uuidString
            NotificationCenter.default.addObserver(self, selector: #selector(receiveTodaySchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + todayScheduleReturnID), object: nil)
            
            let todayScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", todaySchedule)
            appDelegate.cloudManager!.fetchPublicDatabaseObject(type: "Schedule", predicate: todayScheduleQueryPredicate, returnID: todayScheduleReturnID)
        }
        else
        {
            print(" FTODYS: currentDay out of schedule range")
            viewController.printCurrentStatus(message: "No school today")
            
            viewController.printSchoolStartTimeStatus(status: "No school today")
        }
    }
    
    @objc func receiveTodaySchedule(notification: NSNotification)
    {
        if let todaySchedule = notification.object as? CKRecord
        {
            print(" FTODYS: Received todaySchedule")
            viewController.printCurrentStatus(message: "Received todaySchedule")
            
            self.todaySchedule = todaySchedule
            
            let todayCode = todaySchedule.object(forKey: "scheduleCode") as! String
            if todayCode != "H"
            {
                let periodTimes = todaySchedule.object(forKey: "periodTimes") as! Array<String>
                findCurrentPeriod(periodTimes: periodTimes)
            }
            else
            {
                print(" FTODYS: todayCode == H, No school today")
                viewController.printCurrentStatus(message: "No school today")
                viewController.printSchoolStartTimeStatus(status: "No school today")
            }
        }
        else
        {
            print(" FTODYS: Did not receive todaySchedule")
            viewController.printCurrentStatus(message: "Error on query")
        }
    }
    
    //MARK: Tomorrow Schedule
    
    func queryTomorrowSchedule(weekSchedules: Array<String>, addDays: Int, notificationID: String)
    {
        var tomorrowSchedule = ""
        var currentlyLoadingNextWeek = false
        var tomorrowDate = addDays
        
        if !loadedNextWeekDictionary[notificationID]!
        {
            tomorrowDate = Date().getDayOfWeek()+addDays
        }
        
        if tomorrowDate < weekSchedules.count && tomorrowDate >= 0
        {
            tomorrowSchedule = weekSchedules[tomorrowDate]
            print(" FTOMWS: tomorrowDate == " + String(tomorrowDate) + " and tomorrowSchedule == " + tomorrowSchedule)
        }
        else
        {
            print(" FTOMWS: tomorrowDate out of schedule range, loading next week")
            nextWeekOn! += 1
            nextDayOn = 0
            queryNextWeek(notificationID: notificationID)
            currentlyLoadingNextWeek = true
        }
        
        if !currentlyLoadingNextWeek
        {
            print(" FTOMWS: Fetching tomorrowSchedule")
            
            let tomorrowScheduleReturnID = UUID().uuidString
            NotificationCenter.default.addObserver(self, selector: #selector(receiveTomorrowSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + tomorrowScheduleReturnID + ":" + notificationID), object: nil)
            
            let tomorrowScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", tomorrowSchedule)
            appDelegate.cloudManager!.fetchPublicDatabaseObject(type: "Schedule", predicate: tomorrowScheduleQueryPredicate, returnID: tomorrowScheduleReturnID + ":" + notificationID)
        }
    }
    
    @objc func receiveTomorrowSchedule(notification: NSNotification)
    {
        if let tomorrowSchedule = notification.object as? CKRecord
        {
            print(" FTOMWS: Received tomorrowSchedule")
            
            let tomorrowScheduleCode = tomorrowSchedule.object(forKey: "scheduleCode") as! String
            if tomorrowScheduleCode != "H"
            {
                print(" FTOMWS: Tomorrow schedule found!")
                self.loadedNextWeekDictionary.remove(at: self.loadedNextWeekDictionary.index(forKey: String(notification.name.rawValue.split(separator: ":")[2]))!)
                viewController.printTomorrowStartTime(tomorrowSchedule: tomorrowSchedule, nextWeekCount: nextWeekOn!, nextDayCount: nextDayOn!)
            }
            else
            {
                print(" FTOMWS: No school tomorrow, loading next day")
                nextDayOn!+=1
                
                queryTomorrowSchedule(weekSchedules: self.nextWeekSchedules!, addDays: nextDayOn!, notificationID: String(notification.name.rawValue.split(separator: ":")[2]))
            }
        }
        else
        {
            print(" FTOMWS: Did not receive tomorrowSchedule")
        }
    }
    
    //MARK: Next Week Schedule
    
    func queryNextWeek(notificationID: String)
    {
        print(" FNXTWK: Fetching nextWeekScheduleRecord")
        
        let nextWeekScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNextWeekSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + nextWeekScheduleReturnID + ":" + notificationID), object: nil)
        
        let startOfNextWeekRaw = Date().getStartOfNextWeek(nextWeek: nextWeekOn!)
        let gregorian = Calendar(identifier: .gregorian)
        var components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfNextWeekRaw)
        components.hour = 12
        let startOfNextWeekFormatted = gregorian.date(from: components)!
        
        let nextWeekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfNextWeekFormatted as CVarArg)
        appDelegate.cloudManager!.fetchPublicDatabaseObject(type: "WeekSchedules", predicate: nextWeekScheduleQueryPredicate, returnID: nextWeekScheduleReturnID + ":" + notificationID)
    }
    
    @objc func receiveNextWeekSchedule(notification: NSNotification)
    {
        if let nextWeekScheduleRecord = notification.object as? CKRecord
        {
            print(" FNXTWK: Received nextWeekScheduleRecord")
            let schedules = nextWeekScheduleRecord.object(forKey: "schedules") as! Array<String>
            self.nextWeekSchedules = schedules
            loadedNextWeekDictionary[String(notification.name.rawValue.split(separator: ":")[2])] = true
            queryTomorrowSchedule(weekSchedules: schedules, addDays: 0, notificationID: String(notification.name.rawValue.split(separator: ":")[2]))
        }
        else
        {
            print(" FNXTWK: Did not receive nextWeekScheduleRecord")
        }
    }
    
    //MARK: Find Current Period
    
    func getDate(hourMinute: Substring, day: Date) -> Date
    {
        let hourMinuteSplit = hourMinute.split(separator: ":")
        let gregorian = Calendar(identifier: .gregorian)
        var dateComponents = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: day)
        dateComponents.hour = Int(hourMinuteSplit[0])
        dateComponents.minute = Int(hourMinuteSplit[1])
        dateComponents.second = 0
        let periodStartDate = gregorian.date(from: dateComponents)!
        
        return periodStartDate
    }
    
    func findCurrentPeriod(periodTimes: Array<String>)
    {
        print(" FCURPER: Finding current period")
        let currentDate = Date()
        var periodOn = 1
        var periodFound = false
        var lastPeriodEnd: Date?
        var passingPeriod = false
        var nextPeriodStart: Substring?
        var nextPeriodNumber: Int?
        var schoolHasNotStarted = false
        viewController.setSchoolStartEndLabel(periodTimes: periodTimes)
        
        for periodRangeString in periodTimes
        {
            viewController.printCurrentStatus(message: "Loading...\nperiodOn == " + String(periodOn))
            
            let periodRangeArray = periodRangeString.split(separator: "-")
            
            let periodStart = getDate(hourMinute: periodRangeArray[0], day: currentDate)
            let periodEnd = getDate(hourMinute: periodRangeArray[1], day: currentDate)
            
            if periodStart < periodEnd
            {
                let periodRange = periodStart ... periodEnd
                
                let periodRangeContainsDate = periodRange.contains(Date())
                print(" FCURPER: periodOn == " + String(periodOn) + " : " + String(periodRange.contains(Date())))
                
                if periodRangeContainsDate
                {
                    periodFound = true
                    print(" FCURPER: Found current period!")
                    viewController.printCurrentPeriod(periodRangeString: periodRangeString, periodNumber: periodOn, todaySchedule: self.todaySchedule!, periodNames: self.periodNames)
                    
                    break
                }
                else if lastPeriodEnd != nil
                {
                    let passingPeriodRange = lastPeriodEnd!...periodStart
                    if passingPeriodRange.contains(currentDate)
                    {
                        passingPeriod = true
                        nextPeriodStart = periodRangeArray[0]
                        
                        let periodNumbers = todaySchedule!.object(forKey: "periodNumbers") as! Array<Int>
                        nextPeriodNumber = periodNumbers[periodOn-1]
                        
                        break
                    }
                }
                else if periodOn == 1
                {
                    if currentDate < periodStart
                    {
                        schoolHasNotStarted = true
                    }
                }
            }
            else
            {
                print("Skipping due to invalid date range")
            }
            
            lastPeriodEnd = periodEnd
            
            periodOn += 1
        }
        
        if !periodFound
        {
            if passingPeriod
            {
                print(" FCURPER: Currently passing period")
                let passingPeriodMessage1 = "Passing Period\nPeriod " + String(describing: nextPeriodNumber!) + " starts at "
                var passingPeriodMessage2 = Date().convertToStandardTime(date: String(nextPeriodStart!)) + "\n"
                
                if periodNames != nil
                {
                    passingPeriodMessage2 = passingPeriodMessage2 + periodNames![nextPeriodNumber!-1]
                }
                viewController.printCurrentStatus(message: passingPeriodMessage1 + passingPeriodMessage2)
            }
            else
            {
                if schoolHasNotStarted
                {
                    print(" FCURPER: School has not started")
                    viewController.printCurrentStatus(message: "School has not started")
                }
                else
                {
                    print(" FCURPER: School has ended")
                    viewController.printCurrentStatus(message: "School has ended")
                }
            }
        }
    }
}
