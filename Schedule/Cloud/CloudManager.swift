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
    var appDelegate = UIApplication.shared.delegate! as! AppDelegate
    
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
    
    func fetchCloudData(entityType: String)
    {
        print("↓ - Fetching Changes from Cloud")
        
        let zoneChangeoptions = CKFetchRecordZoneChangesOptions()
        zoneChangeoptions.previousServerChangeToken = currentChangeToken
        
        let fetchRecordChangesOperation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [CKRecordZone(zoneName: "_defaultZone").zoneID], optionsByRecordZoneID: [CKRecordZone(zoneName: "_defaultZone").zoneID:zoneChangeoptions])
        fetchRecordChangesOperation.fetchAllChanges = true
        
        fetchRecordChangesOperation.recordChangedBlock = {(record) in
            let updateLocalObjectPredicate = NSPredicate(format: "uuid == %@", record.object(forKey: "uuid")! as! CVarArg)
            if let recordToUpdate = self.fetchLocalObjects(predicate: updateLocalObjectPredicate, entityType: entityType)?.first
            {
                self.updateFromRemote(record: record, object: recordToUpdate as! NSManagedObject, fields: self.getFieldsFromEntity(entityType: entityType))
                
                print(" ↓ - Updating)")
            }
            else
            {
                let newObject = NSEntityDescription.insertNewObject(forEntityName: entityType, into: self.appDelegate.persistentContainer.viewContext)
                self.updateFromRemote(record: record, object: newObject, fields: self.getFieldsFromEntity(entityType: entityType))
                
                print(" ↓ - Inserting)")
            }
            
            OperationQueue.main.addOperation {
                (UIApplication.shared.delegate as! AppDelegate).saveContext()
            }
        }
        
        /*fetchRecordChangesOperation.recordWithIDWasDeletedBlock = {(recordID, string) in
            let deleteLocalObjectPredicate = NSPredicate(format: "uuid == %@", )
            let recordToDelete = self.fetchLocalObjects(predicate: deleteLocalObjectPredicate, entityType: entityType)?.first
            if recordToDelete != nil
            {
                print(" ↓ - Deleting)")
                
                OperationQueue.main.addOperation {
                    self.appDelegate.persistentContainer.viewContext.delete(recordToDelete as! NSManagedObject)
                    (UIApplication.shared.delegate as! AppDelegate).saveContext()
                }
            }
        }*/
        
        fetchRecordChangesOperation.recordZoneFetchCompletionBlock = {(recordZoneID, serverChangeToken, data, bool, error) in
            if error != nil
            {
                print("Error: \(String(describing: error))")
            }
            else
            {
                self.currentChangeToken = serverChangeToken
                UserDefaults.standard.set(NSKeyedArchiver.archivedData(withRootObject: self.currentChangeToken as Any), forKey: "currentChangeToken")
            }
        }
        
        fetchRecordChangesOperation.completionBlock = { () in
            OperationQueue.main.addOperation {                
                print("↓ - Finished Fetching Changes from Cloud")
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "finishedFetchingFromCloud"), object: nil)
            }
        }
        
        publicDatabase.add(fetchRecordChangesOperation)
    }
    
    func fetchLocalObjects(predicate: NSPredicate, entityType: String) -> [AnyObject]?
    {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WeekSchedules")
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
            let recordObject = record.object(forKey: field)!
            var coreDataObject = recordObject
            if let recordArray = recordObject as? Array<String>
            {
                do
                {
                    try coreDataObject = JSONEncoder().encode(recordArray) as CKRecordValue
                }
                catch
                {
                    print(error)
                }
            }
            object.setValue(coreDataObject, forKey: field)
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
