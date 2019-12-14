//
//  ComplicationController.swift
//  ScheduleWatch Extension
//
//  Created by jackson on 12/10/17.
//  Copyright © 2017 jackson. All rights reserved.
//

import ClockKit


class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirections(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimeTravelDirections) -> Void) {
        handler([])
    }
//
//    func getTimelineStartDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
//        handler(nil)
//    }
//
//    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
//        handler(nil)
//    }
//
//    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
//        handler(.showOnLockScreen)
//    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Call the handler with the current timeline entry
        if (complication.family == .graphicCircular)
        {
            let template = CLKComplicationTemplateGraphicCircularImage()
            let image = UIImage(named: "Complication/Graphic Circular")!
            template.imageProvider = CLKFullColorImageProvider(fullColorImage: image)
            let timelineEntry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(timelineEntry)
        }
        handler(nil)
    }
    
//    func getTimelineEntries(for complication: CLKComplication, before date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
//        // Call the handler with the timeline entries prior to the given date
//        handler(nil)
//    }
//
//    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
//        // Call the handler with the timeline entries after to the given date
//        handler(nil)
//    }
    
    // MARK: - Placeholder Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        if (complication.family == .graphicCircular)
        {
            let template = CLKComplicationTemplateGraphicCircularImage()
            template.imageProvider = CLKFullColorImageProvider(fullColorImage: UIImage(named: "Complication/Graphic Circular")!)
            handler(template)
            return
        }
        handler(nil)
    }
    
}
