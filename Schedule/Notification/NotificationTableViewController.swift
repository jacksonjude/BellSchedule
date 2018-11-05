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
    var schoolNotifications: Array<Array<SchoolNotification>>?
    @IBOutlet weak var schoolNotificationsTableView: UITableView!
    
    override func viewDidLoad() {
        if let schoolNotifications = CoreDataStack.fetchLocalObjects(type: "SchoolNotification", predicate: NSPredicate(value: true)) as? Array<SchoolNotification>
        {
            self.schoolNotifications = Array<Array<SchoolNotification>>()
            self.schoolNotifications?.insert(schoolNotifications.filter({ (schoolNotificationTmp) -> Bool in
                return schoolNotificationTmp.isEnabled
            }), at: 0)
            self.schoolNotifications?.insert(schoolNotifications.filter({ (schoolNotificationTmp) -> Bool in
                return !schoolNotificationTmp.isEnabled
            }), at: 1)
            schoolNotificationsTableView.reloadData()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section
        {
        case 0:
            return self.schoolNotifications?[0].count ?? 0
        case 1:
            return self.schoolNotifications?[1].count ?? 0
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SchoolNotificationCell", for: indexPath)
        
        self.configureCell(cell, indexPath)
        
        return cell
    }
    
    func configureCell(_ cell: UITableViewCell, _ indexPath: IndexPath)
    {
        let schoolNotification = schoolNotifications![indexPath.section][indexPath.row]
        
        (cell.viewWithTag(600) as! UILabel).text = "Period " + String(schoolNotification.notificationPeriod)
        (cell.viewWithTag(601) as! UILabel).text = (schoolNotification.displayTimeAsOffset ? String(abs(schoolNotification.notificationTimeOffset )) + " min" : get12HourTime(hour: schoolNotification.notificationTimeHour, minute: schoolNotification.notificationTimeMinute))
        (cell.viewWithTag(602) as! UILabel).text = (schoolNotification.shouldFireDayBefore ? ("The day before") : (schoolNotification.displayTimeAsOffset ? (schoolNotification.notificationTimeOffset < 0 ? "Before" : "After") + " the period " + (schoolNotification.shouldFireWhenPeriodStarts ? "starts" : "ends") : "The day of"))
        (cell.viewWithTag(603) as! UILabel).text = schoolNotification.isEnabled ? "Enabled" : "Disabled"
        (cell.viewWithTag(603) as! UILabel).textColor = schoolNotification.isEnabled ? UIColor(red: 0, green: 0.5, blue: 0, alpha: 1) : UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
        
        //cell.backgroundColor = schoolNotification?.isEnabled ?? true ? UIColor.white : UIColor(white: 0.8, alpha: 1)
        
        cell.layoutSubviews()
    }
    
    func get12HourTime(hour: Int64, minute: Int64) -> String
    {
        let hourString = (hour == 0 ? "12" : (hour > 12 ? String(hour-12) : String(hour)))
        let minuteString = (minute < 10 ? "0" : "") + String(minute)
        let AMPMString = (hour == 12 ? "PM" : (hour > 12 ? "PM" : "AM"))
                
        return hourString + ":" + minuteString + " " + AMPMString
    }
    
    var selectedNotificationRowIndex: IndexPath?
    var schoolNotificationUUID: String?
    
    @IBAction func addSchoolNotification(_ sender: Any)
    {
        let schoolNotification = NSEntityDescription.insertNewObject(forEntityName: "SchoolNotification", into: CoreDataStack.persistentContainer.viewContext) as! SchoolNotification
        schoolNotification.notificationPeriod = 1
        schoolNotification.notificationTimeHour = 21
        schoolNotification.notificationTimeMinute = 0
        schoolNotification.shouldFireWhenPeriodStarts = true
        schoolNotification.isEnabled = true
        schoolNotification.uuid = UUID().uuidString
        
        schoolNotificationUUID = schoolNotification.uuid
        
        CoreDataStack.saveContext()
        
        schoolNotifications![0].append(schoolNotification)
        schoolNotificationsTableView.insertRows(at: [IndexPath(row: (schoolNotifications?.count ?? 0)-1, section: 0)], with: .fade)
        
        self.performSegue(withIdentifier: "openNotificationEditor", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        if segue.identifier == "openNotificationEditor"
        {
            let destination = segue.destination as! NotificationEditorViewController
            destination.schoolNotificationUUID = schoolNotificationUUID
        }
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        schoolNotificationUUID = schoolNotifications![indexPath.section][indexPath.row].uuid
        selectedNotificationRowIndex = indexPath
        
        return indexPath
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]?
    {
        let schoolNotification = schoolNotifications![indexPath.section][indexPath.row]
        
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
            CoreDataStack.persistentContainer.viewContext.delete(schoolNotification)
            self.schoolNotifications?.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
        
        let enableDisable = UITableViewRowAction(style: .default, title: schoolNotification.isEnabled ? "Disable" : "Enable") { (action, indexPath) in
            schoolNotification.isEnabled = !schoolNotification.isEnabled
            self.schoolNotifications?[schoolNotification.isEnabled ? 1 : 0].remove(at: indexPath.row)
            self.schoolNotifications?[schoolNotification.isEnabled ? 0 : 1].insert(schoolNotification, at: 0)
            
            CoreDataStack.saveContext()
            
            let newIndexPath: IndexPath?
            if schoolNotification.isEnabled
            {
                newIndexPath = IndexPath(row: 0, section: 0)
            }
            else
            {
                newIndexPath = IndexPath(row: 0, section: 1)
            }
            
            tableView.moveRow(at: indexPath, to: newIndexPath!)
            
            self.configureCell(tableView.cellForRow(at: newIndexPath!)!, newIndexPath!)
        }
        
        enableDisable.backgroundColor = schoolNotification.isEnabled ? UIColor.lightGray : UIColor(red: 0, green: 0.5, blue: 1, alpha: 1)
        
        
        return [delete, enableDisable]
    }
    
    @IBAction func exitNotificationEditorView(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting NotificationEditorView...")
        
        if selectedNotificationRowIndex != nil
        {
            schoolNotificationsTableView.reloadRows(at: [selectedNotificationRowIndex!], with: .fade)
        }
    }
}
