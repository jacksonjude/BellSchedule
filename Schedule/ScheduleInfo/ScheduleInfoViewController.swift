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
import SafariServices

let appDelegate = UIApplication.shared.delegate as! AppDelegate

var backgroundName = "background1"

extension UIView
{
    func addCorners()
    {
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
    }
    
    func setBackground()
    {
        (self.viewWithTag(819) as! UIImageView).image = UIImage(named: backgroundName)
    }
}

class ScheduleInfoViewController: UIViewController, ScheduleInfoDelegate {
    var scheduleManager: ScheduleInfoManager?
    
    @IBOutlet weak var currentPeriodLabel: UILabel!
    @IBOutlet weak var schoolStartEndLabel: UILabel!
    @IBOutlet weak var tomorrowStartTimeLabel: UILabel!
    
    @IBOutlet weak var editScheduleButton: UIButton!
    @IBOutlet weak var openCalendarButton: UIButton!
    @IBOutlet weak var announcementButton: UIButton!
    @IBOutlet weak var helpButton: UIButton!
    
    
    var periodNumber: Int?
    
    var syncButtonValue = true
    var refreshTimer: Timer?
    
    let kCurrentPeriodLabel = 0
    let kSchoolStartTime = 1
    let kTomorrowStartTimeLabel = 2
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        
        scheduleManager = ScheduleInfoManager(delegate: self, downloadData: true, onlyFindOneDay: false)
        scheduleManager?.startInfoManager()
        
