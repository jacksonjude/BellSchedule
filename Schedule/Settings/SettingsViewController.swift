//
//  SettingsViewController.swift
//  Schedule
//
//  Created by jackson on 1/31/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import Foundation
import UIKit

class SettingsViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate
{
    @IBOutlet weak var userIDLabel: UILabel!
    @IBOutlet weak var syncLabel: UILabel!
    @IBOutlet weak var backgroundLabel: UILabel!
    @IBOutlet weak var alertTimeLabel: UILabel!
    
    @IBOutlet weak var userIDTextField: UITextField!
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var backgroundButton: UIButton!
    @IBOutlet weak var alertTimeButton: UIButton!
    
    @IBOutlet weak var settingsPickerView: UIPickerView!
    @IBOutlet weak var settingsPickerViewDoneButton: UIButton!
    
    let kNone = 0
    let kAlertTimeValue = 1
    let kBackgroundValue = 2
    
    var selectedPickerValue = 0
    var currentPickerArray: Array<Array<String>> = []
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return currentPickerArray.count
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return currentPickerArray[component].count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return currentPickerArray[component][row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch selectedPickerValue
        {
        case kAlertTimeValue:
            let hour = currentPickerArray[0][pickerView.selectedRow(inComponent: 0)]
            let minute = currentPickerArray[1][pickerView.selectedRow(inComponent: 1)]
            let ampm = currentPickerArray[2][pickerView.selectedRow(inComponent: 2)]
            
            let alertTimeString = hour + ":" + minute + " " + ampm
            
            alertTimeButton.setTitle(alertTimeString, for: UIControl.State.normal)
        case kBackgroundValue:
            let backgroundName = currentPickerArray[0][pickerView.selectedRow(inComponent: 0)]
            
            backgroundButton.setTitle(backgroundName, for: UIControl.State.normal)
        default:
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userIDLabel.addCorners(5)
        syncLabel.addCorners(5)
        backgroundLabel.addCorners(5)
        alertTimeLabel.addCorners(5)
        
        syncButton.addCorners()
        backgroundButton.addCorners()
        alertTimeButton.addCorners()
        
        settingsPickerView.addCorners()
        
        settingsPickerViewDoneButton.addCorners()
        
        userIDTextField.delegate = self
        userIDTextField.returnKeyType = .done
        
        settingsPickerView.delegate = self
        
        self.view.setBackground()
        
        let backgroundName = "Background " + (String(describing: (UserDefaults.standard.object(forKey: "backgroundName") as? String ?? "background1").last!))
        backgroundButton.setTitle(backgroundName, for: UIControl.State.normal)
        
        let notification24Time = UserDefaults.standard.object(forKey: "notificationAlertTime") as? String ?? "21:00"
        var notificationHour = String(notification24Time.split(separator: ":")[0])
        let notificationMinute = String(notification24Time.split(separator: ":")[1])
        var notificationAMPM = "AM"
        
        if Int(notificationHour) ?? 21 > 12
        {
            notificationHour = String((Int(notificationHour) ?? 21) - 12)
            
            notificationAMPM = "PM"
        }
        alertTimeButton.setTitle(notificationHour + ":" + notificationMinute + " " + notificationAMPM, for: UIControl.State.normal)
        
        userIDTextField.placeholder = (UserDefaults.standard.object(forKey: "userID") as? String ?? "")
        
        syncButton.setTitle(String((UserDefaults.standard.object(forKey: "syncData") as? Bool) ?? true), for: UIControl.State.normal)
        
        Logger.println(" SETV: Opening SettingsViewController...")
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if userIDTextField.text != nil && userIDTextField.text != ""
        {
            Logger.println(" SETV: Set userID!")
            UserDefaults.standard.set(userIDTextField.text, forKey: "userID")
            
            userIDTextField.placeholder = userIDTextField.text
            userIDTextField.text = ""
        }
        
        return false
    }
    
    @IBAction func alertTimeButtonPressed()
    {
        selectedPickerValue = kAlertTimeValue
        
        var alertTimeValues: Array<Array<String>> = [["12"], [], ["AM", "PM"]]
        
        var hourOn = 1
        while hourOn <= 11
        {
            alertTimeValues[0].append(String(hourOn))
            hourOn += 1
        }
        
        var minuteOn = 0
        while minuteOn <= 59
        {
            alertTimeValues[1].append(String(format: "%02d", minuteOn))
            minuteOn += 1
        }
        
        currentPickerArray = alertTimeValues
        self.reloadPickerView()
        
        settingsPickerView.isHidden = false
        settingsPickerViewDoneButton.isHidden = false
        
        Logger.println(" SETV: Opened picker for alert time")
    }
    
    @IBAction func backgroundButtonPressed()
    {
        selectedPickerValue = kBackgroundValue
        
        let backgroundNumbers = [["Background 1", "Background 2", "Background 3", "Background 4"]]
        
        currentPickerArray = backgroundNumbers
        self.reloadPickerView()
        
        settingsPickerView.isHidden = false
        settingsPickerViewDoneButton.isHidden = false
        
        Logger.println(" SETV: Opened picker for background")
    }
    
    @IBAction func closePickerView()
    {
        settingsPickerView.isHidden = true
        settingsPickerViewDoneButton.isHidden = true
        
        switch selectedPickerValue
        {
        case kAlertTimeValue:
            var hour = currentPickerArray[0][settingsPickerView.selectedRow(inComponent: 0)]
            let minute = currentPickerArray[1][settingsPickerView.selectedRow(inComponent: 1)]
            let ampm = currentPickerArray[2][settingsPickerView.selectedRow(inComponent: 2)]
            
            if ampm == "PM"
            {
                hour = String((Int(hour) ?? 21) + 12)
            }
            
            UserDefaults.standard.set(String(hour) + ":" + String(minute), forKey: "notificationAlertTime")
            
            Logger.println(" SETV: Set Alert Time!")
        case kBackgroundValue:
            let backgroundNameLocal = "background" + String(currentPickerArray[0][settingsPickerView.selectedRow(inComponent: 0)].last!)
            
            UserDefaults.standard.set(backgroundNameLocal, forKey: "backgroundName")
            
            backgroundName = backgroundNameLocal
            
            self.view.setBackground()
            
            Logger.println(" SETV: Set Background!")
        default:
            break
        }
        
        currentPickerArray = []
        
        settingsPickerView.reloadAllComponents()
        
        Logger.println(" SETV: Closed picker")
    }
    
    func reloadPickerView()
    {
        settingsPickerView.reloadAllComponents()
        
        switch selectedPickerValue
        {
        case kAlertTimeValue:
            let notification24Time = UserDefaults.standard.object(forKey: "notificationAlertTime") as? String ?? "21:00"
            var notificationHour = String(notification24Time.split(separator: ":")[0])
            let notificationMinute = String(notification24Time.split(separator: ":")[1])
            var notificationAMPM = "AM"
            
            if Int(notificationHour) ?? 21 > 12
            {
                notificationHour = String((Int(notificationHour) ?? 21) - 12)
                
                notificationAMPM = "PM"
            }
                        
            settingsPickerView.selectRow(currentPickerArray[0].index(of: notificationHour) ?? 0, inComponent: 0, animated: false)
            settingsPickerView.selectRow(currentPickerArray[1].index(of: notificationMinute) ?? 0, inComponent: 1, animated: false)
            settingsPickerView.selectRow(currentPickerArray[2].index(of: notificationAMPM) ?? 0, inComponent: 2, animated: false)
        case kBackgroundValue:
            let backgroundName = "Background " + (String(describing: (UserDefaults.standard.object(forKey: "backgroundName") as? String ?? "background1").last!))
            settingsPickerView.selectRow(currentPickerArray[0].index(of: backgroundName) ?? 0, inComponent: 0, animated: false)
        default:
            break
        }
    }
    
    @IBAction func toggleSync(_ sender: Any) {
        UserDefaults.standard.set(!((UserDefaults.standard.object(forKey: "syncData") as? Bool) ?? true), forKey: "syncData")
        syncButton.setTitle(String((UserDefaults.standard.object(forKey: "syncData") as? Bool) ?? true), for: UIControl.State.normal)
    }
}
