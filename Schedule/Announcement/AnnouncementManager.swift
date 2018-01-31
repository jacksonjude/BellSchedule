//
//  AnnouncementManager.swift
//  Schedule
//
//  Created by jackson on 12/21/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CoreData
import CloudKit

class AnnouncementManager: NSObject, NSFetchedResultsControllerDelegate
{
    var announcementsTableViewController: AnnouncementsTableViewController
    var announcementViewController: AnnouncementViewController?
    
    var announcementFetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>?
    
    init(viewController: AnnouncementsTableViewController)
    {
        announcementsTableViewController = viewController
        super.init()
        
        let announcementFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Announcement")
        let announcementSortDescriptor = NSSortDescriptor(key: "postDate", ascending: false)
        announcementFetchRequest.sortDescriptors = [announcementSortDescriptor]
        
        announcementFetchedResultsController = NSFetchedResultsController(fetchRequest: announcementFetchRequest, managedObjectContext: CoreDataStack.persistentContainer.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        announcementFetchedResultsController!.delegate = self
        
        do {
            try announcementFetchedResultsController?.performFetch()
        }
        catch {
            Logger.println("Failed to fetch announcements")
        }        
    }
    
    func fetchAnnouncementTitles()
    {
        for fetchedAnnouncement in announcementFetchedResultsController?.fetchedObjects ?? []
        {
            let announcement = fetchedAnnouncement as! NSManagedObject
            announcementsTableViewController.announcementTitles.append((announcement.value(forKey: "title") as? String) ?? "")
            announcementsTableViewController.announcementDates.append((announcement.value(forKey: "postDate") as? Date) ?? Date())
        }
        
        OperationQueue.main.addOperation {
            self.announcementsTableViewController.tableView.reloadData()
        }
    }
    
    func setAnnouncementRecord(selectedRow: Int)
    {
        announcementViewController?.announcementRecord = announcementFetchedResultsController?.fetchedObjects![selectedRow] as? NSManagedObject
        announcementViewController?.loadDataFromRecord()
    }
}
