//
//  InterfaceController.swift
//  ScheduleWatch Extension
//
//  Created by jackson on 12/10/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import WatchKit
import Foundation
import CoreData


class InterfaceController: WKInterfaceController, ScheduleInfoDelegate {
    
    var periodNumber = 0
    
    func printCurrentPeriod(periodRangeString: String, periodNumber: Int, todaySchedule: NSManagedObject) {
        if let periodNumbers = self.decodeArrayFromJSON(object: todaySchedule, field: "periodNumbers") as? Array<Int>
        {
            let periodRangeSplit = periodRangeString.split(separator: "-")
            let periodStartString = Date().convertToStandardTime(date: String(periodRangeSplit[0]))
            let periodEndString = Date().convertToStandardTime(date: String(periodRangeSplit[1]))
            
            let periodInfo1 = "The current period is " + String(periodNumbers[periodNumber-1]) + "\n"
            let periodInfo2 = periodStartString! + "-" + periodEndString!
            OperationQueue.main.addOperation {
                self.currentPeriodLabel.setText(periodInfo1 + periodInfo2)
            }
            
            self.periodNumber = periodNumber
            
            if self.scheduleInfoManager?.periodNames != nil
            {
                printPeriodName(todaySchedule: todaySchedule, periodNames: self.scheduleInfoManager!.periodNames!)
            }
        }
    }
    
    func printPeriodName(todaySchedule: NSManagedObject, periodNames: Array<String>) {
        return
    }
    
    func printCurrentMessage(message: String) {
        OperationQueue.main.addOperation {
            self.currentPeriodLabel.setText(message)
        }
    }
    
    func printInternalError(message: String, labelNumber: Int) {
        return
    }
    
    func printSchoolStartEndMessage(message: String) {
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.setText(message)
        }
    }
    
    func printSchoolStartEndTime(periodTimes: Array<String>) {
        let currentDate = Date()
        
        let startTimeArray = periodTimes[0].split(separator: "-")
        let startTimeStart = getDate(hourMinute: startTimeArray[0], day: currentDate)
        
        let endTimeArray = periodTimes[periodTimes.count-1].split(separator: "-")
        let endTimeEnd = getDate(hourMinute: endTimeArray[1], day: currentDate)
        
        var schoolStartMessage = ""
        var schoolEndMessage = ""
        
        let schoolStartToPastRange = Date.distantPast ... startTimeStart
        if schoolStartToPastRange.contains(currentDate)
        {
            schoolStartMessage = "School starts today at " + Date().convertToStandardTime(date: String(startTimeArray[0]))
        }
        else
        {
            schoolStartMessage = "School started today at " + Date().convertToStandardTime(date: String(startTimeArray[0]))
        }
        
        let schoolEndToPastRange = Date.distantPast ... endTimeEnd
        if schoolEndToPastRange.contains(currentDate)
        {
            schoolEndMessage = "\nSchool ends today at " + Date().convertToStandardTime(date: String(endTimeArray[1]))
        }
        else
        {
            schoolEndMessage = "\nSchool ended today at " + Date().convertToStandardTime(date: String(endTimeArray[1]))
        }
        
        OperationQueue.main.addOperation {
            self.schoolStartEndLabel.setText(schoolStartMessage + schoolEndMessage)
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
                self.tomorrowStartTimeLabel.setText(schoolStart1 + schoolStart2)
            }
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
    
    @IBOutlet var currentPeriodLabel: WKInterfaceLabel!
    @IBOutlet var schoolStartEndLabel: WKInterfaceLabel!
    @IBOutlet var tomorrowStartTimeLabel: WKInterfaceLabel!
    
    let extentionDelegate = WKExtension.shared().delegate as! ExtensionDelegate
    
    var scheduleInfoManager: ScheduleInfoManager?
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        
        scheduleInfoManager = ScheduleInfoManager(delegate: self, downloadData: true, onlyFindOneDay: false)
        scheduleInfoManager?.startInfoManager()
        
        //updateScheduleInfo()
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    func updateScheduleInfo()
    {
        currentPeriodLabel.setText("Loading...")
        schoolStartEndLabel.setText("Loading...")
        tomorrowStartTimeLabel.setText("Loading...")
        
        scheduleInfoManager?.refreshScheduleInfo()
    }
    
    @IBAction func refreshInfo(_ sender: Any) {
        updateScheduleInfo()
    }
}
