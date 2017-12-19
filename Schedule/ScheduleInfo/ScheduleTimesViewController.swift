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
    
    var viewHasAppeared = false
    
    var dateTitle = "Loading..."
    var periodTimesText = "Loading..."
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.addCorners()
        periodTimesTextView.addCorners()
        
        Logger.println("Opening ScheduleTimes...")
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
            
            dateTitle = scheduleMonth + "-" + scheduleDay + scheduleYear +  " -- " + scheduleCode
            
            let periodTimes = appDelegate.decodeArrayFromJSON(object: scheduleRecord!, field: "periodTimes") as! Array<String>
            
            let periodNumbers = appDelegate.decodeArrayFromJSON(object: scheduleRecord!, field: "periodNumbers") as! Array<Int>
            
            for periodNumber in periodNumbers
            {
                let periodIndex = periodNumbers.index(of: periodNumber) ?? 0
                periodTimesText += "Period " + String(periodNumber) + " -- " + periodTimes[periodIndex]
                if periodIndex+1 != periodNumbers.count
                {
                    periodTimesText += "\n"
                }
            }
            
            Logger.println(" SCT: Loaded schedule times data")
            
            refreshText()
        }
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
}
