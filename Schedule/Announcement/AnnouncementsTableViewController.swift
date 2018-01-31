//
//  AnnouncementsTableViewController.swift
//  Schedule
//
//  Created by jackson on 12/21/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class AnnouncementsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    var announcementTitles: Array<String> = []
    var announcementDates: Array<Date> = []
    @IBOutlet weak var tableView: UITableView!
    var announcementManager: AnnouncementManager?
    var selectedRow = 0
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return announcementTitles.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AnnoucementCell", for: indexPath)
        let announcementTitle = announcementTitles[indexPath.row]
        let announcementDate = announcementDates[indexPath.row]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yy"
        let formattedAnnouncementDate = dateFormatter.string(from: announcementDate) 
        
        cell.textLabel?.text = announcementTitle + " - " + formattedAnnouncementDate
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedRow = indexPath.row
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        self.performSegue(withIdentifier: "openAnnouncementView", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "openAnnouncementView"
        {
            let announcementViewController = segue.destination as! AnnouncementViewController
            
            announcementManager?.announcementViewController = announcementViewController
            
            announcementManager?.setAnnouncementRecord(selectedRow: selectedRow)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.println("Loading AnnouncementsTableView...")
        
        tableView.addCorners()
        
        announcementManager = AnnouncementManager(viewController: self)
        announcementManager?.fetchAnnouncementTitles()
        
        self.view.setBackground()
    }
    
    @IBAction func exitAnnouncementView(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting AnnouncementView...")
    }
}
