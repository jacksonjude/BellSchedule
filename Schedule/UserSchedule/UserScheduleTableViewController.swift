//
//  UserScheduleTableViewController.swift
//  Schedule
//
//  Created by jackson on 10/10/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CloudKit

class UserScheduleTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var periodNames: Array<String> = []
    var uploadData = false
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.println(" USRV: Loading UserSchedule...")
        
        tableView.addCorners()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if UserDefaults.standard.object(forKey: "userID") == nil
        {
            showUserIDAlert()
        }
    }
    
    func showUserIDAlert()
    {
        let userIDAlert = UIAlertController(title: "Set UserID", message: "Enter a UserID to load or create a new user schedule", preferredStyle: .alert)
        
        userIDAlert.addTextField { (textFeild) in
            textFeild.placeholder = (UserDefaults.standard.object(forKey: "userID") as? String) ?? "UserID"
        }
        
        userIDAlert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (alert) in
            self.performSegue(withIdentifier: "exitUserSchedule", sender: self)
        }))
        
        userIDAlert.addAction(UIAlertAction(title: "Set", style: .default, handler: { (alert) in
            let userID = userIDAlert.textFields![0].text
            if userID != nil && userID != ""
            {
                UserDefaults.standard.set(userID, forKey: "userID")
                Logger.println(" USRID: Set userID: " + userID!)
                self.getUserID()
            }
            else
            {
                self.performSegue(withIdentifier: "exitUserSchedule", sender: self)
            }
        }))
        
        self.present(userIDAlert, animated: true) {
            
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return periodNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserPeriodCell", for: indexPath)
        cell.textLabel?.text = "Period " + String(indexPath.row + 1) + ": " + periodNames[indexPath.row]
        return cell
    }
    
    override func viewWillAppear(_ animated: Bool) {
        getUserID()
    }
    
    func getUserID()
    {
        Logger.println(" USRID: Fetching userID")
        if let userID = UserDefaults.standard.object(forKey: "userID") as? String
        {
            Logger.println(" USRID: userID: " + userID)
            queryUserSchedule(userID: userID)
        }
        else
        {
            Logger.println(" USRID: No userID")
        }
    }
    
    func queryUserSchedule(userID: String)
    {
        Logger.println(" USRSCH: Fetching periodNamesRecord")
        let userScheduleReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveUserSchedule(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + userScheduleReturnID), object: nil)
        
        let userScheduleQueryPredicate = NSPredicate(format: "userID == %@", userID)
        CloudManager.fetchPublicDatabaseObject(type: "UserSchedule", predicate: userScheduleQueryPredicate, returnID: userScheduleReturnID)
    }
    
    @objc func receiveUserSchedule(notification: NSNotification)
    {
        if let periodNamesRecord = notification.object as? CKRecord
        {
            Logger.println(" USRSCH: Received periodNamesRecord")
            if periodNamesRecord.object(forKey: "periodNames") as? [String] != nil
            {
                periodNames = periodNamesRecord.object(forKey: "periodNames") as! [String]
            }
            else
            {
                periodNames = ["", "", "", "", "", "", "", "", "Registry"]
            }
        }
        else
        {
            Logger.println(" USRSCH: Did not receive periodNamesRecord")
            
            periodNames = ["", "", "", "", "", "", "", "", "Registry"]
        }
        
        OperationQueue.main.addOperation {
            self.tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userPeriodChangeAlert = UIAlertController(title: "Period Name Change", message: "Edit the name of the period", preferredStyle: .alert)
        
        userPeriodChangeAlert.addTextField { (textFeild) in
            textFeild.text = self.periodNames[indexPath.row]
        }
        
        userPeriodChangeAlert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { (alert) in
            
        }))
        
        userPeriodChangeAlert.addAction(UIAlertAction(title: "Set", style: .default, handler: { (alert) in
            let periodName = userPeriodChangeAlert.textFields![0].text
            if periodName != nil || periodName != ""
            {
                self.periodNames[indexPath.row] = periodName!
                
                OperationQueue.main.addOperation {
                    self.tableView.deselectRow(at: indexPath, animated: true)
                    self.tableView.reloadData()
                }
            }
        }))
        
        self.present(userPeriodChangeAlert, animated: true) {
            
        }
    }
    
    @IBAction func performUnwind(_ sender: Any) {
        let barButtonItem = sender as! UIBarButtonItem
        if barButtonItem.tag == 618
        {
            uploadData = true
        }
        performSegue(withIdentifier: "exitUserSchedule", sender: self)
    }
}
