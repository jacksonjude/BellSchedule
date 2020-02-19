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
        let hourMin = date.split(separator: ":")
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
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject)
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>)
    
    func printCurrentMessage(message: String)
    
    func printInternalError(message: String, labelNumber: Int)
    
    func printSchoolStartEndMessage(message: String)
    
    func printSchoolStartEndTime(schoolStartTime: String, schoolEndTime: String)
    
    func printTomorrowStartTime(tomorrowSchoolStartTime: String, tomorrowSchedule: Schedule, nextWeekCount: Int, nextDayCount: Int)
    
    @objc optional func setTimer(_ time: String)
    
    @objc optional func resetTimer()
    
    @objc optional func noSchoolTomorrow(nextDayCount: Int, nextWeekCount: Int)
    
    @objc optional func printFreeModStatus(statusType: Int, timesArray: Array<String>)
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
    var periodIndex: Int?
    var freeMods: Array<Int>?
    var offBlocks: Array<Int> = [0,0,0,0,0,0,0,0]
    
    var todaySchedule: NSManagedObject?
    
    var tomorrowDay: Date?
    var nextWeekOn: Int?
    var nextDayOn: Int?
    
    var onlyFindOneDay: Bool
    var downloadData: Bool
    
    var currentlyDownloadingCloudData = false
    var userScheduleQueryReturnID: String?
    
    var loadedData = 0
    {
        didSet
        {
            if loadedData == 3
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
        var shouldDownloadData = downloadData
        #if os(iOS)
        shouldDownloadData = shouldDownloadData && Reachability.isConnectedToNetwork()
        #endif
        if shouldDownloadData
        {
            downloadCloudData()
        }
        else
        {
            refreshScheduleInfo()
        }
    }
    
    func downloadCloudData()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(finishedFetchingData), name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)
        
        if !currentlyDownloadingCloudData
        {
            currentlyDownloadingCloudData = true
        }
        else
        {
            if let wsIndex = CloudManager.fetchAllDataQueue.firstIndex(of: "WeekSchedules") {CloudManager.fetchAllDataQueue.remove(at: wsIndex)}
            if let sIndex = CloudManager.fetchAllDataQueue.firstIndex(of: "Schedule") {CloudManager.fetchAllDataQueue.remove(at: sIndex)}
            if let aIndex = CloudManager.fetchAllDataQueue.firstIndex(of: "Announcement") {CloudManager.fetchAllDataQueue.remove(at: aIndex)}
            
            if let currentFetchAllDataQueryOperation = CloudManager.currentCloudOperations["fetchAllData"]
            {
                currentFetchAllDataQueryOperation.cancel()
                
                let fetchIndex = CloudManager.currentCloudOperations.index(forKey: "fetchAllData")!
                CloudManager.currentCloudOperations.remove(at: fetchIndex)
            }
            
            if let currentFetchUserScheduleQueryOperation = CloudManager.currentCloudOperations["userScheduleQueryReturnID"]
            {
                currentFetchUserScheduleQueryOperation.cancel()
                
                let fetchIndex = CloudManager.currentCloudOperations.index(forKey: "fetchAllCloudData")!
                CloudManager.currentCloudOperations.remove(at: fetchIndex)
            }
            
            CloudManager.loopFetchAllData()
        }
        
        self.loadedData = 0
        
        UserDefaults.standard.set(Date(), forKey: "fetchingCloudData")
        
        CloudManager.fetchAllDataQueue.append("WeekSchedules")
        CloudManager.fetchAllDataQueue.append("Schedule")
        CloudManager.fetchAllDataQueue.append("Announcement")
        
        CloudManager.initFetchAllDataQueue()
    }
    
    @objc func finishedFetchingData()
    {
        loadedData += 1
        if loadedAllData
        {
            NotificationCenter.default.removeObserver(self, name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)

            currentlyDownloadingCloudData = false
            
            UserDefaults.standard.set(UserDefaults.standard.object(forKey: "fetchingCloudData"), forKey: "lastUpdatedData")
            Logger.println("↓ - Finished fetching changes from cloud")
            refreshScheduleInfo()
        }
    }
    
    func refreshScheduleInfo()
    {
        periodPrinted = false
        periodNamePrinted = false
        periodNames = nil
        freeMods = nil
        //offBlocks = nil
        
        if let weekSchedule = queryWeekSchedule()
        {
            if let todaySchedule = queryTodaySchedule(weekSchedules: weekSchedule), let periodTimes = CoreDataStack.decodeArrayFromJSON(object: todaySchedule, field: "periodTimes") as? Array<String>
            {
                findCurrentPeriod(periodTimes: periodTimes)
            }
            
            refreshTomorrowScheduleInfo(weekSchedule: weekSchedule)
        }
        
        if let userID = ScheduleInfoManager.getUserID()
        {
            queryUserSchedule(userID: userID)
        }
    }
    
    func refreshTomorrowScheduleInfo(weekSchedule: Array<String>)
    {
        nextWeekOn = 0
        nextDayOn = 0
        if let tomorrowScheduleData = queryTomorrowSchedule(weekSchedules: weekSchedule, addDays: 0, loadedNextWeek: false), let tomorrowSchedule = tomorrowScheduleData.schedule, let nextDayOn = tomorrowScheduleData.nextDayOn, let nextWeekOn = tomorrowScheduleData.nextWeekOn, let periodTimes = CoreDataStack.decodeArrayFromJSON(object: tomorrowSchedule, field: "periodTimes") as? Array<String>, let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: tomorrowSchedule, field: "periodNumbers") as? Array<Int>
        {
            infoDelegate.printTomorrowStartTime(tomorrowSchoolStartTime: String(periodTimes[findNextClassBlock(currentPeriodIndex: 0, periodNumbers: periodNumbers) ?? 0].split(separator: "-")[0]), tomorrowSchedule: tomorrowSchedule, nextWeekCount: nextWeekOn, nextDayCount: nextDayOn)
        }
    }
    
    //MARK: UserSchedule
    
    static func getUserID() -> String?
    {
        Logger.println(" USRID: Fetching userID")
        let appGroupUserDefaults = UserDefaults(suiteName: "group.com.jacksonjude.BellSchedule")
        if let userID = appGroupUserDefaults?.object(forKey: "userID") as? String
        {
            Logger.println(" USRID: userID: " + userID)
            return userID
        }
        Logger.println(" USRID: No userID")
        return nil
    }
    
    func queryUserSchedule(userID: String)
    {
        let queryUserScheduleID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUserSchedule(notification:)), name: Notification.Name("fetchedPublicDatabaseObject:" + queryUserScheduleID), object: nil)
        
        Logger.println(" USRSCH: Fetching periodNamesRecord")
        let userScheduleQueryPredicate = NSPredicate(format: "userID == %@", userID)
        
        self.userScheduleQueryReturnID = queryUserScheduleID
        
        CloudManager.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: queryUserScheduleID)
    }
    
    @objc func receiveUserSchedule(notification: NSNotification)
    {
        self.userScheduleQueryReturnID = nil
        
        if let periodNamesRecord = notification.userInfo?["object"] as? CKRecord
        {
            Logger.println(" USRSCH: Received periodNamesRecord")
            periodNames = periodNamesRecord.object(forKey: "periodNames") as? [String]
            freeMods = periodNamesRecord.object(forKey: "freeMods") as? [Int]
            offBlocks = periodNamesRecord.object(forKey: "offBlocks") as? [Int] ?? [0,0,0,0,0,0,0,0]
            
            getPeriodName()

            recalculateForOffBlocks()
        }
        else
        {
            Logger.println(" USRSCH: Did not receive periodNamesRecord")
        }
        
        if let returnID = notification.userInfo?["returnID"] as? String
        {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("fetchedPublicDatabaseObject:" + returnID), object: nil)
        }
    }
    
    func recalculateForOffBlocks()
    {
        if todaySchedule != nil, let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? [Int], let periodTimes = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodTimes") as? [String]
        {
            //let currentPeriodNumber = periodNumbers[periodIndex!-1]-1
            let nextClassPeriodIndex = findNextClassBlock(currentPeriodIndex: ((periodIndex ?? 1)-1), periodNumbers: periodNumbers)
            
            if periodIndex != nil && nextClassPeriodIndex != nil && periodIndex!-1 != nextClassPeriodIndex!, let periodTimes = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodTimes") as? Array<String>
            {
                let nextClassPeriodNumber = periodNumbers[nextClassPeriodIndex!]
                
                let messagePart1BecauseTheCompilerSucks = "Off Block\nBlock " + String(nextClassPeriodNumber) + " starts at " + String(periodTimes[nextClassPeriodIndex!].split(separator: "-")[0])
                let messagePart2BecauseTheCompilerSucks = "\n" + ((periodNames?.count ?? 0 > nextClassPeriodIndex!) ? periodNames![nextClassPeriodNumber-1] : "")
                infoDelegate.printCurrentMessage(message: messagePart1BecauseTheCompilerSucks + messagePart2BecauseTheCompilerSucks)
                //infoDelegate.printCurrentPeriod(periodRangeString: periodTimes[nextClassPeriodIndex!], periodNumber: nextClassPeriodIndex!, todaySchedule: todaySchedule!)
                //getPeriodName()
            }
            else if periodIndex == nil && nextClassPeriodIndex != nil
            {
                if getDate(hourMinute: String(periodTimes[nextClassPeriodIndex!].split(separator: "-")[0]), day: Date()) > Date()
                {
                    infoDelegate.printCurrentMessage(message: "School has not started")
                }
                else
                {
                    infoDelegate.printCurrentMessage(message: "School has ended")
                }
            }
            else if periodIndex != nil && nextClassPeriodIndex == nil
            {
                infoDelegate.printCurrentMessage(message: "School has ended")
            }
            
            infoDelegate.printSchoolStartEndTime(schoolStartTime: String(periodTimes[findNextClassBlock(currentPeriodIndex: 0, periodNumbers: periodNumbers) ?? 0].split(separator: "-")[0]), schoolEndTime: String(periodTimes[findLastClassBlock(periodNumbers: periodNumbers)].split(separator: "-")[1]))
        }
        
        if let weekSchedule = queryWeekSchedule()
        {
            refreshTomorrowScheduleInfo(weekSchedule: weekSchedule)
        }
    }
    
    func getPeriodName()
    {
        if periodPrinted && !periodNamePrinted && todaySchedule != nil && periodIndex != nil
        {
            if (periodNames?.count ?? 0) > periodIndex!-1
            {
                Logger.println(" GPN: Printing period name")
                infoDelegate.printPeriodName(todaySchedule: self.todaySchedule!, periodNames: periodNames!)
                return
            }
            
            //if let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? [Int]
            //{
                //let freeModsAreLoaded = (freeMods?.count ?? 0) >= periodNumbers[periodIndex!-1]
                //Logger.println(" GPN: Free mods are loaded: " + String(freeModsAreLoaded))
                /*if freeModsAreLoaded
                {
                    Logger.println(" GPN: Is a free mod: " + String(freeMods?[periodNumbers[periodIndex!-1]-1] == 1))
                    Logger.println(" GPN: Today is a B or C code: " + String(((todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "B" || (todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "C")))
                    
                    if freeMods?[periodNumbers[periodIndex!-1]-1] == 1 && ((todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "B" || (todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "C")
                    {
                        if let periodTimes = decodeArrayFromJSON(object: todaySchedule!, field: "periodTimes") as? Array<String>
                        {
                            recalculateCurrentPeriodForMods(periodTimes: periodTimes)
                            return
                        }
                    }
                }*/
            //}
        }
    }
    
    func findNextClassBlock(currentPeriodIndex: Int, periodNumbers: Array<Int>) -> Int?
    {
        for periodNumber in periodNumbers
        {
            let periodNumberIndex = periodNumbers.firstIndex(of: periodNumber)!
            //Hardcode reg#
            if ((offBlocks.count > periodNumber-1 && offBlocks[periodNumber-1] == 0) || periodNumber == 9) && periodNumberIndex >= currentPeriodIndex
            {
                return periodNumberIndex
            }
        }
        
        return nil
    }
    
    func findLastClassBlock(periodNumbers: Array<Int>) -> Int
    {
        var lastPeriodIndex = 0
        for periodNumber in periodNumbers
        {
            if offBlocks.count > periodNumber-1 && offBlocks[periodNumber-1] == 0
            {
                lastPeriodIndex = periodNumbers.firstIndex(of: periodNumber)!
            }
        }
        
        return lastPeriodIndex
    }
    
    //MARK: Week Schedule
    
    func queryWeekSchedule() -> Array<String>?
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
        if let weekScheduleRecord = CoreDataStack.fetchLocalObjects(type: "WeekSchedules", predicate: weekScheduleQueryPredicate)?.first as? NSManagedObject
        {
            Logger.println(" FWSCH: Received weekScheduleRecord")
            //infoDelegate.printCurrentMessage(message: "Loading...\nReceived weekScheduleRecord")
            
            if let schedules = CoreDataStack.decodeArrayFromJSON(object: weekScheduleRecord, field: "schedules") as? Array<String>
            {
                self.nextWeekSchedules = schedules
                
                return schedules
            }
            
            return nil
        }
        else
        {
            Logger.println(" FWSCH: Did not receive weekScheduleRecord")
            
            infoDelegate.printInternalError(message: "Week schedule codes not found", labelNumber: kCurrentPeriodLabel)
            
            return nil
        }
    }
    
    //MARK: Today Schedule
    
    func queryTodaySchedule(weekSchedules: Array<String>) -> Schedule?
    {
        let currentDay = Date().getDayOfWeek()-1
        if currentDay < weekSchedules.count && currentDay >= 0
        {
            let todayScheduleCode = weekSchedules[currentDay]
            Logger.println(" FTODYS: currentDay == " + String(currentDay) + " and todaySchedule == " + todayScheduleCode)
            
            Logger.println(" FTODYS: Fetching todaySchedule")
            
            let todayScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", todayScheduleCode)
            if let todaySchedule = CoreDataStack.fetchLocalObjects(type: "Schedule", predicate: todayScheduleQueryPredicate)?.first as? Schedule
            {
                Logger.println(" FTODYS: Received todaySchedule")
                infoDelegate.printCurrentMessage(message: "Received todaySchedule")
                
                self.todaySchedule = todaySchedule
                
                let todayCode = todaySchedule.value(forKey: "scheduleCode") as! String
                if todayCode != "H"
                {
                    if let periodTimes = CoreDataStack.decodeArrayFromJSON(object: todaySchedule, field: "periodTimes") as? Array<String>
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
                
                return todaySchedule
            }
            else
            {
                Logger.println(" FTODYS: Did not receive todaySchedule")
                infoDelegate.printCurrentMessage(message: "Error on query")
                
                return nil
            }
        }
        else
        {
            Logger.println(" FTODYS: currentDay out of schedule range")
            infoDelegate.printCurrentMessage(message: "No school today")
            
            infoDelegate.printSchoolStartEndMessage(message: "No school today")
            
            return nil
        }
    }
    
    //MARK: Tomorrow Schedule
    
    func queryTomorrowSchedule(weekSchedules: Array<String>, addDays: Int, loadedNextWeek: Bool) -> (schedule: Schedule?, nextDayOn: Int?, nextWeekOn: Int?)?
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
            if let nextWeekSchedules = queryNextWeek()
            {
                return queryTomorrowSchedule(weekSchedules: nextWeekSchedules, addDays: 0, loadedNextWeek: true)
            }
            currentlyLoadingNextWeek = true
        }
        
        if !currentlyLoadingNextWeek
        {
            Logger.println(" FTOMWS: Fetching tomorrowSchedule")
            
            let tomorrowScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", tomorrowScheduleCode)
            if let tomorrowSchedule = CoreDataStack.fetchLocalObjects(type: "Schedule", predicate: tomorrowScheduleQueryPredicate)?.first as? Schedule
            {
                Logger.println(" FTOMWS: Received tomorrowSchedule")
                
                let tomorrowScheduleCode = tomorrowSchedule.value(forKey: "scheduleCode") as! String
                if tomorrowScheduleCode != "H"
                {
                    Logger.println(" FTOMWS: Tomorrow schedule found!")
                    return (schedule: tomorrowSchedule, nextDayOn: nextDayOn, nextWeekOn: nextWeekOn)
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
                        
                        return queryTomorrowSchedule(weekSchedules: self.nextWeekSchedules!, addDays: nextDayOn!, loadedNextWeek: loadedNextWeek)
                    }
                }
            }
            else
            {
                Logger.println(" FTOMWS: Did not receive tomorrowSchedule")
                
                infoDelegate.printInternalError(message: "Tomorrow schedule code not found", labelNumber: kTomorrowStartTimeLabel)
            }
        }
        
        return nil
    }
    
    //MARK: Next Week Schedule
    
    func queryNextWeek() -> Array<String>?
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
        if let nextWeekScheduleRecord = CoreDataStack.fetchLocalObjects(type: "WeekSchedules", predicate: nextWeekScheduleQueryPredicate)?.first as? NSManagedObject
        {
            Logger.println(" FNXTWK: Received nextWeekScheduleRecord")
            if let schedules = CoreDataStack.decodeArrayFromJSON(object: nextWeekScheduleRecord, field: "schedules") as? Array<String>
            {
                self.nextWeekSchedules = schedules
                
                return schedules
            }
        }
        else
        {
            Logger.println(" FNXTWK: Did not receive nextWeekScheduleRecord")
            
            infoDelegate.printInternalError(message: "Next week schedule codes not found", labelNumber: kTomorrowStartTimeLabel)
            
            return nil
        }
        
        return nil
    }
    
    //MARK: Find Current Period
    
    func getDate(hourMinute: String, day: Date) -> Date
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
        infoDelegate.printSchoolStartEndTime(schoolStartTime: String(periodTimes[0].split(separator: "-")[0]), schoolEndTime: String(periodTimes[periodTimes.count-1].split(separator: "-")[1]))
        
        for periodRangeString in periodTimes
        {
            infoDelegate.printCurrentMessage(message: "Loading...\nperiodOn == " + String(periodOn))
            
            let periodRangeArray = periodRangeString.split(separator: "-")
            
            let periodStart = getDate(hourMinute: String(periodRangeArray[0]), day: currentDate)
            let periodEnd = getDate(hourMinute: String(periodRangeArray[1]), day: currentDate)
            
            if periodStart < periodEnd
            {
                let periodRange = periodStart ... periodEnd
                
                let periodRangeContainsDate = periodRange.contains(Date())
                Logger.println(" FCURPER: periodOn == " + String(periodOn) + " : " + String(periodRange.contains(Date())))
                
                if periodRangeContainsDate
                {
                    periodFound = true
                    self.periodIndex = periodOn
                    periodPrinted = true
                    Logger.println(" FCURPER: Found current period!")
                    
                    infoDelegate.printCurrentPeriod(periodRangeString: periodRangeString, periodNumber: periodOn, todaySchedule: self.todaySchedule!)                    
                    
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
                        
                        if let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? Array<Int>
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
                var passingPeriodMessage2 = Date().convertToStandardTime(date: String(nextPeriodStart!))!
                
                if periodNames != nil
                {
                    passingPeriodMessage2 = passingPeriodMessage2 + periodNames![nextPeriodNumber!-1]
                }
                
                periodPrinted = true
                
                if let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? [Int]
                {
                    periodIndex = (periodNumbers.firstIndex(of: nextPeriodNumber!) ?? 0)+1
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
    
    func recalculateCurrentPeriodForMods(periodTimes: Array<String>)
    {
        if let periodNumbers = CoreDataStack.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? Array<Int>
        {
            let currentPeriodWithMod = periodNumbers[periodIndex!-1]
        
            let periodStart = periodTimes[periodIndex!-1].split(separator: "-")[0]
            var periodStartHour = Int(periodStart.split(separator: ":")[0]) ?? 0
            var periodStartMinute = Int(periodStart.split(separator: ":")[1]) ?? 0
            
            let periodEnd = periodTimes[periodIndex!-1].split(separator: "-")[1]
            var periodEndHour = Int(periodEnd.split(separator: ":")[0]) ?? 0
            var periodEndMinute = Int(periodEnd.split(separator: ":")[1]) ?? 0
            
            let totalMinutes = (60*(periodEndHour - periodStartHour)) + (periodEndMinute - periodStartMinute)
            
            Logger.println(" RCPM: Calculating period length - " + String(totalMinutes) + " mins")
            
            if totalMinutes == 60
            {
                infoDelegate.resetTimer?()
                
                var modStartHour = 0
                var modStartMinute = 0
                
                var modEndHour = 0
                var modEndMinute = 0
                
                if currentPeriodWithMod % 2 == 0
                {
                    //Even block number -- Mod goes before
                    
                    modStartHour = periodStartHour
                    modStartMinute = periodStartMinute
                    
                    periodStartMinute += 15
                    if periodStartMinute >= 60
                    {
                        if periodStartMinute - 5 >= 60
                        {
                            modEndHour = periodStartHour + 1
                            modEndMinute = periodStartMinute - 5 - 60
                        }
                        else
                        {
                            modEndHour = periodStartHour
                            modEndMinute = periodStartMinute - 5
                        }
                        
                        periodStartMinute -= 60
                        periodStartHour += 1
                    }
                    else
                    {
                        modEndHour = periodStartHour
                        modEndMinute = periodStartMinute - 5
                    }
                    
                }
                else if currentPeriodWithMod % 2 == 1
                {
                    //Odd block number -- Mod goes after
                    
                    modEndHour = periodEndHour
                    modEndMinute = periodEndMinute
                    
                    periodEndMinute -= 15
                    if periodEndMinute < 0
                    {
                        if periodEndMinute + 5 < 0
                        {
                            modStartHour = periodEndHour - 1
                            modStartMinute = periodEndMinute + 5 + 60
                        }
                        else
                        {
                            modStartHour = periodEndHour
                            modStartMinute = periodEndMinute + 5
                        }
                        
                        periodEndMinute += 60
                        periodEndHour -= 1
                    }
                    else
                    {
                        modStartHour = periodEndHour
                        modStartMinute = periodEndMinute + 5
                    }
                }
                
                let periodStartFormattedString = String(convertTo12Hour(periodStartHour)) + ":" + zeroPadding(periodStartMinute)
                let periodEndFormattedString = String(convertTo12Hour(periodEndHour)) + ":" + zeroPadding(periodEndMinute)
                
                let periodStartFormattedString24 = String(periodStartHour) + ":" + zeroPadding(periodStartMinute)
                let periodEndFormattedString24 = String(periodEndHour) + ":" + zeroPadding(periodEndMinute)
                
                let periodStartDate = getDate(hourMinute: zeroPadding(periodStartHour) + ":" + zeroPadding(periodStartMinute), day: Date())
                let periodEndDate = getDate(hourMinute: zeroPadding(periodEndHour) + ":" + zeroPadding(periodEndMinute), day: Date())
                
                let modStartFormattedString = String(convertTo12Hour(modStartHour)) + ":" + zeroPadding(modStartMinute)
                let modEndFormattedString = String(convertTo12Hour(modEndHour)) + ":" + zeroPadding(modEndMinute)
                
                let modStartFormattedString24 = String(modStartHour) + ":" + zeroPadding(modStartMinute)
                let modEndFormattedString24 = String(modEndHour) + ":" + zeroPadding(modEndMinute)
                
                let modStartDate = getDate(hourMinute: zeroPadding(modStartHour) + ":" + zeroPadding(modStartMinute), day: Date())
                let modEndDate = getDate(hourMinute: zeroPadding(modEndHour) + ":" + zeroPadding(modEndMinute), day: Date())
                
                let currentDate = Date()
                let periodDateRange = periodStartDate ... periodEndDate
                let modDateRange = modStartDate ... modEndDate
                
                let kDuringPeriod = 0
                let kDuringMod = 1
                let kPassingModPeriod = 2
                let kPassingPeriodMod = 3
                let kPassingBeforeMod = 4
                let kPassingAfterMod = 5
                
                if periodDateRange.contains(currentDate)
                {
                    Logger.println(" RCPM: Period is not in mod -- Printing period name -- " + periodStartFormattedString + " - " + periodEndFormattedString)
                    
                    infoDelegate.setTimer?(periodEndFormattedString24)
                    
                    infoDelegate.printFreeModStatus?(statusType: kDuringPeriod, timesArray: [String(currentPeriodWithMod), periodStartFormattedString, periodEndFormattedString, periodNames![currentPeriodWithMod-1]])
                }
                else if modDateRange.contains(currentDate)
                {
                    Logger.println(" RCPM: Period is in mod -- Printing mod -- " + modStartFormattedString + " - " + modEndFormattedString)
                    //Print mod start end times
                    
                    infoDelegate.setTimer?(modEndFormattedString24)
                    
                    infoDelegate.printFreeModStatus?(statusType: kDuringMod, timesArray: [modStartFormattedString, modEndFormattedString])
                }
                else if currentPeriodWithMod % 2 == 0 && (modEndDate ... periodStartDate).contains(currentDate)
                {
                    Logger.println(" RCPM: Period is passing between mod and period -- " + modEndFormattedString + " - " + periodStartFormattedString)
                    //Passing period between mod and period
                    
                    infoDelegate.setTimer?(periodStartFormattedString24)
                    
                    infoDelegate.printFreeModStatus?(statusType: kPassingModPeriod, timesArray: [String(currentPeriodWithMod), periodStartFormattedString, periodNames![currentPeriodWithMod-1]])
                }
                else if currentPeriodWithMod % 2 == 1 && (periodEndDate ... modStartDate).contains(currentDate)
                {
                    Logger.println(" RCPM: Period is passing between period and mod -- " + periodEndFormattedString + " - " + modStartFormattedString)
                    //Passing period between period and mod
                    
                    infoDelegate.setTimer?(modStartFormattedString24)
                    
                    infoDelegate.printFreeModStatus?(statusType: kPassingPeriodMod, timesArray: [modStartFormattedString, modEndFormattedString])
                }
                else if currentPeriodWithMod % 2 == 0 && modStartDate > currentDate
                {
                    Logger.println(" RCPM: Passing period before mod -- " + modStartFormattedString)
                    //Passing period before mod
                    
                    infoDelegate.setTimer?(modStartFormattedString24)
                    
                    infoDelegate.printFreeModStatus?(statusType: kPassingBeforeMod, timesArray: [modStartFormattedString, modEndFormattedString])
                }
                else if currentPeriodWithMod % 2 == 1 && modEndDate < currentDate
                {
                    Logger.println(" RCPM: Passing period after mod -- " + modEndFormattedString)
                    //Passing period after mod
                    //Should never call...
                    
                    infoDelegate.printFreeModStatus?(statusType: kPassingAfterMod, timesArray: [modEndFormattedString])
                }
            }
            else
            {
                infoDelegate.printPeriodName(todaySchedule: self.todaySchedule!, periodNames: periodNames!)
            }
        }
    }
    
    func calculateStartTime(periodTimes: Array<String>, periodNumbers: Array<String>)
    {
        
    }
    
    func zeroPadding(_ int: Int) -> String
    {
        if int > 9
        {
            return String(int)
        }
        else
        {
            return "0" + String(int)
        }
    }
    
    func convertTo12Hour(_ int: Int) -> Int
    {
        if int > 12
        {
            return int-12
        }
        else
        {
            return int
        }
    }
}
