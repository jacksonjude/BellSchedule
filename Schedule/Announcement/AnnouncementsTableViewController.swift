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
    var announcementTitles: Array<String>?
    @IBOutlet weak var tableView: UITableView!
    var announcementManager: AnnouncementManager?
    var selectedRow = 0
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return announcementTitles?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AnnoucementCell", for: indexPath)
        cell.textLabel?.text = announcementTitles?[indexPath.row]
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
            
            //Find the selected post date
            let selectedAnnouncementPostDate = String(announcementTitles![selectedRow].split(separator: ":")[0])
            
            //Get the recordUUID from the announcementID array using the post date
            announcementManager?.fetchAnnouncementRecord(recordUUID: (announcementManager?.announcementIDs[selectedAnnouncementPostDate])!)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.println("Loading AnnouncementsTableView...")
        
        tableView.addCorners()
        
        announcementManager = AnnouncementManager(viewController: self)
    }
    
    @IBAction func exitAnnouncementView(_ segue: UIStoryboardSegue)
    {
        Logger.println("Exiting AnnouncementView...")
    }
}
