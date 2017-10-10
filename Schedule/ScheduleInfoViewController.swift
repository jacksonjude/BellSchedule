//
//  ViewController.swift
//  Schedule
//
//  Created by jackson on 10/5/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CloudKit

extension Date {
    struct Gregorian {
        static let calendar = Calendar(identifier: .gregorian)
    }
    var startOfWeek: Date? {
        return Gregorian.calendar.date(from: Gregorian.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))
    }
    func getStartOfNextWeek(nextWeek: Int) -> Date {
        var nextWeekComponents = Gregorian.calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
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

class ScheduleInfoViewController: UIViewController {
    let appDelegate = UIApplication.shared.delegate! as! AppDelegate
    @IBOutlet weak var currentPeriodLabel: UILabel!
    @IBOutlet weak var schoolStartEndLabel: UILabel!
    @IBOutlet weak var tomorrowStartTimeLabel: UILabel!
    @IBOutlet weak var editScheduleButton: UIButton!
    @IBOutlet weak var openCalenderButton: UIButton!
    
    var nextWeekSchedules: Array<String>?
    
    var periodNames: Array<String>?
    var periodPrinted = false
    var periodNumber: Int?
    
    var todaySchedule: CKRecord?
    
    var tomorrowDay: Date?
    var nextWeekOn: Int?
    var nextDayOn: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        addCorners(view: currentPeriodLabel)
        addCorners(view: schoolStartEndLabel)
        addCorners(view: tomorrowStartTimeLabel)
        addCorners(view: editScheduleButton)
        addCorners(view: openCalenderButton)
        
        refreshPeriodInfo(self)
    }
    
    func addCorners(view: UIView)
    {
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
    }
    
    //MARK: User ID
    
    @IBAction func setUserID(_ sender: Any) {
        let userIDAlert = UIAlertController(title: "UserID", message: "Set your userID to be fetched", preferredStyle: .alert)
        
        userIDAlert.addTextField { (textFeild) in
            textFeild.placeholder = "UserID"
        }
        
        userIDAlert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (alert) in
            
        }))
        
        userIDAlert.addAction(UIAlertAction(title: "Set", style: .default, handler: { (alert) in
            let userID = userIDAlert.textFields![0].text
            if userID != nil || userID != ""
            {
                UserDefaults.standard.set(userID, forKey: "userID")
                print(" USRID: Set userID: " + userID!)
            }
        }))
        
        self.present(userIDAlert, animated: true) {
            
        }
    }
    
    
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
    
    //MARK: UserSchedule
    
    func queryUserSchedule(userID: String)
    {
        print(" USRSCH: Fetching periodNamesRecord")
        let userScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUserSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + userScheduleReturnID), object: nil)
        
        let userScheduleQueryPredicate = NSPredicate(format: "userID == %@", userID)
        appDelegate.cloudManager.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: userScheduleReturnID)
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
                    printPeriodName()
                }
            }
        }
        else
        {
            print(" USRSCH: Did not receive periodNamesRecord")
        }
    }
    
    //MARK: Refresh Info
    
    @IBAction func refreshPeriodInfo(_ sender: Any)
    {
        print("Refreshing:")
        OperationQueue.main.addOperation {
            self.currentPeriodLabel.text = "Loading..."
            self.schoolStartEndLabel.text = "Loading..."
            self.tomorrowStartTimeLabel.text = "Loading..."
        }
        getUserID()
        queryWeekSchedule()
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
        appDelegate.cloudManager.fetchPublicDatabaseObject(type: "WeekSchedules", predicate: weekScheduleQueryPredicate, returnID: weekScheduleReturnID)
    }
    
    @objc func receiveWeekScheduleRecord(notification: NSNotification)
    {
        if let weekScheduleRecord = notification.object as? CKRecord
        {
            print(" FWSCH: Received weekScheduleRecord")
            printCurrentStatus(message: "Loading...\nReceived weekScheduleRecord")
            
            let schedules = weekScheduleRecord.object(forKey: "schedules") as! Array<String>
            
            self.nextWeekSchedules = schedules
            queryTodaySchedule(weekSchedules: schedules)
            nextWeekOn = 0
            nextDayOn = 0
            queryTomorrowSchedule(weekSchedules: schedules, isNextWeek: false, addDays: 0)
        }
        else
        {
            print(" FWSCH: Did not receive weekScheduleRecord")
            printCurrentStatus(message: "Error on query")
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
            appDelegate.cloudManager.fetchPublicDatabaseObject(type: "Schedule", predicate: todayScheduleQueryPredicate, returnID: todayScheduleReturnID)
        }
        else
        {
            print(" FTODYS: currentDay out of schedule range")
            printCurrentStatus(message: "No school today")
            
            OperationQueue.main.addOperation {
                self.schoolStartEndLabel.text = "No school today"
            }
        }
    }
    
    @objc func receiveTodaySchedule(notification: NSNotification)
    {
        if let todaySchedule = notification.object as? CKRecord
        {
            print(" FTODYS: Received todaySchedule")
            printCurrentStatus(message: "Received todaySchedule")
            
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
                printCurrentStatus(message: "No school today")
                OperationQueue.main.addOperation {
                    self.schoolStartEndLabel.text = "No school today"
                }
            }
        }
        else
        {
            print(" FTODYS: Did not receive todaySchedule")
            printCurrentStatus(message: "Error on query")
        }
    }
    
    //MARK: Tomorrow Schedule
    
    func queryTomorrowSchedule(weekSchedules: Array<String>, isNextWeek: Bool, addDays: Int)
    {
        var tomorrowSchedule = ""
        var loadingNextWeek = false
        
        let tomorrowDate = Date().getDayOfWeek()+addDays
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
            queryNextWeek()
            loadingNextWeek = true
        }
        
        if !loadingNextWeek
        {
            print(" FTOMWS: Fetching tomorrowSchedule")
            
            let tomorrowScheduleReturnID = UUID().uuidString
            NotificationCenter.default.addObserver(self, selector: #selector(receiveTomorrowSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + tomorrowScheduleReturnID), object: nil)
            
            let tomorrowScheduleQueryPredicate = NSPredicate(format: "scheduleCode == %@", tomorrowSchedule)
            appDelegate.cloudManager.fetchPublicDatabaseObject(type: "Schedule", predicate: tomorrowScheduleQueryPredicate, returnID: tomorrowScheduleReturnID)
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
                printTomorrowStartTime(tomorrowSchedule: tomorrowSchedule)
            }
            else
            {
                print(" FTOMWS: No school tomorrow, loading next day")
                nextDayOn!+=1
                
                queryTomorrowSchedule(weekSchedules: self.nextWeekSchedules!, isNextWeek: false, addDays: nextDayOn!)
            }
        }
        else
        {
            print(" FTOMWS: Did not receive tomorrowSchedule")
        }
    }
    
    //MARK: Next Week Schedule
    
    func queryNextWeek()
    {
        print(" FNXTWK: Fetching nextWeekScheduleRecord")
        
        let nextWeekScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveNextWeekSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + nextWeekScheduleReturnID), object: nil)
        
        let startOfNextWeekRaw = Date().getStartOfNextWeek(nextWeek: nextWeekOn!)
        let gregorian = Calendar(identifier: .gregorian)
        var components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second], from: startOfNextWeekRaw)
        components.hour = 12
        let startOfNextWeekFormatted = gregorian.date(from: components)!
        
        let nextWeekScheduleQueryPredicate = NSPredicate(format: "weekStartDate == %@", startOfNextWeekFormatted as CVarArg)
        appDelegate.cloudManager.fetchPublicDatabaseObject(type: "WeekSchedules", predicate: nextWeekScheduleQueryPredicate, returnID: nextWeekScheduleReturnID)
    }
    
    @objc func receiveNextWeekSchedule(notification: NSNotification)
    {
        if let nextWeekScheduleRecord = notification.object as? CKRecord
        {
            print(" FNXTWK: Received nextWeekScheduleRecord")
            let schedules = nextWeekScheduleRecord.object(forKey: "schedules") as! Array<String>
            self.nextWeekSchedules = schedules
            queryTomorrowSchedule(weekSchedules: schedules, isNextWeek: true, addDays: 0)
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
        
        setSchoolStartEndLabel(periodTimes: periodTimes)
        
        for periodRangeString in periodTimes
        {
            printCurrentStatus(message: "Loading...\nperiodOn == " + String(periodOn))
            
            let periodRangeArray = periodRangeString.split(separator: "-")
            
            let periodStart = getDate(hourMinute: periodRangeArray[0], day: currentDate)
            let periodEnd = getDate(hourMinute: periodRangeArray[1], day: currentDate)
            
            let periodRange = periodStart ... periodEnd
            
            let periodRangeContainsDate = periodRange.contains(Date())
            print(" FCURPER: periodOn == " + String(periodOn) + " : " + String(periodRange.contains(Date())))
            
            if periodRangeContainsDate
            {
                periodFound = true
                print(" FCURPER: Found current period!")
                printCurrentPeriod(periodRangeString: periodRangeString, periodNumber: periodOn)
                
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
                printCurrentStatus(message: passingPeriodMessage1 + passingPeriodMessage2)
            }
            else
            {
                if schoolHasNotStarted
                {
                    print(" FCURPER: School has not started")
                    printCurrentStatus(message: "School has not started")
                }
                else
                {
                    print(" FCURPER: School has ended")
                    printCurrentStatus(message: "School has ended")
                }
            }
        }
    }
    
    func setSchoolStartEndLabel(periodTimes: Array<String>)
    {
        let currentDate = Date()
        
        let startTimeArray = periodTimes[0].split(separator: "-")
        let startTimeStart = getDate(hourMinute: startTimeArray[0], day: currentDate)
        
        let endTimeArray = periodTimes[periodTimes.count-1].split(separator: "-")
        let endTimeEnd = getDate(hourMinute: endTimeArray[1], day: currentDate)
        
        let schoolStartToPastRange = Date.distantPast ... startTimeStart
        if schoolStartToPastRange.contains(currentDate)
        {
            OperationQueue.main.addOperation {
                self.schoolStartEndLabel.text = "School starts today at " + Date().convertToStandardTime(date: String(startTimeArray[0]))
            }
        }
        else
        {
            OperationQueue.main.addOperation {
                self.schoolStartEndLabel.text = "School started today at " + Date().convertToStandardTime(date: String(startTimeArray[0]))
            }
        }
        
        let schoolEndToPastRange = Date.distantPast ... endTimeEnd
        if schoolEndToPastRange.contains(currentDate)
        {
            OperationQueue.main.addOperation {
                self.schoolStartEndLabel.text = self.schoolStartEndLabel.text! + "\nSchool ends today at " + Date().convertToStandardTime(date: String(endTimeArray[1]))
            }
        }
        else
        {
            OperationQueue.main.addOperation {
                self.schoolStartEndLabel.text = self.schoolStartEndLabel.text! + "\nSchool ended today at " + Date().convertToStandardTime(date: String(endTimeArray[1]))
            }
        }
    }
    
    //MARK: Print
    
    func printCurrentStatus(message: String)
    {
        OperationQueue.main.addOperation {
            self.currentPeriodLabel.text = message
        }
    }
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int)
    {
        let periodNumbers = todaySchedule!.object(forKey: "periodNumbers") as! Array<Int>
        let periodRangeSplit = periodRangeString.split(separator: "-")
        let periodStartString = Date().convertToStandardTime(date: String(periodRangeSplit[0]))
        let periodEndString = Date().convertToStandardTime(date: String(periodRangeSplit[1]))
        
        let periodInfo1 = "The current period is " + String(periodNumbers[periodNumber-1]) + "\n"
        let periodInfo2 = periodStartString! + "-" + periodEndString!
        OperationQueue.main.addOperation {
            self.currentPeriodLabel.text = periodInfo1 + periodInfo2
        }
        
        self.periodNumber = periodNumber
        
        periodPrinted = true
        
        if periodNames != nil
        {
            printPeriodName()
        }
    }
    
    func printPeriodName()
    {
        let periodNumbers = todaySchedule!.object(forKey: "periodNumbers") as! Array<Int>
        OperationQueue.main.addOperation {
            if self.periodNames!.count > periodNumbers[self.periodNumber!-1]-1
            {
                self.currentPeriodLabel.text = self.currentPeriodLabel.text! + "\n" + self.periodNames![periodNumbers[self.periodNumber!-1]-1]
            }
        }
    }
    
    func printTomorrowStartTime(tomorrowSchedule: CKRecord)
    {
        let tomorrowPeriodTimes = tomorrowSchedule.object(forKey: "periodTimes") as! Array<String>
        
        let startOfNextSchoolDayRaw = Date().getStartOfNextWeek(nextWeek: nextWeekOn!)
        let gregorian = Calendar(identifier: .gregorian)
        var components = gregorian.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: startOfNextSchoolDayRaw)
        components.hour = 12
        components.weekday = nextDayOn
        let startOfNextSchoolDayFormatted = gregorian.date(from: components)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let startOfNextSchoolDayString = formatter.string(from: startOfNextSchoolDayFormatted)
        let tomorrowSchoolStartTime = tomorrowPeriodTimes[0].split(separator: "-")[0]
        let weekDayOfSchoolStart = Date().getStringDayOfWeek(day: Date().getDayOfWeek() + nextDayOn! + 1)
        
        OperationQueue.main.addOperation {
            let schoolStart1 = "School starts " + weekDayOfSchoolStart + ",\n" + startOfNextSchoolDayString
            let schoolStart2 = " at " + Date().convertToStandardTime(date: String(tomorrowSchoolStartTime))
            self.tomorrowStartTimeLabel.text = schoolStart1 + schoolStart2
        }
    }
}

