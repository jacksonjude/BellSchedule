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
            }
            else
            {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: records?.first)
            }
        }
    }
}
