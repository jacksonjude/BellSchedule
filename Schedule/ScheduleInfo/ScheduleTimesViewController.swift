//
//  ScheduleTimesViewController.swift
//  Schedule
//
//  Created by jackson on 12/17/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class ScheduleTimesViewController: UIViewController
{
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var periodTimesTextView: UITextView!
    
    var scheduleRecord: NSManagedObject?
    var scheduleDateString: String?
    var parentViewControllerString: String?
    
    var viewHasAppeared = false
    
    var dateTitle = "Loading..."
    var periodTimesText = "Loading..."
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.addCorners()
        periodTimesTextView.addCorners()
        
        Logger.println("Opening ScheduleTimes...")
        
        self.view.setBackground()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadFromScheduleData()
    }
    
    func loadFromScheduleData()
    {
        if scheduleRecord != nil// && scheduleDate != nil
        {
            dateTitle = ""
            periodTimesText = ""
            
            let splitDateString = scheduleDateString!.split(separator: "/")
            
            let scheduleYear = String(splitDateString[2])
            let scheduleMonth = String(splitDateString[0])
            let scheduleDay = String(splitDateString[1])
            
            let scheduleCode = String(describing: scheduleRecord!.value(forKey: "scheduleCode")!)
            
            dateTitle = scheduleMonth + "-" + scheduleDay + "-" + scheduleYear +  " -- " + scheduleCode
            
            let periodTimes = appDelegate.decodeArrayFromJSON(object: scheduleRecord!, field: "periodTimes") as! Array<String>
            
            let periodNumbers = appDelegate.decodeArrayFromJSON(object: scheduleRecord!, field: "periodNumbers") as! Array<Int>
            
            for periodNumber in periodNumbers
            {
                let periodIndex = periodNumbers.index(of: periodNumber) ?? 0
                let periodMinutes = String(calculateMinutes(periodRangeString: periodTimes[periodIndex]))
                
                let periodStart = periodTimes[periodIndex].split(separator: "-")[0]
                let periodStartHour = Int(periodStart.split(separator: ":")[0]) ?? 0
                let periodStartMinute = Int(periodStart.split(separator: ":")[1]) ?? 0
                
                let periodEnd = periodTimes[periodIndex].split(separator: "-")[1]
                let periodEndHour = Int(periodEnd.split(separator: ":")[0]) ?? 0
                let periodEndMinute = Int(periodEnd.split(separator: ":")[1]) ?? 0
                
                let periodStartFormatted = zeroPadding(periodStartHour) + ":" + zeroPadding(periodStartMinute)
                let periodEndFormatted = zeroPadding(periodEndHour) + ":" + zeroPadding(periodEndMinute)
                
                periodTimesText += "PER " + String(periodNumber) + " - " + periodStartFormatted + "-" + periodEndFormatted + " - " + periodMinutes + " MIN"
                if periodIndex+1 != periodNumbers.count
                {
                    periodTimesText += "\n"
                }
            }
            
            Logger.println(" SCT: Loaded schedule times data")
            
            refreshText()
        }
    }
    
    func calculateMinutes(periodRangeString: String) -> Int
    {
        let periodStart = periodRangeString.split(separator: "-")[0]
        let periodStartHour = Int(periodStart.split(separator: ":")[0]) ?? 0
        let periodStartMinute = Int(periodStart.split(separator: ":")[1]) ?? 0
        
        let periodEnd = periodRangeString.split(separator: "-")[1]
        let periodEndHour = Int(periodEnd.split(separator: ":")[0]) ?? 0
        let periodEndMinute = Int(periodEnd.split(separator: ":")[1]) ?? 0
        
        let totalMinutes = (60*(periodEndHour - periodStartHour)) + (periodEndMinute - periodStartMinute)
        
        return totalMinutes
    }
    
    func refreshText()
    {
        titleLabel.text = dateTitle
        periodTimesTextView.text = periodTimesText
        
        Logger.println(" SCT: Refreshing Text")
        
        let fixedWidth = periodTimesTextView.frame.size.width
        let newSize = periodTimesTextView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat(MAXFLOAT)))
        var newFrame = periodTimesTextView.frame
        newFrame.size = CGSize(width: CGFloat(fmaxf(Float(newSize.width), Float(fixedWidth))), height: newSize.height)
        periodTimesTextView.frame = newFrame        
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
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        switch parentViewControllerString
        {
        case "CalendarCollectionViewController":
            self.performSegue(withIdentifier: "exitPeriodTimesViewToCalendar", sender: self)
        case "ScheduleInfoViewController":
            self.performSegue(withIdentifier: "exitPeriodTimesViewToScheduleInfo", sender: self)
        default:
            break
        }
    }
}
