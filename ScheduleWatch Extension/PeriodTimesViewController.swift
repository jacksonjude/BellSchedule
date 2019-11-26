//
//  PeriodTimesViewController.swift
//  ScheduleWatch Extension
//
//  Created by jackson on 11/26/19.
//  Copyright © 2019 jackson. All rights reserved.
//

import WatchKit
import Foundation

class PeriodTimesViewController: WKInterfaceController
{
    @IBOutlet var codeLabel: WKInterfaceLabel!
    @IBOutlet var periodTimesLabel: WKInterfaceLabel!
    
    let extentionDelegate = WKExtension.shared().delegate as! ExtensionDelegate
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        // Configure interface objects here.
        
        self.setTitle("Period Times")
    }
    
    override func didAppear() {
        if ScheduleDataManager.todayScheduleData == nil || ScheduleDataManager.tomorrowScheduleData == nil
        {
            ScheduleDataManager.fetchTodayData { (todayDictionary) in
                ScheduleDataManager.fetchTomorrowData { (tomorrowDictionary) in
                    self.displayPeriodTimes()
                }
            }
        }
        else
        {
            displayPeriodTimes()
        }
    }
    
    func displayPeriodTimes()
    {
        var periodTimes: [String]?
        var periodNumbers: [Int]?
        var scheduleCode: String?
        
        guard let todayDictionary = ScheduleDataManager.todayScheduleData else { return }
        if let todayScheduleCode = todayDictionary["scheduleCode"] as? String, todayScheduleCode != "H" && todayDictionary["message"] == nil
        {
            if todayDictionary["error"] != nil { return }
            
            periodTimes = todayDictionary["periodTimes"] as? [String]
            periodNumbers = todayDictionary["periodNumbers"] as? [Int]
            scheduleCode = todayScheduleCode
        }
        else
        {
            guard let tomorrowDictionary = ScheduleDataManager.tomorrowScheduleData else { return }
            if tomorrowDictionary["error"] != nil { return }
            
            periodTimes = tomorrowDictionary["periodTimes"] as? [String]
            periodNumbers = tomorrowDictionary["periodNumbers"] as? [Int]
            scheduleCode = tomorrowDictionary["scheduleCode"] as? String
        }
        
        if let periodTimes = periodTimes, let periodNumbers = periodNumbers, let scheduleCode = scheduleCode
        {
            codeLabel.setText("Code " + scheduleCode)
            
            var periodTimesString = ""
            var periodOn = 0
            for periodNumber in periodNumbers
            {
                if periodOn != 0
                {
                    periodTimesString += "\n"
                }
                periodTimesString += "P" + String(periodNumber) + " - " + ScheduleDataManager.convertRangeTo12Hour(periodTimes[periodOn])
                periodOn += 1
            }
            
            periodTimesLabel.setText(periodTimesString)
        }
    }
}
