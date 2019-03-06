//
//  AppDelegate.swift
//  Schedule
//
//  Created by jackson on 10/5/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import UIKit
import CoreData
import MTMigration
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var justLaunched = true
    var firstLaunch = false
    var scheduleNotificationManager: ScheduleNotificationManager?
    var refreshDataOnScheduleViewController = false
    var refreshUserScheduleOnScheduleViewController = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
                
        if UserDefaults.standard.object(forKey: "firstLaunch") == nil
        {
            firstLaunch = true
            UserDefaults.standard.set(618, forKey: "firstLaunch")
        }
        
        MTMigration.applicationUpdate {
            UserDefaults.standard.set(nil, forKey: "lastUpdatedData")
        }
        
        MTMigration.migrate(toBuild: "20190129.1") {
            if let userID = UserDefaults.standard.object(forKey: "UserID")
            {
                let appGroupUserDefaults = UserDefaults(suiteName: "group.com.jacksonjude.BellSchedule")
                appGroupUserDefaults?.set(userID, forKey: "userID")
                appGroupUserDefaults?.synchronize()
            }
        }
        
        backgroundName = (UserDefaults.standard.object(forKey: "backgroundName") as? String) ?? "background1"
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in
            if error == nil && granted
            {
                Logger.println("Granted notifications!")
            }
            else if error != nil
            {
                Logger.println("Error: \(error!.localizedDescription)")
            }
        }
        
        UIApplication.shared.setMinimumBackgroundFetchInterval(86400)
        
        scheduleNotificationManager = ScheduleNotificationManager()
        scheduleNotificationManager?.gatherNotificationData()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: "refreshScheduleInfo"), object: nil)
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        CoreDataStack.saveContext()
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        scheduleNotificationManager = ScheduleNotificationManager()
        scheduleNotificationManager?.gatherNotificationData()
    }
}

