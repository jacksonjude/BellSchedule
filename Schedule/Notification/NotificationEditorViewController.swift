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
    @IBOutlet weak var blockButton: UIButton!
    @IBOutlet weak var timeButton: UIButton!
    @IBOutlet weak var beforeAfterStartEndPeriodButton: UIButton!
    @IBOutlet weak var dayBeforeButton: UIButton!
    @IBOutlet weak var pickerViewDoneButton: UIButton!
    @IBOutlet weak var notificationPickerView: UIPickerView!
    @IBOutlet weak var pickerViewBottomConstraint: NSLayoutConstraint!
    
    var schoolNotificationUUID: String?
    var dayBefore: Bool?
    
    var pickerViewData: Array<Array<String>>?
    
    enum NotificationPickerViewType
    {
        case none
        case block
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
            self.notificationPickerView.isHidden = false
            self.pickerViewDoneButton.isHidden = false
            self.pickerViewDoneButton.isEnabled = true
            
            self.pickerViewBottomConstraint.constant = -16
            self.view.layoutIfNeeded()
        }
    }
    
    func loadPickerView()
    {
        switch pickerViewType
        {
        case .none:
            break
        case .block:
            pickerViewData = [[]]
            var i = 0
            while (i < 8)
            {
                pickerViewData?[0].append(String(i+1))
                i+=1
            }
        case .time:
            pickerViewData = [[], [], ["AM", "PM"], [""]]
            
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
        case .beforeAfterStartEnd:
            pickerViewData = [["Before", "After"], ["Start", "End"]]
        }
    }
    
    @IBAction func blockButtonPressed(_ sender: Any) {
        loadPickerView()
    }
    
    @IBAction func timeButtonPressed(_ sender: Any) {
        loadPickerView()
    }
    
    @IBAction func beforeAfterStartEndPeriodButtonPressed(_ sender: Any) {
        loadPickerView()
    }
    
    @IBAction func dayBeforeButtonPressed(_ sender: Any) {
        dayBefore = !(dayBefore ?? false)
    }
    
    @IBAction func pickerViewDoneButtonPressed(_ sender: Any) {
        hidePickerView()
    }
}
