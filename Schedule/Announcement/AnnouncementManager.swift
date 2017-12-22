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

class AnnouncementManager: NSObject
{
    var announcementsTableViewController: AnnouncementsTableViewController
    var announcementViewController: AnnouncementViewController?
    
    var announcementIDs = Dictionary<String,String>()
    
    init(viewController: AnnouncementsTableViewController)
    {
        announcementsTableViewController = viewController
        super.init()
        
        fetchAnnouncementTitles()
    }
    
    func fetchAnnouncementTitles()
    {
        CloudManager.fetchSpecificFields(entityType: "Announcement", fields: ["title", "postDate"], completionHandler: { (results) in
            self.receiveAnnouncementTitles(announcementFieldDictionary: results)
        })
    }
    
    func receiveAnnouncementTitles(announcementFieldDictionary: Dictionary<String,Array<CKRecordValue>>)
    {
        let announcementTitles = announcementFieldDictionary["title"] as! [String]
        
        let announcementPostDates = announcementFieldDictionary["postDate"] as! [Date]
        let announcementUUIDs = announcementFieldDictionary["uuid"] as! [String]
        
        for announcementUUID in announcementUUIDs
        {
            //Convert the date to a string
            let tmpAnnouncementPostDate = announcementPostDates[announcementUUIDs.index(of: announcementUUID)!]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYY-MM-dd HH:mm "
            let tmpAnnouncementPostDateString = dateFormatter.string(from: tmpAnnouncementPostDate)
            
            //Set in dictionary key -> Date, value -> UUID
            announcementIDs[tmpAnnouncementPostDateString] = announcementUUID
        }
        
        var combinedAnnouncementTitles = Array<String>()
        
        for title in announcementTitles
        {
            //Convert the date to a string
            let tmpAnnouncementPostDate = announcementPostDates[announcementTitles.index(of: title)!]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYY-MM-dd HH:mm "
            let tmpAnnouncementPostDateString = dateFormatter.string(from: tmpAnnouncementPostDate)
            
            //Add the announcement title and the date into one string
            combinedAnnouncementTitles.append(tmpAnnouncementPostDateString + "— " + title)
        }
        
        combinedAnnouncementTitles = combinedAnnouncementTitles.sorted(by: >)
        
        //Handoff the combined titles
        announcementsTableViewController.announcementTitles = combinedAnnouncementTitles
        
        OperationQueue.main.addOperation {
            self.announcementsTableViewController.tableView.reloadData()
        }
    }
    
    func fetchAnnouncementRecord(recordUUID: String)
    {
        let announcementRecordReturnID = UUID().uuidString
        NotificationCenter.default.addObserver(self, selector: #selector(receiveAnnouncementRecord(notification:)), name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + announcementRecordReturnID), object: nil)
        
        let queryRecordID = CKRecordID(recordName: recordUUID)
        
        CloudManager.fetchPublicDatabaseObject(type: "Announcement", predicate: NSPredicate(format: "recordID == %@", queryRecordID), returnID: announcementRecordReturnID)
    }
    
    @objc func receiveAnnouncementRecord(notification: Notification)
    {
        if let announcementRecord = notification.object as? CKRecord
        {
            announcementViewController?.announcementRecord = announcementRecord
            announcementViewController?.loadDataFromRecord()
        }
    }
}
