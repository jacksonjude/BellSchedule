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

@objc protocol ScheduleInfoDelegate
{
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject, periodNames: Array<String>?)
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>)
    
    func printCurrentMessage(message: String)
    
    func printInternalError(message: String, labelNumber: Int)
    
    func printSchoolStartEndMessage(message: String)
    
    func printSchoolStartEndTime(periodTimes: Array<String>)
    
    func printTomorrowStartTime(tomorrowSchedule: NSManagedObject, nextWeekCount: Int, nextDayCount: Int)
    
    @objc optional func setTimer(_ time: String)
    
    @objc optional func noSchoolTomorrow(nextDayCount: Int, nextWeekCount: Int)
}

class ScheduleInfoManager: NSObject {
    let kCurrentPeriodLabel = 0
    let kSchoolStartTime = 1
    let kTomorrowStartTimeLabel = 2
    
    var infoDelegate: ScheduleInfoDelegate
    
    var nextWeekSchedules: Array<String>?
    
    var periodNames: Array<String>?
    var periodPrinted = false
    var periodNamePrinted = false
    var periodNumber: Int?
    
    var todaySchedule: NSManagedObject?
    
    var tomorrowDay: Date?
    var nextWeekOn: Int?
    var nextDayOn: Int?
    
    var onlyFindOneDay: Bool
    var downloadData: Bool
    
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
    
    init(delegate: ScheduleInfoDelegate, downloadData: Bool, onlyFindOneDay: Bool) {
        self.infoDelegate = delegate
        self.onlyFindOneDay = onlyFindOneDay
        self.downloadData = downloadData
        
        super.init()
    }
    
