//
//  InterfaceController.swift
//  ScheduleWatch Extension
//
//  Created by jackson on 12/10/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import WatchKit
import Foundation

class ScheduleInfoController: WKInterfaceController
{
    @IBOutlet var currentPeriodLabel: WKInterfaceLabel!
    @IBOutlet var schoolStartEndLabel: WKInterfaceLabel!
    @IBOutlet var tomorrowStartTimeLabel: WKInterfaceLabel!
    
    let extentionDelegate = WKExtension.shared().delegate as! ExtensionDelegate
        
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        
        self.setTitle("Schedule")
        
        if ScheduleDataManager.todayScheduleData == nil || ScheduleDataManager.tomorrowScheduleData == nil
        {
            updateScheduleInfo()
        }
    }
    
    func getTodayData()
    {
        ScheduleDataManager.fetchTodayData(completion: { (todayDictionary) in
            if let errorString = todayDictionary["error"] as? String
            {
                OperationQueue.main.addOperation {
                    self.currentPeriodLabel.setText("Error: " + errorString)
                    self.schoolStartEndLabel.setText("Error: " + errorString)
                }
                
                return
            }
            
            if let messageString = todayDictionary["message"] as? String
            {
                OperationQueue.main.addOperation {
                    self.currentPeriodLabel.setText(messageString)
                    self.schoolStartEndLabel.setText(messageString)
                }
                return
            }
            
            if let scheduleCode = todayDictionary["scheduleCode"] as? String, scheduleCode == "H"
            {
                OperationQueue.main.addOperation {
                    self.currentPeriodLabel.setText("No school today")
                    self.schoolStartEndLabel.setText("No school today")
                }
                return
            }
            
            let periodNumbers = todayDictionary["periodNumbers"] as! Array<Int>
            let periodTimes = todayDictionary["periodTimes"] as! Array<String>
            
            OperationQueue.main.addOperation {
                self.displayTodayData(periodTimes: periodTimes, periodNumbers: periodNumbers)
            }
        })
    }
    
    func displayTodayData(periodTimes: Array<String>, periodNumbers: Array<Int>)
    {
        let nowHour = Calendar.current.component(.hour, from: Date())
        let nowMinute = Calendar.current.component(.minute, from: Date())
        var currentPeriodNumber = -1
        var periodOn = 0
        var lastEndHour: Int?
        var lastEndMinute: Int?
        var isPassingPeriod = false
        for periodTime in periodTimes
        {
            let startTime = periodTime.split(separator: "-")[0]
            let endTime = periodTime.split(separator: "-")[1]

            let startHour = Int(startTime.split(separator: ":")[0])!
            let startMinute = Int(startTime.split(separator: ":")[1])!
            let endHour = Int(endTime.split(separator: ":")[0])!
            let endMinute = Int(endTime.split(separator: ":")[1])!

            if (nowHour > startHour || (nowHour == startHour && nowMinute >= startMinute)) && (nowHour < endHour || (nowHour == endHour && nowMinute < endMinute))
            {
                currentPeriodNumber = periodOn
                break
            }
            else if lastEndHour != nil && lastEndMinute != nil && (lastEndHour! < nowHour || (lastEndHour == nowHour && lastEndMinute! <= nowMinute)) && (startHour > nowHour || (startHour == nowHour && startMinute > nowMinute))
            {
                isPassingPeriod = true
                currentPeriodNumber = periodOn
                break
            }

            lastEndHour = endHour
            lastEndMinute = endMinute
            
            periodOn += 1
        }

        var schoolStarted = false
        var schoolEnded = false

        if currentPeriodNumber != -1 && !isPassingPeriod
        {
            let periodEndTime = periodTimes[currentPeriodNumber].split(separator: "-")[1]
            let periodEndHour = Int(periodEndTime.split(separator: ":")[0])!
            let periodEndMinute = Int(periodEndTime.split(separator: ":")[1])!
            
            let currentPeriodMessage = "Period " + String(periodNumbers[currentPeriodNumber]) + "\n" + String(ScheduleDataManager.convertRangeTo12Hour(periodTimes[currentPeriodNumber]))
            let timeLeftMessage = " (" + String((periodEndHour-nowHour)*60+(periodEndMinute-nowMinute)) + " left)"
            currentPeriodLabel.setText(currentPeriodMessage + timeLeftMessage)

            schoolStarted = true
            schoolEnded = false
        }
        else if isPassingPeriod
        {
            let passingPeriodMessage = "Passing period\n"
            let nextBlockMessage = "Block " + String(periodNumbers[currentPeriodNumber]) + " starts " + periodTimes[currentPeriodNumber].split(separator: "-")[0]
            currentPeriodLabel.setText(passingPeriodMessage + nextBlockMessage)

            schoolStarted = true
            schoolEnded = false
        }
        else
        {
            let schoolStartHour = Int(periodTimes[0].split(separator: "-")[0].split(separator: ":")[0])!
            let schoolStartMinute = Int(periodTimes[0].split(separator: "-")[0].split(separator: ":")[1])!
            let schoolEndHour = Int(periodTimes[periodTimes.count-1].split(separator: "-")[1].split(separator: ":")[0])!
            let schoolEndMinute = Int(periodTimes[periodTimes.count-1].split(separator: "-")[1].split(separator: ":")[1])!

            if nowHour < schoolStartHour || (nowHour == schoolStartHour && nowMinute < schoolStartMinute)
            {
                currentPeriodLabel.setText("School not started")

                schoolStarted = false
                schoolEnded = false
            }
            else if nowHour > schoolEndHour || (nowHour == schoolEndHour && nowMinute >= schoolEndMinute)
            {
                currentPeriodLabel.setText("School ended")

                schoolStarted = true
                schoolEnded = true
            }
        }

        schoolStartEndLabel.setText("School " + (schoolStarted ? " started " : " starts ") + " " + ScheduleDataManager.convertTimeTo12Hour(String(periodTimes[0].split(separator: "-")[0])) + "\nSchool " + (schoolEnded ? " ended " : " ends ") + " " + ScheduleDataManager.convertTimeTo12Hour(String(periodTimes[periodTimes.count-1].split(separator: "-")[1])))
    }
    
    func getTomorrowData()
    {
        ScheduleDataManager.fetchTomorrowData(completion: { (tomorrowDictionary) in
            if let errorString = tomorrowDictionary["error"] as? String
            {
                OperationQueue.main.addOperation {
                    self.tomorrowStartTimeLabel.setText("Error: " + errorString)
                }
                
                return
            }
            
            let startMillis = tomorrowDictionary["date"] as! Double
            let periodTimes = tomorrowDictionary["periodTimes"] as! Array<String>
            
            OperationQueue.main.addOperation {
                self.displayTomorrowData(startMillis: startMillis, periodTimes: periodTimes)
            }
        })
    }
    
    func displayTomorrowData(startMillis: Double, periodTimes: Array<String>)
    {
        let startDate = Date(timeIntervalSince1970: startMillis/1000)
        let month = String(Calendar.current.component(.month, from: startDate))
        let date = String(Calendar.current.component(.day, from: startDate))
        let weekday = String(Date().getStringDayOfWeek(day: Calendar.current.component(.weekday, from: startDate)-1).prefix(3))
        let startTime = String(periodTimes[0].split(separator: "-")[0])
        
        tomorrowStartTimeLabel.setText("School on " + weekday + "\n" + month + "/" + date + " at " + startTime)
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
        
        getTodayData()
        getTomorrowData()
    }
    
    @IBAction func refreshInfo(_ sender: Any) {
        updateScheduleInfo()
    }
}
