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
    static let publicDatabase = CKContainer(identifier: "iCloud.com.jacksonjude.BellSchedule").publicCloudDatabase
    static var savingCloudChanges = false
    static var fetchAllDataQueue = Array<String>()
    static var queueIsRunning = false
    static var numberOfRecordsUpdated = 0
    static var currentCloudOperations: [String:CKDatabaseOperation] = [:]
    
    static func fetchPublicDatabaseObject(type: String, predicate: NSPredicate, returnID: String)
    {
        let objectQuery = CKQuery(recordType: type, predicate: predicate)
        
        let objectQueryOperation = CKQueryOperation(query: objectQuery)
        
        objectQueryOperation.recordFetchedBlock = {(record) in
            NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: nil, userInfo: ["object":record])
        }
        
        objectQueryOperation.queryCompletionBlock = {(cursorThingy, error) in
            if error != nil
            {
                Logger.println(error!)
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: nil)
            }
        }
        
        publicDatabase.add(objectQueryOperation)
        self.currentCloudOperations[returnID] = objectQueryOperation
        
        /*CloudManager.publicDatabase.perform(objectQuery, inZoneWith: nil) { (records, error) in
            if error != nil
            {
                Logger.println(error!)
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: nil)
            }
            else
            {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "fetchedPublicDatabaseObject:" + returnID), object: records?.first)
            }
        }*/
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
        Logger.println("↓ - Fetching Changes from Cloud: " + entityType)
        
        let lastUpdatedDate = UserDefaults.standard.object(forKey: "lastUpdatedData") as? NSDate ?? Date.distantPast as NSDate
                
        let cloudEntityQuery = CKQuery(recordType: entityType, predicate: NSPredicate(format: "modificationDate >= %@", lastUpdatedDate))
        
        let cloudEntityQueryOperation = CKQueryOperation(query: cloudEntityQuery)
        
        cloudEntityQueryOperation.recordFetchedBlock = {(record) in
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
            
            numberOfRecordsUpdated += 1
        }
        
        cloudEntityQueryOperation.queryCompletionBlock = {(cursorThingy, error) in
            let tmpNumberOfRecordsUpdated = self.numberOfRecordsUpdated
            self.numberOfRecordsUpdated = 0
            
            if let fetchIndex = self.currentCloudOperations.index(forKey: "fetchAllCloudData")
            {
                self.currentCloudOperations.remove(at: fetchIndex)
            }
            
            if error != nil
            {
                Logger.println(error!)
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "cloudKitError"), object: nil, userInfo: ["object":error!])
                NotificationCenter.default.removeObserver(self)
                
                loopFetchAllData()
            }
            else
            {
                Logger.println("↓ - Updated " + String(tmpNumberOfRecordsUpdated) + " records from " + entityType)
                
                OperationQueue.main.addOperation {
                    CloudManager.savingCloudChanges = true
                    
                    CoreDataStack.saveContext()
                }
            }
        }
        
        publicDatabase.add(cloudEntityQueryOperation)
        self.currentCloudOperations["fetchAllCloudData"] = cloudEntityQueryOperation
        
        /*CloudManager.publicDatabase.perform(cloudEntityQuery, inZoneWith: CKRecordZone.default().zoneID) { (results, error) in
            if error != nil
            {
                Logger.println(error!)
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: "cloudKitError"), object: error!)
                
                NotificationCenter.default.removeObserver(self)
                
                loopFetchAllData()
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
                
                Logger.println("↓ - Updated " + String(results?.count ?? 0) + " records from " + entityType)
                
                OperationQueue.main.addOperation {
                    CloudManager.savingCloudChanges = true
                    
                    CoreDataStack.saveContext()
                }
            }
        }*/
    }
    
    @objc static func contextSaved()
    {
        if CloudManager.savingCloudChanges
        {
            CloudManager.savingCloudChanges = false
            NotificationCenter.default.post(name: Notification.Name(rawValue: "finishedFetchingAllData"), object: nil)
            
            loopFetchAllData()
        }
    }
    
    static func initFetchAllDataQueue()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(self.contextSaved), name: NSNotification.Name.NSManagedObjectContextDidSave, object: nil)
        if !queueIsRunning
        {
            queueIsRunning = true
            
            loopFetchAllData()
        }
    }
    
    static func loopFetchAllData()
    {
        if fetchAllDataQueue.count > 0
        {
            let entityTypeToFetch = fetchAllDataQueue[0]
            
            fetchAllDataQueue.remove(at: 0)
            
            fetchAllCloudData(entityType: entityTypeToFetch)
        }
        else
        {
            NotificationCenter.default.removeObserver(self)
            queueIsRunning = false
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
            Logger.println("An Error Occored: " + error!.localizedDescription)
        } catch {
            fatalError()
        }
                
        return fetchResults
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
    
    static func fetchSpecificFields(entityType: String, fields: [String], completionHandler: (@escaping (Dictionary<String,Array<CKRecordValue>>) -> Void))
    {
        Logger.println("↓ - Fetching specific fields from Cloud: " + entityType)
        
        let truePredicate = NSPredicate(value: true)
        let specificFieldQuery = CKQuery(recordType: entityType, predicate: truePredicate)
        let specificFieldOperation = CKQueryOperation(query: specificFieldQuery)
        specificFieldOperation.desiredKeys = fields
        
        var fetchedItems = Array<CKRecord>()
        
        var fetchedFieldObjects = Dictionary<String,Array<CKRecordValue>>()
        
        for field in fields
        {
            fetchedFieldObjects[field] = Array<CKRecordValue>()
        }
        fetchedFieldObjects["uuid"] = Array<CKRecordValue>()
        
        specificFieldOperation.queryCompletionBlock = ( { (cursor, error) -> Void in
            if error != nil
            {
                Logger.println("Error: " + error!.localizedDescription)
            }
            else
            {
                Logger.println("↓ - Fetched " + String(fetchedItems.count) + " " + entityType)
                
                for record in fetchedItems
                {
                    for field in fields
                    {
                        fetchedFieldObjects[field]?.append(record.object(forKey: field)!)
                    }
                    
                    fetchedFieldObjects["uuid"]?.append(record.recordID.recordName as CKRecordValue)
                }
                
                completionHandler(fetchedFieldObjects)
            }
        })
        
        specificFieldOperation.recordFetchedBlock = ( { (record) -> Void in
            fetchedItems.append(record)
        })
        
        publicDatabase.add(specificFieldOperation)
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
            return ["periodNames", "freeMods", "userID", "uuid"]
        case "Announcement":
            return ["title", "postDate", "bodyText", "uuid"]
        default:
            return []
        }
    }
}
