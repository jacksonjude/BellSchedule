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
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject)
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>)
    
    func printCurrentMessage(message: String)
    
    func printInternalError(message: String, labelNumber: Int)
    
    func printSchoolStartEndMessage(message: String)
    
    func printSchoolStartEndTime(periodTimes: Array<String>)
    
    func printTomorrowStartTime(tomorrowSchedule: NSManagedObject, nextWeekCount: Int, nextDayCount: Int)
    
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
    var periodNumber: Int?
    var freeMods: Array<Int>?
    
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
        if !currentlyDownloadingCloudData
        {
            currentlyDownloadingCloudData = true
        }
        else
        {
            if let wsIndex = CloudManager.fetchAllDataQueue.index(of: "WeekSchedules") {CloudManager.fetchAllDataQueue.remove(at: wsIndex)}
            if let sIndex = CloudManager.fetchAllDataQueue.index(of: "Schedule") {CloudManager.fetchAllDataQueue.remove(at: sIndex)}
            if let aIndex = CloudManager.fetchAllDataQueue.index(of: "Announcement") {CloudManager.fetchAllDataQueue.remove(at: aIndex)}
            
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
        
        self.userScheduleQueryReturnID = queryUserScheduleID
        
        CloudManager.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: queryUserScheduleID)
    }
    
    @objc func receiveUserSchedule(notification: NSNotification)
    {
        self.userScheduleQueryReturnID = nil
        
        if let periodNamesRecord = notification.object as? CKRecord
        {
            Logger.println(" USRSCH: Received periodNamesRecord")
            periodNames = periodNamesRecord.object(forKey: "periodNames") as? [String]
            freeMods = periodNamesRecord.object(forKey: "freeMods") as? [Int]
            
            getPeriodName()
        }
        else
        {
            Logger.println(" USRSCH: Did not receive periodNamesRecord")
        }
    }
    
    func getPeriodName()
    {
        if periodPrinted && !periodNamePrinted && todaySchedule != nil && periodNumber != nil
        {
            if let periodNumbers = decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? [Int]
            {
                Logger.println(" GPN: Free mods are loaded: " + String((freeMods?.count ?? 0) > periodNumbers[periodNumber!-1]-1))
                Logger.println(" GPN: Is a free mod: " + String(freeMods?[periodNumbers[periodNumber!-1]-1] == 1))
                Logger.println(" GPN: Today is a B or C code: " + String(((todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "B" || (todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "C")))
                
                if (freeMods?.count ?? 0) > periodNumbers[periodNumber!-1]-1 && freeMods?[periodNumbers[periodNumber!-1]-1] == 1 && ((todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "B" || (todaySchedule!.value(forKey: "scheduleCode") as? String ?? "") == "C")
                {
                    if let periodTimes = decodeArrayFromJSON(object: todaySchedule!, field: "periodTimes") as? Array<String>
                    {
                        recalculateCurrentPeriodForMods(periodTimes: periodTimes)
                    }
                }
                else if (periodNames?.count ?? 0) > periodNumber!-1
                {
                    infoDelegate.printPeriodName(todaySchedule: self.todaySchedule!, periodNames: periodNames!)
                }
            }
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
        infoDelegate.printSchoolStartEndTime(periodTimes: periodTimes)
        
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
                    self.periodNumber = periodOn
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
                var passingPeriodMessage2 = Date().convertToStandardTime(date: String(nextPeriodStart!))!
                
                if periodNames != nil
                {
                    passingPeriodMessage2 = passingPeriodMessage2 + periodNames![nextPeriodNumber!-1]
                }
                
                periodPrinted = true
                periodNumber = nextPeriodNumber!+1
                
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
        if let periodNumbers = self.decodeArrayFromJSON(object: todaySchedule!, field: "periodNumbers") as? Array<Int>
        {
            let currentPeriodWithMod = periodNumbers[periodNumber!-1]
        
            let periodStart = periodTimes[periodNumber!-1].split(separator: "-")[0]
            var periodStartHour = Int(periodStart.split(separator: ":")[0]) ?? 0
            var periodStartMinute = Int(periodStart.split(separator: ":")[1]) ?? 0
            
            let periodEnd = periodTimes[periodNumber!-1].split(separator: "-")[1]
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
    
    func decodeArrayFromJSON(object: NSManagedObject, field: String) -> Array<Any>?
    {
        let JSONdata = object.value(forKey: field) as! Data
        do
        {
            let array = try JSONSerialization.jsonObject(with: JSONdata, options: .allowFragments) as? Array<Any>
            return array
        }
        catch
        {
            Logger.println(error)
            return nil
        }
    }
}