    func startInfoManager()
    {
        if downloadData
        {
            NotificationCenter.default.addObserver(self, selector: #selector(finishedFetchingData), name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)
            
            downloadCloudData()
        }
        else
        {
            queryWeekSchedule()
        }
    }
    
    func downloadCloudData()
    {
        self.loadedData = 0
        
        UserDefaults.standard.set(Date(), forKey: "fetchingCloudData")
        
        CloudManager.fetchAllDataQueue.append("WeekSchedules")
        CloudManager.fetchAllDataQueue.append("Schedule")
        
        CloudManager.initFetchAllDataQueue()
    }
    
    @objc func finishedFetchingData()
    {
        loadedData += 1
        if loadedAllData
        {
            UserDefaults.standard.set(UserDefaults.standard.object(forKey: "fetchingCloudData"), forKey: "lastUpdatedData")
            Logger.println("↓ - Finished fetching changes from cloud")
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
        Logger.println(" USRID: Fetching userID")
        if let userID = UserDefaults.standard.object(forKey: "userID") as? String
        {
            Logger.println(" USRID: userID: " + userID)
            queryUserSchedule(userID: userID)
        }
        else
        {
            Logger.println(" USRID: No userID")
        }
    }
    
    func queryUserSchedule(userID: String)
    {
        let queryUserScheduleID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUserSchedule(notification:)), name: Notification.Name("fetchedPublicDatabaseObject:" + queryUserScheduleID), object: nil)
        
        Logger.println(" USRSCH: Fetching periodNamesRecord")
        let userScheduleQueryPredicate = NSPredicate(format: "userID == %@", userID)
        
        CloudManager.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: queryUserScheduleID)
    }
    
    @objc func receiveUserSchedule(notification: NSNotification)
    {
        if let periodNamesRecord = notification.object as? CKRecord
        {
            Logger.println(" USRSCH: Received periodNamesRecord")
            periodNames = periodNamesRecord.object(forKey: "periodNames") as? [String]
            
            if periodPrinted && !periodNamePrinted
            {
                if (periodNames?.count ?? 0) > periodNumber!-1
                {
                    infoDelegate.printPeriodName(todaySchedule: self.todaySchedule!, periodNames: periodNames!)
                    periodNamePrinted = true
                }
            }
        }
        else
        {
            Logger.println(" USRSCH: Did not receive periodNamesRecord")
        }
    }
    
    //MARK: Week Schedule
    
    func queryWeekSchedule()
    {
        Logger.println(" FWSCH: Fetching weekScheduleRecord")
        
        let startOfWeekRaw = Date().startOfWeek ?? Date()
        let gregorian = Calendar(identifier: .gregorian)
        var startOfWeekComponents = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfWeekRaw)
        startOfWeekComponents.hour = 12
        
        var timeZoneToSet = "PST"
        if TimeZone.current.isDaylightSavingTime(for: gregorian.date(from: startOfWeekComponents)!)
        {
            timeZoneToSet = "PDT"
        }
        startOfWeekComponents.timeZone = TimeZone(abbreviation: timeZoneToSet)
        
        let startOfWeekFormatted = gregorian.date(from: startOfWeekComponents)!
        
        let weekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfWeekFormatted as CVarArg)
        if let weekScheduleRecord = CloudManager.fetchLocalObjects(type: "WeekSchedules", predicate: weekScheduleQueryPredicate)?.first as? NSManagedObject
        {
            Logger.println(" FWSCH: Received weekScheduleRecord")
            infoDelegate.printCurrentMessage(message: "Loading...\nReceived weekScheduleRecord")
            
            if let schedules = self.decodeArrayFromJSON(object: weekScheduleRecord, field: "schedules") as? Array<String>
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
            Logger.println(" FWSCH: Did not receive weekScheduleRecord")
            
            infoDelegate.printInternalError(message: "Week schedule codes not found", labelNumber: kCurrentPeriodLabel)
        }
    }
    
    //MARK: Today Schedule
    
    func queryTodaySchedule(weekSchedules: Array<String>)
    {
        let currentDay = Date().getDayOfWeek()-1
        if currentDay < weekSchedules.count && currentDay >= 0
        {
            let todayScheduleCode = weekSchedules[currentDay]
            Logger.println(" FTODYS: currentDay == " + String(currentDay) + " and todaySchedule == " + todayScheduleCode)
            
            Logger.println(" FTODYS: Fetching todaySchedule")
            
            let todayScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", todayScheduleCode)
            if let todaySchedule = CloudManager.fetchLocalObjects(type: "Schedule", predicate: todayScheduleQueryPredicate)?.first as? NSManagedObject
            {
                Logger.println(" FTODYS: Received todaySchedule")
                infoDelegate.printCurrentMessage(message: "Received todaySchedule")
                
                self.todaySchedule = todaySchedule
                
                let todayCode = todaySchedule.value(forKey: "scheduleCode") as! String
                if todayCode != "H"
                {
                    if let periodTimes = self.decodeArrayFromJSON(object: todaySchedule, field: "periodTimes") as? Array<String>
                    {
                        findCurrentPeriod(periodTimes: periodTimes)
                    }
                }
                else
                {
                    Logger.println(" FTODYS: todayCode == H, No school today")
                    infoDelegate.printCurrentMessage(message: "No school today")
                    infoDelegate.printSchoolStartEndMessage(message: "No school today")
                }
            }
            else
            {
                Logger.println(" FTODYS: Did not receive todaySchedule")
                infoDelegate.printCurrentMessage(message: "Error on query")
            }
        }
        else
        {
            Logger.println(" FTODYS: currentDay out of schedule range")
            infoDelegate.printCurrentMessage(message: "No school today")
            
            infoDelegate.printSchoolStartEndMessage(message: "No school today")
        }
    }
    
    //MARK: Tomorrow Schedule
    
    func queryTomorrowSchedule(weekSchedules: Array<String>, addDays: Int, loadedNextWeek: Bool)
    {
        var tomorrowScheduleCode = ""
        var currentlyLoadingNextWeek = false
        var tomorrowDate = addDays
        
        if !loadedNextWeek
        {
            tomorrowDate = Date().getDayOfWeek()+addDays
        }
        
        if tomorrowDate < weekSchedules.count && tomorrowDate >= 0
        {
            tomorrowScheduleCode = weekSchedules[tomorrowDate]
            Logger.println(" FTOMWS: tomorrowDate == " + String(tomorrowDate) + " and tomorrowSchedule == " + tomorrowScheduleCode)
        }
        else
        {
            Logger.println(" FTOMWS: tomorrowDate out of schedule range, loading next week")
            nextWeekOn! += 1
            nextDayOn = 0
            queryNextWeek()
            currentlyLoadingNextWeek = true
        }
        
        if !currentlyLoadingNextWeek
        {
            Logger.println(" FTOMWS: Fetching tomorrowSchedule")
            
            let tomorrowScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", tomorrowScheduleCode)
            if let tomorrowSchedule = CloudManager.fetchLocalObjects(type: "Schedule", predicate: tomorrowScheduleQueryPredicate)?.first as? NSManagedObject
            {
                Logger.println(" FTOMWS: Received tomorrowSchedule")
                
                let tomorrowScheduleCode = tomorrowSchedule.value(forKey: "scheduleCode") as! String
                if tomorrowScheduleCode != "H"
                {
                    Logger.println(" FTOMWS: Tomorrow schedule found!")
                    infoDelegate.printTomorrowStartTime(tomorrowSchedule: tomorrowSchedule, nextWeekCount: nextWeekOn!, nextDayCount: nextDayOn!)
                }
                else
                {
                    if onlyFindOneDay
                    {
                        infoDelegate.noSchoolTomorrow?(nextDayCount: nextDayOn!, nextWeekCount: nextWeekOn ?? 0)
                    }
                    else
                    {
                        Logger.println(" FTOMWS: No school tomorrow, loading next day")
                        nextDayOn!+=1
                        
                        queryTomorrowSchedule(weekSchedules: self.nextWeekSchedules!, addDays: nextDayOn!, loadedNextWeek: loadedNextWeek)
                    }
                }
            }
            else
            {
                Logger.println(" FTOMWS: Did not receive tomorrowSchedule")
                
                infoDelegate.printInternalError(message: "Tomorrow schedule code not found", labelNumber: kTomorrowStartTimeLabel)
            }
        }
    }
    
    //MARK: Next Week Schedule
    
    func queryNextWeek()
    {
        Logger.println(" FNXTWK: Fetching nextWeekScheduleRecord")
        
        let startOfNextWeekRaw = Date().getStartOfNextWeek(nextWeek: nextWeekOn!)
        let gregorian = Calendar(identifier: .gregorian)
        var startOfNextWeekComponents = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfNextWeekRaw)
        startOfNextWeekComponents.hour = 12
        
        var timeZoneToSet = "PST"
        if TimeZone.current.isDaylightSavingTime(for: gregorian.date(from: startOfNextWeekComponents)!)
        {
            timeZoneToSet = "PDT"
        }
        startOfNextWeekComponents.timeZone = TimeZone(abbreviation: timeZoneToSet)
        
        let startOfNextWeekFormatted = gregorian.date(from: startOfNextWeekComponents)!
        
        let nextWeekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfNextWeekFormatted as CVarArg)
        if let nextWeekScheduleRecord = CloudManager.fetchLocalObjects(type: "WeekSchedules", predicate: nextWeekScheduleQueryPredicate)?.first as? NSManagedObject
        {
            Logger.println(" FNXTWK: Received nextWeekScheduleRecord")
            if let schedules = self.decodeArrayFromJSON(object: nextWeekScheduleRecord, field: "schedules") as? Array<String>
            {
                self.nextWeekSchedules = schedules
                queryTomorrowSchedule(weekSchedules: schedules, addDays: 0, loadedNextWeek: true)
            }
        }
        else
        {
            Logger.println(" FNXTWK: Did not receive nextWeekScheduleRecord")
            
            infoDelegate.printInternalError(message: "Next week schedule codes not found", labelNumber: kTomorrowStartTimeLabel)
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
        Logger.println(" FCURPER: Finding current period")
        let currentDate = Date()
        var periodOn = 1
        var periodFound = false
        var lastPeriodEnd: Date?
        var passingPeriod = false
        var nextPeriodStart: Substring?
        var nextPeriodNumber: Int?
        var schoolHasNotStarted = false
        infoDelegate.printSchoolStartEndTime(periodTimes: periodTimes)
        
        for periodRangeString in periodTimes
        {
            infoDelegate.printCurrentMessage(message: "Loading...\nperiodOn == " + String(periodOn))
            
            let periodRangeArray = periodRangeString.split(separator: "-")
            
            let periodStart = getDate(hourMinute: periodRangeArray[0], day: currentDate)
            let periodEnd = getDate(hourMinute: periodRangeArray[1], day: currentDate)
            
            if periodStart < periodEnd
            {
                let periodRange = periodStart ... periodEnd
                
                let periodRangeContainsDate = periodRange.contains(Date())
                Logger.println(" FCURPER: periodOn == " + String(periodOn) + " : " + String(periodRange.contains(Date())))
                
                if periodRangeContainsDate
                {
                    periodFound = true
                    self.periodNumber = periodOn
                    periodPrinted = true
                    Logger.println(" FCURPER: Found current period!")
                    infoDelegate.printCurrentPeriod(periodRangeString: periodRangeString, periodNumber: periodOn, todaySchedule: self.todaySchedule!, periodNames: self.periodNames)
                    
                    
                    infoDelegate.setTimer?(String(periodRangeString.split(separator: "-")[1]))
                    
                    break
                }
                else if lastPeriodEnd != nil
                {
                    let passingPeriodRange = lastPeriodEnd!...periodStart
                    if passingPeriodRange.contains(currentDate)
                    {
                        passingPeriod = true
                        nextPeriodStart = periodRangeArray[0]
                        
                        if let periodNumbers = self.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? Array<Int>
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
                Logger.println("Skipping due to invalid date range")
            }
            
            lastPeriodEnd = periodEnd
            
            periodOn += 1
        }
        
        if !periodFound
        {
            if passingPeriod
            {
                Logger.println(" FCURPER: Currently passing period")
                let passingPeriodMessage1 = "Passing Period\nPeriod " + String(describing: nextPeriodNumber!) + " starts at "
                var passingPeriodMessage2 = Date().convertToStandardTime(date: String(nextPeriodStart!)) + "\n"
                
                if periodNames != nil
                {
                    passingPeriodMessage2 = passingPeriodMessage2 + periodNames![nextPeriodNumber!-1]
                }
                
                infoDelegate.printCurrentMessage(message: passingPeriodMessage1 + passingPeriodMessage2)
                
                infoDelegate.setTimer?(String(nextPeriodStart!))
            }
            else
            {
                if schoolHasNotStarted
                {
                    Logger.println(" FCURPER: School has not started")
                    infoDelegate.printCurrentMessage(message: "School has not started")
                }
                else
                {
                    Logger.println(" FCURPER: School has ended")
                    infoDelegate.printCurrentMessage(message: "School has ended")
                }
            }
        }
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
