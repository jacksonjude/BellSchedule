//
//  NotificationEditorViewController.swift
//  Schedule
//
//  Created by jackson on 10/31/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class NotificationEditorViewController: UIViewController
{
    @IBOutlet weak var periodButton: UIButton!
    @IBOutlet weak var timeButton: UIButton!
    @IBOutlet weak var beforeAfterStartEndPeriodButton: UIButton!
    @IBOutlet weak var dayBeforeButton: UIButton!
    @IBOutlet weak var editorViewDoneButton: UIButton!
    @IBOutlet weak var editorViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var schedulesButton: UIButton!
    @IBOutlet weak var barDoneButton: UIBarButtonItem!
    
    var schoolNotificationUUID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadNotificationEditorState()
        
        periodButton.addCorners()
        timeButton.addCorners()
        beforeAfterStartEndPeriodButton.addCorners()
        dayBeforeButton.addCorners()
        schedulesButton.addCorners()
        editorViewDoneButton.addCorners()
        self.view.viewWithTag(619)?.addCorners()
        self.view.viewWithTag(620)?.addCorners()
        
        setPeriodButtonTitle()
        setTimeButtonTitle()
        setBeforeAfterStartEndButtonTitle()
        setFireDayBeforeButtonTitle()
        setScheduleButtonTitle()
        
        setEnabledButtons()
        
        self.view.setBackground()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setEnabledButtons), name: NSNotification.Name("SetEnabledButtons"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setPeriodButtonTitle), name: NSNotification.Name("SetPeriodButtonTitle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setTimeButtonTitle), name: NSNotification.Name("SetTimeButtonTitle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setFireDayBeforeButtonTitle), name: NSNotification.Name("SetFireDayBeforeButtonTitle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setBeforeAfterStartEndButtonTitle), name: NSNotification.Name("SetBeforeAfterStartEndButtonTitle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(setScheduleButtonTitle), name: NSNotification.Name("SetScheduleButtonTitle"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(disableEditorDoneButton), name: NSNotification.Name("DisableEditorDoneButton"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(enableEditorDoneButton), name: NSNotification.Name("EnableEditorDoneButton"), object: nil)
    }
    
    func loadNotificationEditorState()
    {
        if let schoolNotification = getSchoolNotification()
        {
            NotificationEditorState.displayTimeAsOffset = schoolNotification.displayTimeAsOffset
            if let notificationPeriodArray = CoreDataStack.decodeArrayFromJSON(object: schoolNotification, field: "notificationPeriodArray") as? Array<Bool>
            {
                NotificationEditorState.notificationPeriodArray = notificationPeriodArray
            }
            NotificationEditorState.notificationTimeHour = Int(schoolNotification.notificationTimeHour)
            NotificationEditorState.notificationTimeMinute = Int(schoolNotification.notificationTimeMinute)
            NotificationEditorState.notificationTimeOffset = Int(schoolNotification.notificationTimeOffset)
            NotificationEditorState.shouldFireDayBefore = schoolNotification.shouldFireDayBefore
            NotificationEditorState.shouldFireWhenPeriodStarts = schoolNotification.shouldFireWhenPeriodStarts
            if schoolNotification.schedulesToFireOn != nil, let schedulesToFireOn = (try? JSONSerialization.jsonObject(with: schoolNotification.schedulesToFireOn!, options: JSONSerialization.ReadingOptions.allowFragments) as? Dictionary<String, Bool>)
            {
                NotificationEditorState.schedulesToFireOn = schedulesToFireOn
            }
            else
            {
                NotificationEditorState.schedulesToFireOn = ["N":true, "M":true, "R":true, "S":true, "+":true]
            }
        }
    }
    
    //var editorViewType: NotificationEditorViewType = .none
    
    func loadEditorView(type: NotificationEditorViewType)
    {
        let oldEditorType = NotificationEditorState.editorViewType
        let newEditorType = type
        
        NotificationEditorState.editorViewType = type
        
        if let editorView = editorViewToShow()
        {
            editorView.isHidden = false
            self.view.viewWithTag(618)?.bringSubviewToFront(editorView)
            self.view.viewWithTag(618)?.bringSubviewToFront(editorViewDoneButton)
        }
        
        if oldEditorType == .none && newEditorType != .none
        {
            showEditorView()
        }
        
        if NotificationEditorState.editorViewType == .beforeAfterStartEnd || NotificationEditorState.editorViewType == .time
        {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ReloadPickerView"), object: self)
        }
        
        if NotificationEditorState.editorViewType == .period || NotificationEditorState.editorViewType == .schedules
        {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "ReloadCheckboxView"), object: self)
        }
    }
    
    func showEditorView()
    {
        editorViewBottomConstraint.constant = -(self.view.viewWithTag(618)!).frame.size.height
        
        editorViewDoneButton.isHidden = false
        editorViewDoneButton.isEnabled = true
        self.view.layoutIfNeeded()
        
        self.editorViewBottomConstraint.constant = 16
        
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }
    
    func hideEditorView()
    {
        editorViewBottomConstraint.constant = -(self.view.viewWithTag(618)!).frame.size.height
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
        }) { (completed) in
            self.view.viewWithTag(619)!.isHidden = true
            self.view.viewWithTag(620)!.isHidden = true
            self.editorViewDoneButton.isHidden = true
            self.editorViewDoneButton.isEnabled = false
            
            self.editorViewBottomConstraint.constant = 16
            self.view.layoutIfNeeded()
        }
    }
    
    func editorViewToShow() -> UIView?
    {
        switch NotificationEditorState.editorViewType
        {
        case .none:
            return nil
        case .period:
            return self.view.viewWithTag(620)
        case .time:
            return self.view.viewWithTag(619)
        case .beforeAfterStartEnd:
            return self.view.viewWithTag(619)
        case .schedules:
            return self.view.viewWithTag(620)
        }
    }
    
    @IBAction func periodButtonPressed(_ sender: Any) {
        loadEditorView(type: .period)
    }
    
    @IBAction func timeButtonPressed(_ sender: Any) {
        loadEditorView(type: .time)
    }
    
    @IBAction func beforeAfterStartEndPeriodButtonPressed(_ sender: Any) {
        loadEditorView(type: .beforeAfterStartEnd)
    }
    
    @IBAction func dayBeforeButtonPressed(_ sender: Any) {
        NotificationEditorState.shouldFireDayBefore = !(NotificationEditorState.shouldFireDayBefore ?? false)
        
        setFireDayBeforeButtonTitle()
    }
    
    @IBAction func editorViewDoneButtonPressed(_ sender: Any) {
        NotificationEditorState.editorViewType = .none
        
        hideEditorView()
    }
    
    @IBAction func schedulesButtonPressed(_ sender: Any) {
        loadEditorView(type: .schedules)
    }
    
    @objc func setPeriodButtonTitle()
    {
        if var notificationPeriodArray = NotificationEditorState.notificationPeriodArray
        {
            var notificationPeriodIntArray = Array<Int>()
            
            var i = 0
            while i < notificationPeriodArray.count
            {
                notificationPeriodIntArray.append(notificationPeriodArray[i] ? i : -1)
                i += 1
            }
            
            let convertedNotificationPeriodArray = notificationPeriodIntArray.filter { (period) -> Bool in
                    return period != -1
                }.map { (period) -> String in
                    return String(period+1)
            }
            
            var outputString = "Period" + (convertedNotificationPeriodArray.count > 1 ? "s " : " ")
            for period in convertedNotificationPeriodArray
            {
                outputString += period + (convertedNotificationPeriodArray.firstIndex(of: period) == convertedNotificationPeriodArray.count-1 ? "" : ", ")
            }
            
            periodButton.setTitle(outputString, for: UIControl.State.normal)
        }
    }
    
    @objc func setTimeButtonTitle()
    {
        if NotificationEditorState.displayTimeAsOffset ?? true
        {
            timeButton.setTitle(String(abs(NotificationEditorState.notificationTimeOffset ?? 0)) + " minutes", for: UIControl.State.normal)
        }
        else
        {
            timeButton.setTitle(get12HourTime(hour: NotificationEditorState.notificationTimeHour ?? 0, minute: NotificationEditorState.notificationTimeMinute ?? 0), for: UIControl.State.normal)
        }
    }
    
    func get12HourTime(hour: Int, minute: Int) -> String
    {
        let hourString = (hour == 0 ? "12" : (hour > 12 ? String(hour-12) : String(hour)))
        let minuteString = (minute < 10 ? "0" : "") + String(minute)
        let AMPMString = (hour == 12 ? "PM" : (hour > 12 ? "PM" : "AM"))
        
        return hourString + ":" + minuteString + " " + AMPMString
    }
    
    @objc func setBeforeAfterStartEndButtonTitle()
    {
        beforeAfterStartEndPeriodButton.setTitle((NotificationEditorState.notificationTimeOffset ?? 0 < 0 ? "Before" : "After") + " the " + (NotificationEditorState.shouldFireWhenPeriodStarts ?? true ? "start" : "end") + " of the period", for: .normal)
    }
    
    @objc func setFireDayBeforeButtonTitle()
    {
        dayBeforeButton.setTitle("Fire on the day " + (NotificationEditorState.shouldFireDayBefore ?? false ? "before" : "of"), for: UIControl.State.normal)
    }
    
    @objc func setScheduleButtonTitle()
    {
        schedulesButton.setTitle("Fire on" + (NotificationEditorState.schedulesToFireOn.map({ (scheduleDictionary) -> Bool in
            for scheduleCode in scheduleDictionary
            {
                if !scheduleCode.value
                {
                    return false
                }
            }
            return true
        }) ?? true ? " all schedule codes" : (NotificationEditorState.schedulesToFireOn.map({ (scheduleDictionary) -> String in
            var scheduleCodesString = " "
            var keyArray = scheduleDictionary.keys.sorted()
            if keyArray.count > 0 && keyArray[0] == "+"
            {
                keyArray.remove(at: 0)
                keyArray.append("+")
            }
            
            for scheduleCode in keyArray
            {
                scheduleCodesString += (scheduleDictionary[scheduleCode] ?? false ? scheduleCode + ", " : "")
            }
            scheduleCodesString = String(scheduleCodesString.dropLast().dropLast())
            return scheduleCodesString
        }) ?? "")), for: UIControl.State.normal)
    }
    
    func getSchoolNotification(_ schoolNotificationArgument: SchoolNotification? = nil) -> SchoolNotification?
    {
        var schoolNotification: SchoolNotification?
        if schoolNotificationArgument == nil, schoolNotificationUUID != nil, let schoolNotificationTmp = CoreDataStack.fetchLocalObjects(type: "SchoolNotification", predicate: NSPredicate(format: "uuid == %@", schoolNotificationUUID!))?.first as? SchoolNotification
        {
            schoolNotification = schoolNotificationTmp
        }
        
        return schoolNotification
    }
    
    @objc func setEnabledButtons()
    {
        beforeAfterStartEndPeriodButton.isEnabled = (NotificationEditorState.displayTimeAsOffset ?? true)
        dayBeforeButton.isEnabled = !(NotificationEditorState.displayTimeAsOffset ?? true)
    }
    
    @objc func disableEditorDoneButton()
    {
        editorViewDoneButton.isEnabled = false
        barDoneButton.isEnabled = false
    }
    
    @objc func enableEditorDoneButton()
    {
        editorViewDoneButton.isEnabled = true
        barDoneButton.isEnabled = true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "unwindNotificationEditor"
        {
            if let schoolNotification = getSchoolNotification()
            {
                schoolNotification.displayTimeAsOffset = NotificationEditorState.displayTimeAsOffset ?? true
                schoolNotification.notificationPeriodArray = try? JSONSerialization.data(withJSONObject: NotificationEditorState.notificationPeriodArray ?? Array<Bool>(), options: JSONSerialization.WritingOptions.prettyPrinted)
                schoolNotification.notificationTimeHour = Int64(NotificationEditorState.notificationTimeHour ?? 0)
                schoolNotification.notificationTimeMinute = Int64(NotificationEditorState.notificationTimeMinute ?? 0)
                schoolNotification.notificationTimeOffset = Int64(NotificationEditorState.notificationTimeOffset ?? 0)
                schoolNotification.shouldFireDayBefore = NotificationEditorState.shouldFireDayBefore ?? false
                schoolNotification.shouldFireWhenPeriodStarts = NotificationEditorState.shouldFireWhenPeriodStarts ?? true
                schoolNotification.schedulesToFireOn = try? JSONSerialization.data(withJSONObject: NotificationEditorState.schedulesToFireOn ?? ["N":true, "M":true, "R":true, "S":true, "+":true], options: JSONSerialization.WritingOptions.prettyPrinted)
                
                CoreDataStack.saveContext()
            }
            
            NotificationEditorState.editorViewType = .none
        }
    }
}
