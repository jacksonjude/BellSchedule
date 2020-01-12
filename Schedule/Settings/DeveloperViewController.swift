//
//  DeveloperViewController.swift
//  Schedule
//
//  Created by jackson on 10/16/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import CloudKit

class DeveloperViewController: UIViewController
{
    @IBOutlet weak var logTextView: UITextView!
    @IBOutlet weak var clearLogButton: UIButton!
    @IBOutlet weak var clearCoreDataButton: UIButton!
    @IBOutlet weak var clearUserScheduleButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        logTextView.addCorners()
        clearCoreDataButton.addCorners()
        clearLogButton.addCorners()
        clearUserScheduleButton.addCorners()
        
        setLogText()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setLogText), name: Notification.Name(rawValue: "loggerChangedData"), object: nil)
        
        Logger.println("Loading Developer View...")
        
        self.view.setBackground()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func setLogText()
    {
        OperationQueue.main.addOperation {
            self.logTextView.text = Logger.printedData
        }
    }
    
    @IBAction func clearCoreData(_ sender: Any) {
        let entityTypes = ["Schedule", "WeekSchedules", "Announcement"]
        
        for entityType in entityTypes
        {
            if let objects = CoreDataStack.fetchLocalObjects(type: entityType, predicate: NSPredicate(format: "TRUEPREDICATE")) as? [NSManagedObject]
            {
                for object in objects
                {
                    CoreDataStack.persistentContainer.viewContext.delete(object)
                }
                
                Logger.println("Deleted " + String(objects.count) + " " + entityType)
            }
            else
            {
                Logger.println("Deleted 0 " + entityType)
            }
        }
        
        CoreDataStack.saveContext()
        
        UserDefaults.standard.set(nil, forKey: "lastUpdatedData")
        
        appDelegate.refreshDataOnScheduleViewController = true
    }
    
    @IBAction func clearConsole(_ sender: Any) {
        Logger.printedData = ""
        setLogText()
    }
    
    @IBAction func clearUserSchedule(_ sender: Any) {
        guard let userID = ScheduleInfoManager.getUserID() else { return }
        let defaultUserScheduleDictionary = ["periodNames":["Period 1", "Period 2", "Period 3", "Period 4", "Period 5", "Period 6", "Period 7", "Period 8", "Registry"], "userID":userID, "offBlocks":[0, 0, 0, 0, 0, 0, 0, 0]] as [String : Any]
        
        CloudManager.setPublicDatabaseObject(type: "UserSchedule", dataDictionary: defaultUserScheduleDictionary, predicate: NSPredicate(format: "userID == %@", userID))
    }
}
