//
//  NotificationEditorViewController.swift
//  Schedule
//
//  Created by jackson on 10/31/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class NotificationEditorViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource
{
    @IBOutlet weak var periodButton: UIButton!
    @IBOutlet weak var timeButton: UIButton!
    @IBOutlet weak var beforeAfterStartEndPeriodButton: UIButton!
    @IBOutlet weak var dayBeforeButton: UIButton!
    @IBOutlet weak var pickerViewDoneButton: UIButton!
    @IBOutlet weak var notificationPickerView: UIPickerView!
    @IBOutlet weak var pickerViewBottomConstraint: NSLayoutConstraint!
    
    var schoolNotificationUUID: String?
    
    var pickerViewData: Array<Array<String>>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loadNotificationEditorState()
        
        periodButton.addCorners()
        timeButton.addCorners()
        beforeAfterStartEndPeriodButton.addCorners()
        dayBeforeButton.addCorners()
        pickerViewDoneButton.addCorners()
        notificationPickerView.addCorners()
        
        setPeriodButtonTitle()
        setTimeButtonTitle()
        setBeforeAfterStartEndButtonTitle()
        setFireDayBeforeButtonTitle()
        
        setEnabledButtons()
        
        self.view.setBackground()
    }
    
    func loadNotificationEditorState()
    {
        if let schoolNotification = getSchoolNotification()
        {
            NotificationEditorState.displayTimeAsOffset = schoolNotification.displayTimeAsOffset
            NotificationEditorState.notificationPeriod = Int(schoolNotification.notificationPeriod)
            NotificationEditorState.notificationTimeHour = Int(schoolNotification.notificationTimeHour)
            NotificationEditorState.notificationTimeMinute = Int(schoolNotification.notificationTimeMinute)
            NotificationEditorState.notificationTimeOffset = Int(schoolNotification.notificationTimeOffset)
            NotificationEditorState.shouldFireDayBefore = schoolNotification.shouldFireDayBefore
            NotificationEditorState.shouldFireWhenPeriodStarts = schoolNotification.shouldFireWhenPeriodStarts
        }
    }
    
    enum NotificationPickerViewType
    {
        case none
        case period
        case time
        case beforeAfterStartEnd
    }
    
    var pickerViewType: NotificationPickerViewType = .none
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return pickerViewData?.count ?? 0
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ((pickerViewData?.count ?? 0) > component) ? pickerViewData?[component].count ?? 0 : 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerViewData?[component][row]
    }
    
    func showPickerView()
    {
        pickerViewBottomConstraint.constant = notificationPickerView.frame.size.height
        notificationPickerView.isHidden = false
        pickerViewDoneButton.isHidden = false
        pickerViewDoneButton.isEnabled = true
        self.view.layoutIfNeeded()
        
        self.pickerViewBottomConstraint.constant = -16
        
        UIView.animate(withDuration: 0.5) {
            self.view.layoutIfNeeded()
        }
    }
    
    func hidePickerView()
    {
        pickerViewBottomConstraint.constant = notificationPickerView.frame.size.height
        
        UIView.animate(withDuration: 0.5, animations: {
            self.view.layoutIfNeeded()
        }) { (completed) in
            self.notificationPickerView.isHidden = true
            self.pickerViewDoneButton.isHidden = true
            self.pickerViewDoneButton.isEnabled = false
            
            self.pickerViewBottomConstraint.constant = -16
            self.view.layoutIfNeeded()
        }
    }
    
    func loadPickerView(pickerViewType: NotificationPickerViewType)
    {
        switch pickerViewType
        {
        case .none:
            break
        case .period:
            pickerViewData = [[]]
            var i = 0
            while (i < 8)
            {
                pickerViewData?[0].append(String(i+1))
                i+=1
            }
        case .time:
            if NotificationEditorState.displayTimeAsOffset ?? true
            {
                pickerViewData = [[], ["Time", "Offset"]]
                
                var minuteOn = 0
                while minuteOn <= 59
                {
                    pickerViewData?[0].append(String(format: "%01d", minuteOn))
                    minuteOn += 1
                }
            }
            else
            {
                pickerViewData = [["12"], [], ["AM", "PM"], ["Time", "Offset"]]
                
                var hourOn = 1
                while hourOn <= 11
                {
                    pickerViewData?[0].append(String(hourOn))
                    hourOn += 1
                }
                
                var minuteOn = 0
                while minuteOn <= 59
                {
                    pickerViewData?[1].append(String(format: "%02d", minuteOn))
                    minuteOn += 1
                }
            }
            
        case .beforeAfterStartEnd:
            pickerViewData = [["Before", "After"], ["Start", "End"]]
        }
        
        notificationPickerView.reloadAllComponents()
        
        if pickerViewType != .none && self.pickerViewType == .none
        {
            showPickerView()
        }
        
        switch pickerViewType
        {
        case .none:
            break
        case .period:
            notificationPickerView.selectRow(pickerViewData![0].firstIndex(of: String(NotificationEditorState.notificationPeriod ?? 0)) ?? 0, inComponent: 0, animated: true)
        case .time:
            if NotificationEditorState.displayTimeAsOffset ?? true
            {
                let notificationOffset = String(abs(NotificationEditorState.notificationTimeOffset ?? 0))
                notificationPickerView.selectRow(pickerViewData![0].index(of: notificationOffset) ?? 0, inComponent: 0, animated: true)
                notificationPickerView.selectRow(pickerViewData![1].index(of: "Offset") ?? 0, inComponent: 1, animated: false)
            }
            else
            {
                var notificationHour = String(NotificationEditorState.notificationTimeHour ?? 0)
                var notificationMinute = String(NotificationEditorState.notificationTimeMinute ?? 0)
                var notificationAMPM = "AM"
                
                if Int(notificationHour) ?? 21 > 12
                {
                    notificationHour = String((Int(notificationHour) ?? 21) - 12)
                    
                    notificationAMPM = "PM"
                }
                
                if NotificationEditorState.notificationTimeMinute ?? 0 < 10
                {
                    notificationMinute = "0" + notificationMinute
                }
                
                notificationPickerView.selectRow(pickerViewData![0].index(of: notificationHour) ?? 0, inComponent: 0, animated: true)
                notificationPickerView.selectRow(pickerViewData![1].index(of: notificationMinute) ?? 0, inComponent: 1, animated: true)
                notificationPickerView.selectRow(pickerViewData![2].index(of: notificationAMPM) ?? 0, inComponent: 2, animated: true)
                notificationPickerView.selectRow(pickerViewData![3].index(of: "Time") ?? 0, inComponent: 3, animated: false)
            }
        case .beforeAfterStartEnd:
            notificationPickerView.selectRow(pickerViewData![0].index(of: (NotificationEditorState.notificationTimeOffset ?? 0 < 0) ? "Before" : "After") ?? 0, inComponent: 0, animated: true)
            notificationPickerView.selectRow(pickerViewData![1].index(of: NotificationEditorState.shouldFireWhenPeriodStarts ?? true ? "Start" : "End") ?? 0, inComponent: 1, animated: true)
        }

        self.pickerViewType = pickerViewType
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch pickerViewType
        {
        case .none:
            break
        case .period:
            NotificationEditorState.notificationPeriod = Int(pickerViewData?[0][row] ?? "0")
            setPeriodButtonTitle()
        case .time:
            if (!(NotificationEditorState.displayTimeAsOffset ?? true) && component == 3)
            {
                NotificationEditorState.displayTimeAsOffset = (pickerViewData?[3][notificationPickerView.selectedRow(inComponent: 3)] ?? "Offset" == "Offset")
                loadPickerView(pickerViewType: .time)
                setEnabledButtons()
            }
            else if (NotificationEditorState.displayTimeAsOffset ?? true) && component == 1
            {
                NotificationEditorState.displayTimeAsOffset = (pickerViewData?[1][notificationPickerView.selectedRow(inComponent: 1)] ?? "Offset" == "Offset")
                loadPickerView(pickerViewType: .time)
                setEnabledButtons()
            }
            else if NotificationEditorState.displayTimeAsOffset ?? true
            {
                var signum = NotificationEditorState.notificationTimeOffset?.signum() ?? 0
                if signum == 0
                {
                    signum = 1
                }
                NotificationEditorState.notificationTimeOffset = Int(pickerViewData?[0][notificationPickerView.selectedRow(inComponent: 0)] ?? "0")!*signum
            }
            else
            {
                NotificationEditorState.notificationTimeHour = (Int(pickerViewData?[0][notificationPickerView.selectedRow(inComponent: 0)] ?? "0") ?? 0) + ((pickerViewData?[2][notificationPickerView.selectedRow(inComponent: 2)] ?? "PM" == "AM") ? 0 : 12)
                
                if NotificationEditorState.notificationTimeHour == 12 || NotificationEditorState.notificationTimeHour == 24
                {
                    NotificationEditorState.notificationTimeHour! -= 12
                }
                NotificationEditorState.notificationTimeMinute = Int(pickerViewData?[1][notificationPickerView.selectedRow(inComponent: 1)] ?? "0")
            }
            setTimeButtonTitle()
        case .beforeAfterStartEnd:
            NotificationEditorState.notificationTimeOffset = abs(NotificationEditorState.notificationTimeOffset ?? 0)*(pickerViewData?[0][notificationPickerView.selectedRow(inComponent: 0)] == "Before" ? -1 : 1)
            NotificationEditorState.shouldFireWhenPeriodStarts = pickerViewData?[1][notificationPickerView.selectedRow(inComponent: 1)] == "Start"
            
            setBeforeAfterStartEndButtonTitle()
        }
    }
    
    @IBAction func periodButtonPressed(_ sender: Any) {
        loadPickerView(pickerViewType: .period)
    }
    
    @IBAction func timeButtonPressed(_ sender: Any) {
        loadPickerView(pickerViewType: .time)
    }
    
    @IBAction func beforeAfterStartEndPeriodButtonPressed(_ sender: Any) {
        loadPickerView(pickerViewType: .beforeAfterStartEnd)
    }
    
    @IBAction func dayBeforeButtonPressed(_ sender: Any) {
        NotificationEditorState.shouldFireDayBefore = !(NotificationEditorState.shouldFireDayBefore ?? false)
        
        setFireDayBeforeButtonTitle()
    }
    
    @IBAction func pickerViewDoneButtonPressed(_ sender: Any) {
        pickerViewType = .none
        
        hidePickerView()
    }
    
    func setPeriodButtonTitle()
    {
        if let notificationPeriod = NotificationEditorState.notificationPeriod
        {
            periodButton.setTitle("Period " + String(notificationPeriod), for: UIControl.State.normal)
        }
    }
    
    func setTimeButtonTitle()
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
    
    func setBeforeAfterStartEndButtonTitle()
    {
        beforeAfterStartEndPeriodButton.setTitle((NotificationEditorState.notificationTimeOffset ?? 0 < 0 ? "Before" : "After") + " the " + (NotificationEditorState.shouldFireWhenPeriodStarts ?? true ? "start" : "end") + " of the period", for: .normal)
    }
    
    func setFireDayBeforeButtonTitle()
    {
        dayBeforeButton.setTitle("Fire on the day " + (NotificationEditorState.shouldFireDayBefore ?? false ? "before" : "of"), for: UIControl.State.normal)
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
    
    func setEnabledButtons()
    {
        beforeAfterStartEndPeriodButton.isEnabled = (NotificationEditorState.displayTimeAsOffset ?? true)
        dayBeforeButton.isEnabled = !(NotificationEditorState.displayTimeAsOffset ?? true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "unwindNotificationEditor"
        {
            if let schoolNotification = getSchoolNotification()
            {
                schoolNotification.displayTimeAsOffset = NotificationEditorState.displayTimeAsOffset ?? true
                schoolNotification.notificationPeriod = Int64(NotificationEditorState.notificationPeriod ?? 1)
                schoolNotification.notificationTimeHour = Int64(NotificationEditorState.notificationTimeHour ?? 0)
                schoolNotification.notificationTimeMinute = Int64(NotificationEditorState.notificationTimeMinute ?? 0)
                schoolNotification.notificationTimeOffset = Int64(NotificationEditorState.notificationTimeOffset ?? 0)
                schoolNotification.shouldFireDayBefore = NotificationEditorState.shouldFireDayBefore ?? false
                schoolNotification.shouldFireWhenPeriodStarts = NotificationEditorState.shouldFireWhenPeriodStarts ?? true
                
                CoreDataStack.saveContext()
            }
        }
    }
}
