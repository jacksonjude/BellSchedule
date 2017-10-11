//
//  CloudKitManager.swift
//  Schedule
//
//  Created by jackson on 10/5/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation
import CoreData
import CloudKit
import UIKit

class CloudManager: NSObject
{
    let publicDatabase = CKContainer.default().publicCloudDatabase
    
    let projectZone = CKRecordZone(zoneName: "ProjectZone")
    
    func fetchPublicDatabaseObject(type: String, predicate: NSPredicate, returnID: String)
    {
        let objectQuery = CKQuery(recordType: type, predicate: predicate)
        publicDatabase.perform(objectQuery, inZoneWith: nil) { (records, error) in
            if error != nil
            {
                print(error!)
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: nil)
            }
            else
            {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: records?.first)
            }
        }
    }
    
    func setPublicDatabaseObject(type: String, dataDictionary: Dictionary<String,Any>, predicate: NSPredicate)
    {
        let objectQuery = CKQuery(recordType: type, predicate: predicate)
        publicDatabase.perform(objectQuery, inZoneWith: nil) { (records, error) in
            if error != nil
            {
                print(error!)
            }
            else
            {
                var remoteRecord: CKRecord? = nil
                if records!.count > 0
                {
                    remoteRecord = records!.first!
                }
                else
                {
                    remoteRecord = CKRecord(recordType: type)
                }
                
                for object in dataDictionary
                {
                    remoteRecord!.setValue(object.value, forKey: object.key)
                }
                
                self.publicDatabase.save(remoteRecord!, completionHandler: { (record, error) -> Void in
                    if (error != nil) {
                        print("Error: \(String(describing: error))")
                    }
                    else
                    {
                        print("Uploaded " + type + " to public database!")
                    }
                })
            }
        }
    }
}
