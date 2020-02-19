//
//  CoreDataStack.swift
//  Schedule
//
//  Created by jackson on 11/27/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import Foundation
import CoreData

class CoreDataStack: NSObject
{
    static var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "Schedule")
        
        //var persistentStoreDescriptions: NSPersistentStoreDescription
                
        let storeUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jacksonjude.BellSchedule")!.appendingPathComponent("Schedule.sqlite")

        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.url = storeUrl
        
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Core Data Saving support
    
    static func saveContext () {
        let context = CoreDataStack.persistentContainer.viewContext
        do {
            try context.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
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
    
    static func decodeArrayFromJSON(object: NSManagedObject, field: String) -> Array<Any>?
    {
        if let JSONdata = object.value(forKey: field) as? Data
        {
            do
            {
                let array = try JSONSerialization.jsonObject(with: JSONdata, options: .allowFragments) as? Array<Any>
                return array
            }
            catch
            {
                Logger.println(error)
                return nil
            }
        }
        
        return nil
    }
}
