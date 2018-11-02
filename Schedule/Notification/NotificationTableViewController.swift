//
//  NotificationTableViewController.swift
//  Schedule
//
//  Created by jackson on 10/31/18.
//  Copyright © 2018 jackson. All rights reserved.
//

import UIKit
import CoreData

class NotificationTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var schoolNotifications: Array<SchoolNotification>?
    
    override func viewDidLoad() {
        if let schoolNotifications = CoreDataStack.fetchLocalObjects(type: "SchoolNotification", predicate: NSPredicate(value: true)) as? Array<SchoolNotification>
        {
            self.schoolNotifications = schoolNotifications
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.schoolNotifications?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SchoolNotificationCell", for: indexPath)
        
        (cell.viewWithTag(600) as! UILabel).text = String(schoolNotifications?[indexPath.row].notificationPeriod ?? 0)
        
        return cell
    }
    
    @IBAction func addSchoolNotification(_ sender: Any)
    {
        let schoolNotification = NSEntityDescription.insertNewObject(forEntityName: "SchoolNotification", into: CoreDataStack.persistentContainer.viewContext) as! SchoolNotification
        schoolNotification.notificationPeriod = 1
        schoolNotification.notificationTimeHour = 21
        schoolNotification.notificationTimeMinute = 0
        schoolNotification.shouldFireWhenPeriodStarts = true
        schoolNotification.uuid = UUID().uuidString
        
        
    }
    
    @IBAction func exitNotificationEditorView(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting NotificationEditorView...")
    }
}
