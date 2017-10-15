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

class ScheduleInfoViewController: UIViewController {
    let appDelegate = UIApplication.shared.delegate! as! AppDelegate
    var scheduleManager: ScheduleInfoManager?
    
    @IBOutlet weak var currentPeriodLabel: UILabel!
    @IBOutlet weak var schoolStartEndLabel: UILabel!
    @IBOutlet weak var tomorrowStartTimeLabel: UILabel!
    @IBOutlet weak var editScheduleButton: UIButton!
    @IBOutlet weak var openCalenderButton: UIButton!
    
    var periodPrinted = false
    var periodNumber: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scheduleManager = ScheduleInfoManager(viewController: self)
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
        
        if appDelegate.justLaunched
        {
            appDelegate.justLaunched = false
            refreshPeriodInfo(self)
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(refreshPeriodInfo(_:)), name: Notification.Name(rawValue: "refreshScheduleInfo"), object: nil)
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
    
    //MARK: Refresh Info
    
    @IBAction func refreshPeriodInfo(_ sender: Any)
    {
        print("Refreshing:")
        OperationQueue.main.addOperation {
            self.currentPeriodLabel.text = "Loading..."
            self.schoolStartEndLabel.text = "Loading..."
            self.tomorrowStartTimeLabel.text = "Loading..."
        }
        
        scheduleManager!.refreshScheduleInfo()
        
        //getUserID()
        //queryWeekSchedule()
    }
        
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
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: CKRecord, periodNames: Array<String>?)
    {
        let periodNumbers = todaySchedule.object(forKey: "periodNumbers") as! Array<Int>
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
            printPeriodName(todaySchedule: todaySchedule, periodNames: periodNames!)
        }
    }
    
    func printPeriodName(todaySchedule: CKRecord, periodNames: Array<String>)
    {
        let periodNumbers = todaySchedule.object(forKey: "periodNumbers") as! Array<Int>
        OperationQueue.main.addOperation {
            if periodNames.count > periodNumbers[self.periodNumber!-1]-1
            {
                self.currentPeriodLabel.text = self.currentPeriodLabel.text! + "\n" + periodNames[periodNumbers[self.periodNumber!-1]-1]
            }
        }
    }
    
    func printTomorrowStartTime(tomorrowSchedule: CKRecord, nextWeekCount: Int, nextDayCount: Int)
    {
        let tomorrowPeriodTimes = tomorrowSchedule.object(forKey: "periodTimes") as! Array<String>
        
        var startOfNextSchoolDayRaw = Date().getStartOfNextWeek(nextWeek: nextWeekCount)
        let gregorian = Calendar(identifier: .gregorian)
        let weekDaysToAdd = Double(60*60*24*(nextDayCount + 1))
        startOfNextSchoolDayRaw.addTimeInterval(weekDaysToAdd)
        var components = gregorian.dateComponents([.month, .day, .weekday], from: startOfNextSchoolDayRaw)
        components.hour = 12
        let startOfNextSchoolDayFormatted = gregorian.date(from: components)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        let startOfNextSchoolDayString = formatter.string(from: startOfNextSchoolDayFormatted)
        let tomorrowSchoolStartTime = tomorrowPeriodTimes[0].split(separator: "-")[0]
        let weekDayOfSchoolStart = Date().getStringDayOfWeek(day: nextDayCount + 1)
        
        OperationQueue.main.addOperation {
            let schoolStart1 = "School starts " + weekDayOfSchoolStart + ",\n" + startOfNextSchoolDayString
            let schoolStart2 = " at " + Date().convertToStandardTime(date: String(tomorrowSchoolStartTime))
            self.tomorrowStartTimeLabel.text = schoolStart1 + schoolStart2
        }
    }
    
    func printSchoolStartTimeStatus(status: String)
    {
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.text = status
        }
    }
    
    @IBAction func exitUserScheduleTableView(_ segue: UIStoryboardSegue)
    {
        
        let source = segue.source as! UserScheduleTableViewController
        
        if source.uploadData
        {
            print("Exiting UserSchedule and uploading...")
            if let userID = UserDefaults.standard.object(forKey: "userID") as? String
            {
                let userScheduleDictionary = ["periodNames":source.periodNames, "userID":userID] as [String : Any]
                appDelegate.cloudManager!.setPublicDatabaseObject(type: "UserSchedule", dataDictionary: userScheduleDictionary, predicate: NSPredicate(format: "userID == %@", userID))
            }
        }
        else
        {
            print("Exiting UserSchedule...")
        }
    }
    
    @IBAction func exitCalendar(_ segue: UIStoryboardSegue)
    {
        print("Exiting Calendar...")
    }
}

