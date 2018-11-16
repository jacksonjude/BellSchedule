//
//  NotificationCheckboxViewController.swift
//  Schedule
//
//  Created by jackson on 11/6/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class NotificationCheckboxViewController: UIViewController
{
    @IBOutlet weak var checkboxStackView: UIStackView!
    
    var stackViewTitles = Array<String>()
    var stackViewChecked = Array<Bool>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadStackView()
                
        NotificationCenter.default.addObserver(self, selector: #selector(reloadStackView), name: NSNotification.Name("ReloadCheckboxView"), object: nil)
    }
    
    @objc func reloadStackView()
    {
        stackViewTitles = Array<String>()
        
        let removedSubviews = checkboxStackView.arrangedSubviews.reduce([]) { (allSubviews, subview) -> [UIView] in
            checkboxStackView.removeArrangedSubview(subview)
            return allSubviews + [subview]
        }
        NSLayoutConstraint.deactivate(removedSubviews.flatMap({ $0.constraints }))
        removedSubviews.forEach({ $0.removeFromSuperview() })
        
        switch NotificationEditorState.editorViewType
        {
        case .period:
            var i = 0
            while i < 8
            {
                stackViewTitles.append(String(i+1))
                i+=1
            }
            stackViewChecked = NotificationEditorState.notificationPeriodArray ?? stackViewChecked
        case .schedules:
            var scheduleCodes: Array<String> = ["N", "M", "R", "S", "+"]
            if let scheduleCodesData = UserDefaults.standard.object(forKey: "") as? Data, let scheduleCodesTmp = try? JSONSerialization.jsonObject(with: scheduleCodesData, options: JSONSerialization.ReadingOptions.allowFragments) as? Array<String>
            {
                scheduleCodes = scheduleCodesTmp ?? ["N", "M", "R", "S", "+"]
            }
            stackViewTitles = scheduleCodes
            
            var i = 0
            while i < stackViewTitles.count
            {
                stackViewChecked.append(false)
                i+=1
            }
            
            if let schedulesToFireOn = NotificationEditorState.schedulesToFireOn
            {
                schedulesToFireOn.forEach { (arg0) in
                    let (key, value) = arg0
                    if let index = scheduleCodes.firstIndex(of: key)
                    {
                        stackViewChecked[index] = value
                    }
                }
            }
        default:
            break
        }
        
        for stackViewTitle in stackViewTitles
        {
            let newButton = UIButton(type: .system)
            newButton.setTitle(stackViewTitle, for: .normal)
            newButton.backgroundColor = UIColor(white: stackViewChecked[stackViewTitles.index(of: stackViewTitle) ?? 0] ? 0.7 : 0.9, alpha: 1)
            newButton.addCorners()
            newButton.addConstraint(NSLayoutConstraint(item: newButton, attribute: .height, relatedBy: .equal, toItem: newButton, attribute: .width, multiplier: 1, constant: 0))
            newButton.tag = 200 + (stackViewTitles.index(of: stackViewTitle) ?? 0)
            newButton.addTarget(self, action: #selector(checkboxButtonPressed(_:)), for: UIControl.Event.touchUpInside)
            checkboxStackView.addArrangedSubview(newButton)
        }
    }
    
    @IBAction func checkboxButtonPressed(_ sender: Any)
    {
        let button = sender as! UIButton
        
        var trueAmount = 0
        for checkbox in stackViewChecked
        {
            trueAmount += checkbox ? 1 : 0
        }
        
        if trueAmount <= 1 && stackViewChecked[button.tag - 200]
        {
            return
        }
        
        stackViewChecked[button.tag - 200] = !stackViewChecked[button.tag - 200]
        button.backgroundColor = UIColor(white: stackViewChecked[button.tag - 200] ? 0.7: 0.9, alpha: 1)
        
        switch NotificationEditorState.editorViewType
        {
        case .period:
            NotificationEditorState.notificationPeriodArray = stackViewChecked
            NotificationCenter.default.post(name: NSNotification.Name("SetPeriodButtonTitle"), object: nil)
        case .schedules:
            var scheduleCodeDictionary = Dictionary<String,Bool>()
            for checkedSchedule in stackViewTitles
            {
                scheduleCodeDictionary[checkedSchedule] = stackViewChecked[stackViewTitles.firstIndex(of: checkedSchedule) ?? 0]
            }
            NotificationEditorState.schedulesToFireOn = scheduleCodeDictionary
            NotificationCenter.default.post(name: NSNotification.Name("SetScheduleButtonTitle"), object: nil)
        default:
            break
        }
        
    }
}
