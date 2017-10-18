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
    var currentChangeToken: CKServerChangeToken?
    var savingCloudChanges = false
    
    func fetchPublicDatabaseObject(type: String, predicate: NSPredicate, returnID: String)
    {
        let objectQuery = CKQuery(recordType: type, predicate: predicate)
        publicDatabase.perform(objectQuery, inZoneWith: nil) { (records, error) in
            if error != nil
            {
                logger.println(error!)
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
                logger.println(error!)
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
                        logger.println("Error: \(String(describing: error))")
                    }
                    else
                    {
                        logger.println("Uploaded " + type + " to public database!")
                    }
                })
            }
        }
    }
    
    func fetchCloudData(entityType: String)
    {
        logger.println("↓ - Fetching Changes from Cloud: " + entityType)
        
        let zoneChangeoptions = CKFetchRecordZoneChangesOptions()
        zoneChangeoptions.previousServerChangeToken = currentChangeToken
        
        let fetchRecordChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [CKRecordZone(zoneName: "_defaultZone").zoneID], optionsByRecordZoneID: [CKRecordZone(zoneName: "_defaultZone").zoneID:zoneChangeoptions])
        fetchRecordChangesOperation.fetchAllChanges = true
        
        fetchRecordChangesOperation.recordChangedBlock = {(record) in
            let updateLocalObjectPredicate = NSPredicate(format: "uuid == %@", record.recordID.recordName)
            if let recordToUpdate = self.fetchLocalObjects(type: entityType, predicate: updateLocalObjectPredicate)?.first
            {
                self.updateFromRemote(record: record, object: recordToUpdate as! NSManagedObject, fields: self.getFieldsFromEntity(entityType: entityType))
                
                logger.println(" ↓ - Updating)")
            }
            else
            {
                let newObject = NSEntityDescription.insertNewObject(forEntityName: entityType, into: appDelegate.persistentContainer.viewContext)
                self.updateFromRemote(record: record, object: newObject, fields: self.getFieldsFromEntity(entityType: entityType))
                
                logger.println(" ↓ - Inserting)")
            }
            
            OperationQueue.main.addOperation {
                (UIApplication.shared.delegate as! AppDelegate).saveContext()
            }
        }
        
        fetchRecordChangesOperation.recordWithIDWasDeletedBlock = {(recordID, string) in
            let deleteLocalObjectPredicate = NSPredicate(format: "uuid == %@", recordID.recordName)
            let recordToDelete = self.fetchLocalObjects(type: entityType, predicate: deleteLocalObjectPredicate)?.first
            if recordToDelete != nil
            {
                logger.println(" ↓ - Deleting)")
                
                OperationQueue.main.addOperation {
                    appDelegate.persistentContainer.viewContext.delete(recordToDelete as! NSManagedObject)
                    (UIApplication.shared.delegate as! AppDelegate).saveContext()
                }
            }
        }
        
        fetchRecordChangesOperation.recordZoneFetchCompletionBlock = {(recordZoneID, serverChangeToken, data, bool, error) in
            if error != nil
            {
                logger.println("Error: \(String(describing: error))")
            }
            else
            {
                self.currentChangeToken = serverChangeToken
                UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: self.currentChangeToken as Any), forKey: "currentChangeToken")
            }
        }
        
        fetchRecordChangesOperation.completionBlock = { () in
            OperationQueue.main.addOperation {                
                logger.println("↓ - Finished Fetching Changes from Cloud")
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "finishedFetchingFromCloud"), object: nil)
            }
        }
        
        publicDatabase.add(fetchRecordChangesOperation)
    }
    
    func fetchAllCloudData(entityType: String)
    {
        logger.println("↓ - Fetching Changes from Cloud")
        
        let lastUpdatedDate = UserDefaults.standard.object(forKey: "lastUpdatedData") as? NSDate ?? Date.distantPast as NSDate
        let cloudEntityQuery = CKQuery(recordType: entityType, predicate: NSPredicate(format: "modificationDate >= %@", lastUpdatedDate))
        publicDatabase.perform(cloudEntityQuery, inZoneWith: CKRecordZone.default().zoneID) { (results, error) in
            if error != nil
            {
                logger.println(error!)
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
                                let newObject = NSEntityDescription.insertNewObject(forEntityName: entityType, into: appDelegate.persistentContainer.viewContext)
                                self.updateFromRemote(record: record, object: newObject, fields: self.getFieldsFromEntity(entityType: entityType))
                            }
                        }
                    }
                }
                
                logger.println(" Updated " + String(results?.count ?? 0) + " records from " + entityType)
                
                OperationQueue.main.addOperation {
                    self.savingCloudChanges = true
                    
                    appDelegate.saveContext()
                }
            }
        }
    }
    
    @objc func contextSaved()
    {
        if savingCloudChanges
        {
            savingCloudChanges = false
            NotificationCenter.default.post(name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)
        }
    }
    
    func fetchLocalObjects(type: String, predicate: NSPredicate) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: type)
        fetchRequest.predicate = predicate
        
        let fetchResults: [AnyObject]?
        var error: NSError? = nil
        
        do {
            fetchResults = try appDelegate.persistentContainer.viewContext.fetch(fetchRequest)
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
        
        if !((UIApplication.shared.delegate as! AppDelegate).firstLaunch)
        {
            if let changeToken = UserDefaults.standard.object(forKey: "currentChangeToken")
            {
                currentChangeToken = NSKeyedUnarchiver.unarchiveObject(with: changeToken as! Data) as? CKServerChangeToken
            }
        }
    }
    
    func updateFromRemote(record: CKRecord, object: NSManagedObject, fields: Array<String>)
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
                            logger.println(error)
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
    
    func getFieldsFromEntity(entityType: String) -> Array<String>
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
