//
//  NotificationEditorPickerViewController.swift
//  Schedule
//
//  Created by jackson on 11/5/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class NotificationEditorPickerViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource
{
    @IBOutlet weak var notificationPickerView: UIPickerView!
    
    var pickerViewData: Array<Array<String>>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notificationPickerView.addCorners()
        
        NotificationCenter.default.addObserver(self, selector: #selector(loadPickerView), name: NSNotification.Name("ReloadPickerView"), object: nil)
    }
    
    @objc func loadPickerView()
    {
        switch NotificationEditorState.editorViewType
        {
        case .none:
            break
        case .period:
            break
            /*pickerViewData = [[]]
            var i = 0
            while (i < 8)
            {
                pickerViewData?[0].append(String(i+1))
                i+=1
            }*/
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
        case .schedules:
            break
        }
        
        notificationPickerView.reloadAllComponents()
        
        switch NotificationEditorState.editorViewType
        {
        case .none:
            break
        case .period:
            //notificationPickerView.selectRow(pickerViewData![0].firstIndex(of: String(NotificationEditorState.notificationPeriod ?? 0)) ?? 0, inComponent: 0, animated: true)
            break
        case .time:
            if NotificationEditorState.displayTimeAsOffset ?? true
            {
                let notificationOffset = String(abs(NotificationEditorState.notificationTimeOffset ?? 0))
                notificationPickerView.selectRow(pickerViewData![0].firstIndex(of: notificationOffset) ?? 0, inComponent: 0, animated: true)
                notificationPickerView.selectRow(pickerViewData![1].firstIndex(of: "Offset") ?? 0, inComponent: 1, animated: false)
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
                
                notificationPickerView.selectRow(pickerViewData![0].firstIndex(of: notificationHour) ?? 0, inComponent: 0, animated: true)
                notificationPickerView.selectRow(pickerViewData![1].firstIndex(of: notificationMinute) ?? 0, inComponent: 1, animated: true)
                notificationPickerView.selectRow(pickerViewData![2].firstIndex(of: notificationAMPM) ?? 0, inComponent: 2, animated: true)
                notificationPickerView.selectRow(pickerViewData![3].firstIndex(of: "Time") ?? 0, inComponent: 3, animated: false)
            }
        case .beforeAfterStartEnd:
            notificationPickerView.selectRow(pickerViewData![0].firstIndex(of: (NotificationEditorState.notificationTimeOffset ?? 0 < 0) ? "Before" : "After") ?? 0, inComponent: 0, animated: true)
            notificationPickerView.selectRow(pickerViewData![1].firstIndex(of: NotificationEditorState.shouldFireWhenPeriodStarts ?? true ? "Start" : "End") ?? 0, inComponent: 1, animated: true)
        case .schedules:
            break
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch NotificationEditorState.editorViewType
        {
        case .none:
            break
        case .period:
            /*NotificationEditorState.notificationPeriod = Int(pickerViewData?[0][row] ?? "0")
            postNotification("SetPeriodButtonTitle")*/
            break
        case .time:
            if !(NotificationEditorState.displayTimeAsOffset ?? true) && component == 3
            {
                NotificationEditorState.displayTimeAsOffset = (pickerViewData?[3][notificationPickerView.selectedRow(inComponent: 3)] ?? "Offset" == "Offset")
                loadPickerView()
                postNotification("SetEnabledButtons")
                
                if NotificationEditorState.displayTimeAsOffset ?? true
                {
                    NotificationEditorState.shouldFireDayBefore = false
                    postNotification("SetFireDayBeforeButtonTitle")
                }
            }
            else if (NotificationEditorState.displayTimeAsOffset ?? true) && component == 1
            {
                NotificationEditorState.displayTimeAsOffset = (pickerViewData?[1][notificationPickerView.selectedRow(inComponent: 1)] ?? "Offset" == "Offset")
                loadPickerView()
                postNotification("SetEnabledButtons")
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
            postNotification("SetTimeButtonTitle")
        case .beforeAfterStartEnd:
            NotificationEditorState.notificationTimeOffset = abs(NotificationEditorState.notificationTimeOffset ?? 0)*(pickerViewData?[0][notificationPickerView.selectedRow(inComponent: 0)] == "Before" ? -1 : 1)
            NotificationEditorState.shouldFireWhenPeriodStarts = pickerViewData?[1][notificationPickerView.selectedRow(inComponent: 1)] == "Start"
            
            postNotification("SetBeforeAfterStartEndButtonTitle")
        case .schedules:
            break
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return pickerViewData?.count ?? 0
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return ((pickerViewData?.count ?? 0) > component) ? pickerViewData?[component].count ?? 0 : 0
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerViewData?[component][row]
    }
    
    func postNotification(_ name: String)
    {
        NotificationCenter.default.post(name: NSNotification.Name(name), object: self)
    }
}
