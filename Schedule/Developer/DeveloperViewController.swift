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
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        logTextView.addCorners()
        clearCoreDataButton.addCorners()
        clearLogButton.addCorners()
        
        setLogText()
        
        NotificationCenter.default.addObserver(self, selector: #selector(setLogText), name: Notification.Name(rawValue: "loggerChangedData"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func setLogText()
    {
        logTextView.text = Logger.printedData
    }
    
    @IBAction func clearCoreData(_ sender: Any) {
        let entityTypes = ["Schedule", "WeekSchedules"]
        
        for entityType in entityTypes
        {
            if let objects = CloudManager.fetchLocalObjects(type: entityType, predicate: NSPredicate(format: "TRUEPREDICATE")) as? [NSManagedObject]
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
    }
    
    @IBAction func clearConsole(_ sender: Any) {
        Logger.printedData = ""
        setLogText()
    }
}
