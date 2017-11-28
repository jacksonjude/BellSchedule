//
//  TodayViewController.swift
//  ScheduleWidget
//
//  Created by jackson on 11/23/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import NotificationCenter
import CoreData
import CloudKit

class TodayViewController: UIViewController, NCWidgetProviding, ScheduleInfoDelegate {
    @IBOutlet weak var schoolStartEndLabel: UILabel!
    @IBOutlet weak var tomorrowStartTimeLabel: UILabel!
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject, periodNames: Array<String>?) {
        return
    }
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>) {
        return
    }
    
    func printCurrentMessage(message: String) {
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.text = message
        }
    }
    
    func printInternalError(message: String, labelNumber: Int) {
        return
    }
    
    func printSchoolStartEndMessage(message: String) {
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.text = message
        }
    }
    
    func printSchoolStartEndTime(periodTimes: Array<String>) {
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
    
    func printTomorrowStartTime(tomorrowSchedule: NSManagedObject, nextWeekCount: Int, nextDayCount: Int) {
        if let tomorrowPeriodTimes = self.decodeArrayFromJSON(object: tomorrowSchedule, field: "periodTimes") as? Array<String>
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
            print(error)
            return nil
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
    
    var scheduleInfoManager: ScheduleInfoManager?
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.
        
        scheduleInfoManager = ScheduleInfoManager(delegate: self, downloadData: false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
}
