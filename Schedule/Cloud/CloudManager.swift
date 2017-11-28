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
    static let publicDatabase = CKContainer.default().publicCloudDatabase
    static var savingCloudChanges = false
    
    static func fetchPublicDatabaseObject(type: String, predicate: NSPredicate, returnID: String)
    {
        let objectQuery = CKQuery(recordType: type, predicate: predicate)
        CloudManager.publicDatabase.perform(objectQuery, inZoneWith: nil) { (records, error) in
            if error != nil
            {
                Logger.println(error!)
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: nil)
            }
            else
            {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: records?.first)
            }
        }
    }
    
    static func setPublicDatabaseObject(type: String, dataDictionary: Dictionary<String,Any>, predicate: NSPredicate)
    {
        let objectQuery = CKQuery(recordType: type, predicate: predicate)
        CloudManager.publicDatabase.perform(objectQuery, inZoneWith: nil) { (records, error) in
            if error != nil
            {
                Logger.println(error!)
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
                        Logger.println("Error: \(String(describing: error))")
                    }
                    else
                    {
                        Logger.println("Uploaded " + type + " to public database!")
                    }
                })
            }
        }
    }
    
    static func fetchAllCloudData(entityType: String)
    {
        Logger.println("↓ - Fetching Changes from Cloud")
        
        let lastUpdatedDate = UserDefaults.standard.object(forKey: "lastUpdatedData") as? NSDate ?? Date.distantPast as NSDate
        let cloudEntityQuery = CKQuery(recordType: entityType, predicate: NSPredicate(format: "modificationDate >= %@", lastUpdatedDate))
        CloudManager.publicDatabase.perform(cloudEntityQuery, inZoneWith: CKRecordZone.default().zoneID) { (results, error) in
            if error != nil
            {
                Logger.println(error!)
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "cloudKitError"), object: error!)
            }
            else
            {
                if results != nil && results!.count > 0
                {
                    for record in results!
                    {
                        OperationQueue.main.addOperation {
                            if let localObject = self.fetchLocalObjects(type: entityType, predicate: NSPredicate(format: "uuid == %@", record.recordID.recordName))?.first as? NSManagedObject
                            {
                                self.updateFromRemote(record: record, object: localObject, fields: self.getFieldsFromEntity(entityType: entityType))
                            }
                            else
                            {
                                let newObject = NSEntityDescription.insertNewObject(forEntityName: entityType, into: CoreDataStack.persistentContainer.viewContext)
                                self.updateFromRemote(record: record, object: newObject, fields: self.getFieldsFromEntity(entityType: entityType))
                            }
                        }
                    }
                }
                
                Logger.println(" Updated " + String(results?.count ?? 0) + " records from " + entityType)
                
                OperationQueue.main.addOperation {
                    CloudManager.savingCloudChanges = true
                    
                    CoreDataStack.saveContext()
                }
            }
        }
    }
    
    @objc func contextSaved()
    {
        if CloudManager.savingCloudChanges
        {
            CloudManager.savingCloudChanges = false
            NotificationCenter.default.post(name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)
        }
    }
    
    static func fetchLocalObjects(type: String, predicate: NSPredicate) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: type)
        fetchRequest.predicate = predicate
        
        let fetchResults: [AnyObject]?
        var error: NSError? = nil
        
        do {
            fetchResults = try CoreDataStack.persistentContainer.viewContext.fetch(fetchRequest)
        } catch let error1 as NSError {
            error = error1
            fetchResults = nil
            NSLog("An Error Occored:", error!)
        } catch {
            fatalError()
        }
        
        return fetchResults
    }
    
    override init()
    {
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(contextSaved), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
    }
    
    static func updateFromRemote(record: CKRecord, object: NSManagedObject, fields: Array<String>)
    {
        for field in fields
        {
            if field != "uuid"
            {
                if let recordObject = record.object(forKey: field)
                {
                    var coreDataObject = recordObject
                    if let recordArray = recordObject as? NSArray
                    {
                        do
                        {
                            coreDataObject = try JSONSerialization.data(withJSONObject: recordArray, options: .prettyPrinted) as CKRecordValue
                        }
                        catch
                        {
                            Logger.println(error)
                        }
                    }
                    object.setValue(coreDataObject, forKey: field)
                }
            }
            else
            {
                object.setValue(record.recordID.recordName, forKey: "uuid")
            }
        }
    }
    
    static func getFieldsFromEntity(entityType: String) -> Array<String>
    {
        switch entityType
        {
        case "Schedule":
            return ["periodNumbers", "periodTimes", "scheduleCode", "uuid"]
        case "WeekSchedules":
            return ["schedules", "weekStartDate", "uuid"]
        case "UserSchedule":
            return ["periodNames", "userID", "uuid"]
        default:
            return []
        }
    }
}
