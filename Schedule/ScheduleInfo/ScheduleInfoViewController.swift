//
//  ViewController.swift
//  Schedule
//
//  Created by jackson on 10/5/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CloudKit
import CoreData

let appDelegate = UIApplication.shared.delegate as! AppDelegate

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

extension UIView
{
    func addCorners()
    {
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
    }
}

class ScheduleInfoViewController: UIViewController {
    var scheduleManager: ScheduleInfoManager?
    
    @IBOutlet weak var currentPeriodLabel: UILabel!
    @IBOutlet weak var schoolStartEndLabel: UILabel!
    @IBOutlet weak var tomorrowStartTimeLabel: UILabel!
    @IBOutlet weak var editScheduleButton: UIButton!
    @IBOutlet weak var openCalenderButton: UIButton!
    
    var periodPrinted = false
    var periodNumber: Int?
    
    var syncButtonValue = true
    var refreshTimer: Timer?
    
    let kCurrentPeriodLabel = 0
    let kSchoolStartTime = 1
    let kTomorrowStartTimeLabel = 2
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        
        scheduleManager = ScheduleInfoManager(viewController: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(printCloudKitError(notification:)), name: Notification.Name(rawValue: "cloudKitError"), object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        currentPeriodLabel.addCorners()
        schoolStartEndLabel.addCorners()
        tomorrowStartTimeLabel.addCorners()
        editScheduleButton.addCorners()
        openCalenderButton.addCorners()
        
        if appDelegate.justLaunched
        {
            appDelegate.justLaunched = false
        }
        
        calculateTimerRefresh()
    }
    
    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if refreshTimer != nil
        {
            refreshTimer?.invalidate()
        }
    }
    
    func calculateTimerRefresh()
    {
        if refreshTimer != nil
        {
            refreshTimer?.invalidate()
        }
        
        let secondMinuteComponents = Date.Gregorian.calendar.dateComponents([.minute, .second], from: Date())
        let secondsToMinute = 60 - (secondMinuteComponents.second! % 60)
        let minuteTo5minutes = 5 - (secondMinuteComponents.minute! % 5)
        
        let timeUntilNext5minutes = TimeInterval(secondsToMinute + (minuteTo5minutes*60) - 60)
        
        logger.println("Timer will start in: " + String(timeUntilNext5minutes))
        
        self.refreshTimer = Timer.scheduledTimer(timeInterval: timeUntilNext5minutes, target: self, selector: #selector(startRefreshTimer), userInfo: nil, repeats: false)
    }
    
    @objc func startRefreshTimer()
    {
        refreshPeriodInfo(self)
        let _ = Timer.scheduledTimer(timeInterval: 300.0, target: self, selector: #selector(refreshPeriodInfo(_:)), userInfo: nil, repeats: true)
        logger.println("Starting timer!")
    }
    
    //MARK: Settings
    
    @IBAction func openSettings(_ sender: Any) {
        let settingsAlert = UIAlertController(title: "Settings", message: "\n\n", preferredStyle: .alert)
        
        settingsAlert.addTextField { (textFeild) in
            textFeild.placeholder = (UserDefaults.standard.object(forKey: "userID") as? String) ?? "UserID"
        }
        
        settingsAlert.view.addSubview(createSwitch())
        
        let syncLabel = UILabel(frame: CGRect(x: 15, y: 40, width: 200, height: 70))
        syncLabel.text = "Sync:"
        syncLabel.font = UIFont(name: "System", size: 15)
        settingsAlert.view.addSubview(syncLabel)
        
        settingsAlert.addAction(UIAlertAction(title: "Dev", style: .default, handler: { (alert) in
            self.performSegue(withIdentifier: "openDeveloperView", sender: self)
        }))
        
        settingsAlert.addAction(UIAlertAction(title: "Set", style: .default, handler: { (alert) in
            let userID = settingsAlert.textFields![0].text
            if userID != nil && userID != ""
            {
                UserDefaults.standard.set(userID, forKey: "userID")
                logger.println(" USRID: Set userID: " + userID!)
            }
            
            UserDefaults.standard.set(self.syncButtonValue, forKey: "syncData")
        }))
        
        self.present(settingsAlert, animated: true) {
            
        }
    }
    
    func createSwitch() -> UISwitch
    {
        let switchControl = UISwitch(frame: CGRect(x: 65, y: 60, width: 0, height: 0))
        switchControl.isOn = UserDefaults.standard.object(forKey: "syncData") as? Bool ?? true
        switchControl.setOn(UserDefaults.standard.object(forKey: "syncData") as? Bool ?? true, animated: false)
        switchControl.addTarget(self, action: #selector(switchValueDidChange(sender:)), for: .valueChanged)
        return switchControl
    }
    
    @objc func switchValueDidChange(sender: UISwitch!)
    {
        syncButtonValue = sender.isOn
    }
    
    //MARK: Refresh Info
    
    @IBAction func refreshPeriodInfo(_ sender: Any)
    {
        logger.println("Refreshing:")
        OperationQueue.main.addOperation {
            self.currentPeriodLabel.text = "Loading..."
            self.schoolStartEndLabel.text = "Loading..."
            self.tomorrowStartTimeLabel.text = "Loading..."
        }
        
        if UserDefaults.standard.object(forKey: "syncData") as? Bool ?? true
        {
            scheduleManager!.downloadCloudData()
        }
        else
        {
            scheduleManager!.refreshScheduleInfo()
        }
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
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject, periodNames: Array<String>?)
    {
        if let periodNumbers = appDelegate.decodeArrayFromJSON(object: todaySchedule, field: "periodNumbers") as? Array<Int>
        {
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
    }
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>)
    {
        if let periodNumbers = appDelegate.decodeArrayFromJSON(object: todaySchedule, field: "periodNumbers") as? Array<Int>
        {
            OperationQueue.main.addOperation {
                if periodNames.count > periodNumbers[self.periodNumber!-1]-1
                {
                    self.currentPeriodLabel.text = self.currentPeriodLabel.text! + "\n" + periodNames[periodNumbers[self.periodNumber!-1]-1]
                }
            }
        }
    }
    
    func printTomorrowStartTime(tomorrowSchedule: NSManagedObject, nextWeekCount: Int, nextDayCount: Int)
    {
        if let tomorrowPeriodTimes = appDelegate.decodeArrayFromJSON(object: tomorrowSchedule, field: "periodTimes") as? Array<String>
        {
            //Determine the date when school starts next
            var startOfNextSchoolDayRaw = Date().getStartOfNextWeek(nextWeek: nextWeekCount)
            let gregorian = Calendar(identifier: .gregorian)
            
            //Find the current day of the week from 0-6
            let todayComponents = gregorian.dateComponents([.weekday], from: Date())
            let currentDayOfWeek = todayComponents.weekday! - 1
            
            let dayInSeconds = (60*60*24+3600)
            
            //Add currentDayOfWeek to the nextDayCount in seconds
            var weekDaysToAdd = 0.0
            if nextWeekCount > 0
            {
                weekDaysToAdd = Double(dayInSeconds * (nextDayCount + 1))
            }
            else
            {
                weekDaysToAdd = Double(dayInSeconds * (nextDayCount + 1 + currentDayOfWeek))
            }
            startOfNextSchoolDayRaw.addTimeInterval(weekDaysToAdd)
            
            //Set the hour correctly
            var startOfNextSchoolDayComponents = gregorian.dateComponents([.month, .day, .weekday], from: startOfNextSchoolDayRaw)
            startOfNextSchoolDayComponents.hour = 12
            let startOfNextSchoolDayFormatted = gregorian.date(from: startOfNextSchoolDayComponents)!
            
            //Format as MM/dd
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            let startOfNextSchoolDayString = formatter.string(from: startOfNextSchoolDayFormatted)
            
            //Get the start time and the weekday name
            let tomorrowSchoolStartTime = tomorrowPeriodTimes[0].split(separator: "-")[0]
            
            var weekDayOfSchoolStart = ""
            if nextWeekCount > 0
            {
                weekDayOfSchoolStart = Date().getStringDayOfWeek(day: nextDayCount + 1)
            }
            else
            {
                weekDayOfSchoolStart = Date().getStringDayOfWeek(day: nextDayCount + 1 + currentDayOfWeek)
            }
            
            OperationQueue.main.addOperation {
                let schoolStart1 = "School starts " + weekDayOfSchoolStart + ",\n" + startOfNextSchoolDayString
                let schoolStart2 = " at " + Date().convertToStandardTime(date: String(tomorrowSchoolStartTime))
                self.tomorrowStartTimeLabel.text = schoolStart1 + schoolStart2
            }
        }
    }
    
    func printSchoolStartTimeStatus(status: String)
    {
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.text = status
        }
    }
    
    @objc func printCloudKitError(notification: NSNotification)
    {
        OperationQueue.main.addOperation {
            if (self.currentPeriodLabel.text?.contains("Loading...") ?? true)
            {
                let cloudKitError = notification.object as! CKError
                let errorDesc = cloudKitError.localizedDescription
                switch cloudKitError.code
                {
                    case .internalError:
                        self.currentPeriodLabel.text = "Internal CloudKit Error\nSign in to iCloud"
                    case .serviceUnavailable:
                        self.currentPeriodLabel.text = "CloudKit Service Unavailable\nSign in to iCloud"
                    case .notAuthenticated:
                        self.currentPeriodLabel.text = "Not Authenticated\nSign in to iCloud"
                    case .networkFailure:
                        self.currentPeriodLabel.text = "Network Failure\nCheck your connection"
                    case .networkUnavailable:
                        self.currentPeriodLabel.text = "Network Unavailable\nCheck your connection"
                    default:
                        self.currentPeriodLabel.text = "CloudKit Error:\n" + errorDesc
                }
            }
        }
    }
    
    func printInternalError(message: String, labelNumber: Int)
    {
        var labelToSwitch: UILabel?
        
        switch labelNumber
        {
            case kCurrentPeriodLabel:
                labelToSwitch = self.currentPeriodLabel
            case kSchoolStartTime:
                labelToSwitch = self.schoolStartEndLabel
            case kTomorrowStartTimeLabel:
                labelToSwitch = self.tomorrowStartTimeLabel
            default:
                labelToSwitch = self.currentPeriodLabel
        }
        
        OperationQueue.main.addOperation {
            labelToSwitch!.text = "Internal Error:\n" + message
        }
    }
    
    @IBAction func exitUserScheduleTableView(_ segue: UIStoryboardSegue)
    {
        let source = segue.source as! UserScheduleTableViewController
        
        if source.uploadData
        {
            logger.println("Exiting UserSchedule and uploading...")
            if let userID = UserDefaults.standard.object(forKey: "userID") as? String
            {
                if (source.periodNames.count > 0)
                {
                    let userScheduleDictionary = ["periodNames":source.periodNames, "userID":userID] as [String : Any]
                    appDelegate.cloudManager!.setPublicDatabaseObject(type: "UserSchedule", dataDictionary: userScheduleDictionary, predicate: NSPredicate(format: "userID == %@", userID))
                }
            }
        }
        else
        {
            logger.println("Exiting UserSchedule...")
        }
    }
    
    @IBAction func exitCalendar(_ segue: UIStoryboardSegue)
    {
        logger.println("Exiting Calendar...")
    }
    
    @IBAction func exitDeveloperView(_ segue: UIStoryboardSegue)
    {
        logger.println("Exiting Developer View...")
    }
}

