//
//  ScheduleInfoManager.swift
//  Schedule
//
//  Created by jackson on 10/9/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import CloudKit
import UIKit
import CoreData

class ScheduleInfoManager: NSObject {
    var viewController: ScheduleInfoViewController
    
    var nextWeekSchedules: Array<String>?
    
    var periodNames: Array<String>?
    var periodPrinted = false
    var periodNumber: Int?
    
    var todaySchedule: NSManagedObject?
    
    var tomorrowDay: Date?
    var nextWeekOn: Int?
    var nextDayOn: Int?
    
    var loadedData = 0
    {
        didSet
        {
            if loadedData == 2
            {
                loadedAllData = true
            }
            else
            {
                loadedAllData = false 
            }
        }
    }
    
    var loadedAllData = false
    
    init(viewController: ScheduleInfoViewController) {
        self.viewController = viewController
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(finishedFetchingData), name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)
        
        downloadCloudData()
    }
    
    func downloadCloudData()
    {
        self.loadedData = 0
        
        UserDefaults.standard.set(Date(), forKey: "fetchingCloudData")
        
        appDelegate.cloudManager!.fetchAllCloudData(entityType: "WeekSchedules")
        appDelegate.cloudManager!.fetchAllCloudData(entityType: "Schedule")
        //appDelegate.cloudManager!.fetchAllCloudData(entityType: "UserSchedule")
    }
    
    @objc func finishedFetchingData()
    {
        loadedData += 1
        if loadedAllData
        {
            UserDefaults.standard.set(UserDefaults.standard.object(forKey: "fetchingCloudData"), forKey: "lastUpdatedData")
            logger.println("↓ - Finished fetching changes from cloud")
            refreshScheduleInfo()
        }
    }
    
    func refreshScheduleInfo()
    {
        getUserID()
        queryWeekSchedule()        
    }
    
    //MARK: UserSchedule
    
    func getUserID()
    {
        logger.println(" USRID: Fetching userID")
        if let userID = UserDefaults.standard.object(forKey: "userID") as? String
        {
            logger.println(" USRID: userID: " + userID)
            queryUserSchedule(userID: userID)
        }
        else
        {
            logger.println(" USRID: No userID")
        }
    }
    
    func queryUserSchedule(userID: String)
    {
        let queryUserScheduleID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUserSchedule(notification:)), name: Notification.Name("fetchedPublicDatabaseObject:" + queryUserScheduleID), object: nil)
        
        logger.println(" USRSCH: Fetching periodNamesRecord")
        let userScheduleQueryPredicate = NSPredicate(format: "userID == %@", userID)
        
        appDelegate.cloudManager!.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: queryUserScheduleID)
        
        /*if let periodNamesRecord = appDelegate.cloudManager!.fetchLocalObjects(type: "UserSchedule", predicate: userScheduleQueryPredicate)?.first as? NSManagedObject
        {
            print(" USRSCH: Received periodNamesRecord")
            periodNames = periodNamesRecord.value(forKey: "periodNames") as? [String]
            
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
        }*/
    }
    
    @objc func receiveUserSchedule(notification: NSNotification)
    {
        if let periodNamesRecord = notification.object as? CKRecord
        {
            logger.println(" USRSCH: Received periodNamesRecord")
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
            logger.println(" USRSCH: Did not receive periodNamesRecord")
        }
    }
    
    //MARK: Week Schedule
    
    func queryWeekSchedule()
    {
        logger.println(" FWSCH: Fetching weekScheduleRecord")
        
        let startOfWeekRaw = Date().startOfWeek ?? Date()
        let gregorian = Calendar(identifier: .gregorian)
        var startOfWeekComponents = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfWeekRaw)
        startOfWeekComponents.hour = 12
        let startOfWeekFormatted = gregorian.date(from: startOfWeekComponents)!
        
        let weekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfWeekFormatted as CVarArg)
        if let weekScheduleRecord = appDelegate.cloudManager!.fetchLocalObjects(type: "WeekSchedules", predicate: weekScheduleQueryPredicate)?.first as? NSManagedObject
        {
            logger.println(" FWSCH: Received weekScheduleRecord")
            viewController.printCurrentStatus(message: "Loading...\nReceived weekScheduleRecord")
            
            if let schedules = appDelegate.decodeArrayFromJSON(object: weekScheduleRecord, field: "schedules") as? Array<String>
            {
                self.nextWeekSchedules = schedules
                queryTodaySchedule(weekSchedules: schedules)
                nextWeekOn = 0
                nextDayOn = 0
                queryTomorrowSchedule(weekSchedules: schedules, addDays: 0, loadedNextWeek: false)
            }
        }
        else
        {
            logger.println(" FWSCH: Did not receive weekScheduleRecord")
            viewController.printCurrentStatus(message: "Error on query")
        }
    }
    
    //MARK: Today Schedule
    
    func queryTodaySchedule(weekSchedules: Array<String>)
    {
        let currentDay = Date().getDayOfWeek()-1
        if currentDay < weekSchedules.count && currentDay >= 0
        {
            let todayScheduleCode = weekSchedules[currentDay]
            logger.println(" FTODYS: currentDay == " + String(currentDay) + " and todaySchedule == " + todayScheduleCode)
            
            logger.println(" FTODYS: Fetching todaySchedule")
            
            let todayScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", todayScheduleCode)
            if let todaySchedule = appDelegate.cloudManager!.fetchLocalObjects(type: "Schedule", predicate: todayScheduleQueryPredicate)?.first as? NSManagedObject
            {
                logger.println(" FTODYS: Received todaySchedule")
                viewController.printCurrentStatus(message: "Received todaySchedule")
                
                self.todaySchedule = todaySchedule
                
                let todayCode = todaySchedule.value(forKey: "scheduleCode") as! String
                if todayCode != "H"
                {
                    if let periodTimes = appDelegate.decodeArrayFromJSON(object: todaySchedule, field: "periodTimes") as? Array<String>
                    {
                        findCurrentPeriod(periodTimes: periodTimes)
                    }
                }
                else
                {
                    logger.println(" FTODYS: todayCode == H, No school today")
                    viewController.printCurrentStatus(message: "No school today")
                    viewController.printSchoolStartTimeStatus(status: "No school today")
                }
            }
            else
            {
                logger.println(" FTODYS: Did not receive todaySchedule")
                viewController.printCurrentStatus(message: "Error on query")
            }
        }
        else
        {
            logger.println(" FTODYS: currentDay out of schedule range")
            viewController.printCurrentStatus(message: "No school today")
            
            viewController.printSchoolStartTimeStatus(status: "No school today")
        }
    }
    
    //MARK: Tomorrow Schedule
    
    func queryTomorrowSchedule(weekSchedules: Array<String>, addDays: Int, loadedNextWeek: Bool)
    {
        var tomorrowSchedule = ""
        var currentlyLoadingNextWeek = false
        var tomorrowDate = addDays
        
        if !loadedNextWeek
        {
            tomorrowDate = Date().getDayOfWeek()+addDays
        }
        
        if tomorrowDate < weekSchedules.count && tomorrowDate >= 0
        {
            tomorrowSchedule = weekSchedules[tomorrowDate]
            logger.println(" FTOMWS: tomorrowDate == " + String(tomorrowDate) + " and tomorrowSchedule == " + tomorrowSchedule)
        }
        else
        {
            logger.println(" FTOMWS: tomorrowDate out of schedule range, loading next week")
            nextWeekOn! += 1
            nextDayOn = 0
            queryNextWeek()
            currentlyLoadingNextWeek = true
        }
        
        if !currentlyLoadingNextWeek
        {
            logger.println(" FTOMWS: Fetching tomorrowSchedule")
            
            let tomorrowScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", tomorrowSchedule)
            if let tomorrowSchedule = appDelegate.cloudManager!.fetchLocalObjects(type: "Schedule", predicate: tomorrowScheduleQueryPredicate)?.first as? NSManagedObject
            {
                logger.println(" FTOMWS: Received tomorrowSchedule")
                
                let tomorrowScheduleCode = tomorrowSchedule.value(forKey: "scheduleCode") as! String
                if tomorrowScheduleCode != "H"
                {
                    logger.println(" FTOMWS: Tomorrow schedule found!")
                    viewController.printTomorrowStartTime(tomorrowSchedule: tomorrowSchedule, nextWeekCount: nextWeekOn!, nextDayCount: nextDayOn!)
                }
                else
                {
                    logger.println(" FTOMWS: No school tomorrow, loading next day")
                    nextDayOn!+=1
                    
                    queryTomorrowSchedule(weekSchedules: self.nextWeekSchedules!, addDays: nextDayOn!, loadedNextWeek: loadedNextWeek)
                }
            }
            else
            {
                logger.println(" FTOMWS: Did not receive tomorrowSchedule")
            }
        }
    }
    
    //MARK: Next Week Schedule
    
    func queryNextWeek()
    {
        logger.println(" FNXTWK: Fetching nextWeekScheduleRecord")
        
        let startOfNextWeekRaw = Date().getStartOfNextWeek(nextWeek: nextWeekOn!)
        let gregorian = Calendar(identifier: .gregorian)
        var startOfNextWeekComponents = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfNextWeekRaw)
        startOfNextWeekComponents.hour = 12
        let startOfNextWeekFormatted = gregorian.date(from: startOfNextWeekComponents)!
        
        let nextWeekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfNextWeekFormatted as CVarArg)
        if let nextWeekScheduleRecord = appDelegate.cloudManager!.fetchLocalObjects(type: "WeekSchedules", predicate: nextWeekScheduleQueryPredicate)?.first as? NSManagedObject
        {
            logger.println(" FNXTWK: Received nextWeekScheduleRecord")
            if let schedules = appDelegate.decodeArrayFromJSON(object: nextWeekScheduleRecord, field: "schedules") as? Array<String>
            {
                self.nextWeekSchedules = schedules
                queryTomorrowSchedule(weekSchedules: schedules, addDays: 0, loadedNextWeek: true)
            }
        }
        else
        {
            logger.println(" FNXTWK: Did not receive nextWeekScheduleRecord")
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
        logger.println(" FCURPER: Finding current period")
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
                logger.println(" FCURPER: periodOn == " + String(periodOn) + " : " + String(periodRange.contains(Date())))
                
                if periodRangeContainsDate
                {
                    periodFound = true
                    logger.println(" FCURPER: Found current period!")
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
                        
                        if let periodNumbers = appDelegate.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? Array<Int>
                        {
                            nextPeriodNumber = periodNumbers[periodOn-1]
                        }
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
                logger.println("Skipping due to invalid date range")
            }
            
            lastPeriodEnd = periodEnd
            
            periodOn += 1
        }
        
        if !periodFound
        {
            if passingPeriod
            {
                logger.println(" FCURPER: Currently passing period")
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
                    logger.println(" FCURPER: School has not started")
                    viewController.printCurrentStatus(message: "School has not started")
                }
                else
                {
                    logger.println(" FCURPER: School has ended")
                    viewController.printCurrentStatus(message: "School has ended")
                }
            }
        }
    }
}