        NotificationCenter.default.addObserver(self, selector: #selector(printCloudKitError(notification:)), name: Notification.Name(rawValue: "cloudKitError"), object: nil)
        
        self.view.setBackground()
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
        openCalendarButton.addCorners()
        helpButton.addCorners()
        announcementButton.addCorners()
        
        if appDelegate.justLaunched
        {
            appDelegate.justLaunched = false
        }
        
        if appDelegate.refreshDataOnScheduleViewController
        {
            appDelegate.refreshDataOnScheduleViewController = false
            
            refreshPeriodInfo(self)
        }
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
        
        Logger.println("Timer will start in: " + String(timeUntilNext5minutes))
        
        self.refreshTimer = Timer.scheduledTimer(timeInterval: timeUntilNext5minutes, target: self, selector: #selector(startRefreshTimer), userInfo: nil, repeats: false)
    }
    
    func setTimer(_ time: String) {
        var currentTimeComponents = Date.Gregorian.calendar.dateComponents([.year, .day, .month, .hour, .minute, .second], from: Date())
        
        var timeOfNextPeriodString = String(describing: currentTimeComponents.year!) + "-" + String(describing: currentTimeComponents.month!) + "-" + String(describing: currentTimeComponents.day!)
        
        timeOfNextPeriodString += "-" + String(time.split(separator: ":")[0])
        timeOfNextPeriodString += "-" + String(time.split(separator: ":")[1])
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd-HH-mm"
        
        let timeUntilNextPeriodComponents = Date.Gregorian.calendar.dateComponents([.hour, .minute, .second], from: Date(), to: dateFormatter.date(from: timeOfNextPeriodString) ?? Date.distantFuture)
        
        let timeUntilNextPeriodInterval = TimeInterval((timeUntilNextPeriodComponents.hour! * 3600) + (timeUntilNextPeriodComponents.minute! * 60) + (timeUntilNextPeriodComponents.second!))
        
        Logger.println("Timer will start in: " + String(timeUntilNextPeriodInterval))
        
        self.refreshTimer = Timer.scheduledTimer(timeInterval: timeUntilNextPeriodInterval, target: self, selector: #selector(startRefreshTimer), userInfo: nil, repeats: false)
    }
    
    @objc func startRefreshTimer()
    {
        refreshPeriodInfo(self)
        let _ = Timer.scheduledTimer(timeInterval: 300.0, target: self, selector: #selector(refreshPeriodInfo(_:)), userInfo: nil, repeats: true)
        Logger.println("Starting timer!")
    }
    
    //MARK: Settings
    
    @IBAction func openSettings(_ sender: Any) {
        Logger.println("SET: Opening settings...")
        
        let settingsAlert = UIAlertController(title: "Settings", message: "\n\n", preferredStyle: .alert)
        
        settingsAlert.addTextField { (textField) in
            textField.placeholder = (UserDefaults.standard.object(forKey: "userID") as? String) ?? "UserID"
        }
        
        settingsAlert.addTextField { (textField) in
            let backgroundNumber = String(describing: backgroundName.last ?? Character(""))
            textField.text = String(describing: backgroundNumber)
        }
        
        settingsAlert.addTextField{ (textField) in
            var notificationAlertTime = (UserDefaults.standard.object(forKey: "notificationAlertTime") as? String) ?? "21:00"
            var formattedNotificationAlertTime = ""
            
            if Int(notificationAlertTime.split(separator: ":")[1]) ?? 0 < 10
            {
                notificationAlertTime = notificationAlertTime.split(separator: ":")[0] + ":0" + notificationAlertTime.split(separator: ":")[1]
            }
            
            if (Int(notificationAlertTime.split(separator: ":")[0]) ?? 0) > 12 || (Int(notificationAlertTime.split(separator: ":")[0]) ?? 0) == 0
            {
                let formattedNotificationAlertTime1 = String((Int(notificationAlertTime.split(separator: ":")[0]) ?? 0) - 12)
                let formattedNotificationAlertTime2 = ":" + String(notificationAlertTime.split(separator: ":")[1]) + " PM"
                formattedNotificationAlertTime = formattedNotificationAlertTime1 + formattedNotificationAlertTime2
            }
            else if (Int(notificationAlertTime.split(separator: ":")[0]) ?? 0) == 12
            {
                formattedNotificationAlertTime = notificationAlertTime + " PM"
            }
            else if (Int(notificationAlertTime.split(separator: ":")[0]) ?? 0) == 0
            {
                formattedNotificationAlertTime = "12:" + String(notificationAlertTime.split(separator: ":")[1]) + " AM"
            }
            else
            {
                formattedNotificationAlertTime = notificationAlertTime + " AM"
            }
            
            textField.text = formattedNotificationAlertTime
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
            Logger.println("SET: Updating settings...")
            
            let userID = settingsAlert.textFields![0].text
            if userID != nil && userID != ""
            {
                UserDefaults.standard.set(userID, forKey: "userID")
                Logger.println(" USRID: Set userID: " + userID!)
            }
            
            let backgroundFileNumber = settingsAlert.textFields![1].text ?? "1"
            if UIImage(named: "background" + backgroundFileNumber) != nil
            {
                backgroundName = "background" + backgroundFileNumber
                self.view.setBackground()
                
                UserDefaults.standard.set(backgroundName, forKey: "backgroundName")
            }
            
            /*var dateRegex: NSRegularExpression? = nil
             do
             {
             dateRegex =  try NSRegularExpression(pattern: "^\\s*\\d+:\\d\\d\\s*[apAP]?[mM]?$", options: NSRegularExpression.Options.caseInsensitive)
             }
             catch
             {
             print(error.localizedDescription)
             }
             
             let range = NSMakeRange(0, notificationAlertTimeString.count)
             let matches = dateRegex?.matches(in: notificationAlertTimeString, options: NSRegularExpression.MatchingOptions.anchored, range: range)
             if matches != nil && matches!.count > 0*/
            
            let notificationAlertTimeString = settingsAlert.textFields![2].text ?? ((UserDefaults.standard.object(forKey: "notificationAlertTime") as? String) ?? "21:00")
            if notificationAlertTimeString.range(of: "^\\s*\\d+:\\d\\d\\s*[apAP]?[mM]?$", options: .regularExpression, range: nil, locale: nil) != nil
            {
                Logger.println("NAT: Formatting notification alert time: " + notificationAlertTimeString)
                
                var notificationAlertTimeHour = Int(notificationAlertTimeString.split(separator: ":")[0]) ?? 21
                let notificationAlertTimeMinute = Int(notificationAlertTimeString.split(separator: ":")[1]) ?? 0
                
                if notificationAlertTimeString.lowercased().range(of: "pm") != nil && notificationAlertTimeHour != 12
                {
                    notificationAlertTimeHour += 12
                }
                
                let formattedNotificationAlertTime = String(notificationAlertTimeHour) + ":" + String(notificationAlertTimeMinute)
                
                Logger.println("NAT: Setting notification alert time: " + formattedNotificationAlertTime)
                
                UserDefaults.standard.set(formattedNotificationAlertTime, forKey: "notificationAlertTime")
                
                appDelegate.scheduleNotificationManager?.setupNotifications()
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
        Logger.println("Refreshing:")
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
    
    func printSchoolStartEndTime(periodTimes: Array<String>)
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
    
    func printCurrentMessage(message: String)
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
                    self.scheduleManager?.periodNamePrinted = true
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
    
    func printSchoolStartEndMessage(message: String)
    {
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.text = message
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
    
    @IBAction func openHelp(_ sender: Any) {
        let faqURL = URL(string: "http://jjcooley.ddns.net/lowellschedule")
        let svc = SFSafariViewController(url: faqURL!)
        self.present(svc, animated: true, completion: nil)
    }
    
    @IBAction func exitUserScheduleTableView(_ segue: UIStoryboardSegue)
    {
        let source = segue.source as! UserScheduleTableViewController
        
        if source.uploadData
        {
            Logger.println("Exiting UserSchedule and uploading...")
            if let userID = UserDefaults.standard.object(forKey: "userID") as? String
            {
                if (source.periodNames.count > 0)
                {
                    let userScheduleDictionary = ["periodNames":source.periodNames, "userID":userID] as [String : Any]
                    CloudManager.setPublicDatabaseObject(type: "UserSchedule", dataDictionary: userScheduleDictionary, predicate: NSPredicate(format: "userID == %@", userID))
                }
            }
        }
        else
        {
            Logger.println("Exiting UserSchedule...")
        }
    }
    
    @IBAction func exitCalendar(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting Calendar...")
    }
    
    @IBAction func exitDeveloperView(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting DeveloperView...")
    }
    
    @IBAction func exitAnnouncementsTableView(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting AnnouncementsTableView...")
    }
}

