//
//  ExtensionDelegate.swift
//  BeijingAirWatch WatchKit Extension
//
//  Created by Di Wu on 10/15/15.
//  Copyright © 2015 Beijing Air Watch. All rights reserved.
//

import WatchKit
import WatchConnectivity
import ClockKit

public let LATEST_DATA_READY_NOTIFICATION_NAME = "LATEST_DATA_READY_NOTIFICATION_NAME"

class ExtensionDelegate: NSObject, WKExtensionDelegate, WCSessionDelegate, URLSessionDownloadDelegate {
    /** Called when the session has completed activation. If session state is WCSessionActivationStateNotActivated there will be an error with more details. */
    @available(watchOS 2.2, *)
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        print("handle called")
        showCustomizedAlert("handle called")
        for task in backgroundTasks {
            if task is WKApplicationRefreshBackgroundTask {
                showCustomizedAlert("refresh task called")
                print("handle WKApplicationRefreshBackgroundTask")
                scheduleDownloadTask()
                scheduleBgRefresh(style: .nextHour)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.showCustomizedAlert("refresh task set completed")
                    task.setTaskCompleted()
                }
            } else if let t = task as? WKURLSessionRefreshBackgroundTask {
                _ = createAndHoldSession(task: t)
                showCustomizedAlert("trying to handle session task")
            } else {
                _ = createAndHoldSession(task: nil)
                showCustomizedAlert("snapshot task handled")
                if let t = task as? WKSnapshotRefreshBackgroundTask {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.showCustomizedAlert("refresh task set completed")
                        t.setTaskCompleted(restoredDefaultState: false, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
                    }
                } else {
                    task.setTaskCompleted()
                }
            }
        }
    }
    
    func showCustomizedAlert(_ msg: String) {
        wcSession?.sendMessage(["bg_handler": msg], replyHandler: { (replayHandler: [String : Any]) in
            
            }, errorHandler: { (error: Error) in
                
        })
    }
    
    private let SESSION_ID = "beijingairid"
    
    private var internalSession: URLSession?
    
    private var internalSessionTask: WKURLSessionRefreshBackgroundTask?
    
    private func createAndHoldSession(task: WKURLSessionRefreshBackgroundTask?) -> URLSession {
        if let t = task {
            internalSessionTask = t
        }
        let newSession = URLSession(configuration: URLSessionConfiguration.background(withIdentifier: SESSION_ID), delegate: self, delegateQueue: OperationQueue.main)
        internalSession = newSession
        return newSession
    }
    
    private var session: URLSession {
        get {
            
            
            return createAndHoldSession(task: nil)
 
            
            /*
            guard let s = internalSession else {
                let newSession = URLSession(configuration: URLSessionConfiguration.background(withIdentifier: SESSION_ID), delegate: self, delegateQueue: OperationQueue.main)
                internalSession = newSession
                return newSession
            }
            return s
 */
 
        }
    }
    
    private var downloadTask: URLSessionDownloadTask?
    
    func scheduleDownloadTask() {
        if let t = downloadTask {
            showCustomizedAlert("prev task cancelled")
            t.cancel()
        }
        let task = session.downloadTask(with: createRequest())
        task.resume()
        downloadTask = task
        showCustomizedAlert("download begins")
    }
    
    private func nextRefreshDateSinceNow() -> Date {
        let m = currentMinute()
        var deltaMinute = 0
        if m >= 18 && m <= 30 {
            deltaMinute = 10
        } else {
            deltaMinute = (60 - m) + 18
        }
        showCustomizedAlert("schedule refresh in \(deltaMinute) minutes")
        return Date(timeIntervalSinceNow: Double(deltaMinute) * 60.0)
    }
    
    enum ScheduleStyle {
        case smart
        case nextHour
        case inOneMinute
        case inFiveMinutes
    }
    
    private let magicNumber: Int = 19
    
    private func nextRefreshDateInNextHour() -> Date {
        let m = currentMinute()
        var deltaMinute = 0
        if m <= 18 {
            deltaMinute = magicNumber - m
        } else {
            deltaMinute = (60 - m) + magicNumber
        }
        showCustomizedAlert("schedule refresh in \(deltaMinute) minutes")
        return Date(timeIntervalSinceNow: Double(deltaMinute) * 60.0)
    }
    
    private func nextRefreshDateIn1Minute() -> Date {
        let deltaMinute = 2
        showCustomizedAlert("schedule refresh in \(deltaMinute) minutes")
        return Date(timeIntervalSinceNow: Double(deltaMinute) * 60.0)
    }
    
    private func nextRefreshDateInFiveMinutes() -> Date {
        let deltaMinute = 5
        showCustomizedAlert("schedule refresh in \(deltaMinute) minutes")
        return Date(timeIntervalSinceNow: Double(deltaMinute) * 60.0)
    }
    
    private func scheduleBgRefresh(style: ScheduleStyle) {
        print("schedule bg refres")
        switch style {
        case .smart:
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextRefreshDateSinceNow(), userInfo: nil, scheduledCompletion: { (error: Error?) in
                if let _ = error {
                    self.showCustomizedAlert("schedule error smart")
                }
            })
        case .inOneMinute:
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextRefreshDateIn1Minute(), userInfo: nil, scheduledCompletion: { (error: Error?) in
                if let _ = error {
                    self.showCustomizedAlert("schedule error one min")
                }
            })
        case .inFiveMinutes:
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextRefreshDateInFiveMinutes(), userInfo: nil, scheduledCompletion: { (error: Error?) in
                if let _ = error {
                    self.showCustomizedAlert("schedule error five min")
                }
            })
        default:
            WKExtension.shared().scheduleBackgroundRefresh(withPreferredDate: nextRefreshDateInNextHour(), userInfo: nil, scheduledCompletion: { (error: Error?) in
                if let _ = error {
                    self.showCustomizedAlert("schedule error next hour")
                }
            })
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let e = error {
            print("url session error = \(e)")
            showCustomizedAlert("task complete w/ error")
            scheduleBgRefresh(style: .inFiveMinutes)
        } else {
            showCustomizedAlert("task complete no error")
            scheduleBgRefresh(style: .nextHour)
        }
        if let t = internalSessionTask {
            showCustomizedAlert("set wk bg session task completed")
            t.setTaskCompleted()
        } else {
            showCustomizedAlert("no session task around")
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        showCustomizedAlert("data downloaded")
        print("download task did finish, url = \(location)")
        do {
            let data = try Data(contentsOf: location)
            guard let dataStr = String(data: data, encoding: .ascii) else {
                showCustomizedAlert("data decoding error")
                scheduleBgRefresh(style: .inFiveMinutes)
                return
            }
            let aqi = parseAQI(data: dataStr)
            let concentration = parseConcentration(data: dataStr)
            let time = parseTime(data: dataStr)
            print("parse result \(aqi), \(concentration), \(time)")
            defer {
                NotificationCenter.default.post(name: Notification.Name(LATEST_DATA_READY_NOTIFICATION_NAME), object: nil)
            }
            guard let airQuality = AirQuality(aqi: parseAQI(data: dataStr), concentration: parseConcentration(data: dataStr), time: parseTime(data: dataStr)) else {
                AirQuality.cleanDisk()
                reloadComplication()
                showCustomizedAlert("data format error")
                return
            }
            airQuality.saveToDisk()
            print("get valid data!")
            reloadComplication()
            showCustomizedAlert("cmpl reloaded")
        } catch {
            print("download data invalid")
            showCustomizedAlert("data invalid")
            scheduleBgRefresh(style: .inFiveMinutes)
        }
    }


    var wcSession: WCSession?
    var wcUserInfo: [String: Any]?
    var myOwnComplication: CLKComplication?
    
    func tryAskIOSAppToRegisterVOIPCallback() {
        wcSession?.sendMessage(["xxx":"xxx"], replyHandler: { (reply: [String : Any]) in
            
            }, errorHandler: { (error: Error) in
                
        })
    }
    
    func startWCSession() {
        if (WCSession.isSupported() && wcSession == nil) {
            wcSession = WCSession.default()
            wcSession?.delegate = self
            wcSession?.activate()
            tryAskIOSAppToRegisterVOIPCallback()
        } else if (WCSession.isSupported() && wcSession != nil) {
            wcSession?.activate()
        }
    }
    
    func reloadComplication() {
        let complicationServer = CLKComplicationServer.sharedInstance()
        guard let cmpls = complicationServer.activeComplications else {
            return
        }
        print("reload every complication")
        for complication in cmpls {
            complicationServer.reloadTimeline(for: complication)
        }
    }
    
    
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
        print("did receive info: \(userInfo)")
        if userInfo["a"] != nil {
            wcUserInfo = userInfo
            reloadComplication()
        }
    }
    
    func sendCityToIOSApp(replyHandler: (([String : Any]) -> Void)?, errorHandler: ((Error) -> Void)?) {
//        wcSession?.transferUserInfo(["selected_city": selectedCity().rawValue])
        //     public func sendMessage(message: [String : AnyObject], replyHandler: (([String : AnyObject]) -> Void)?, errorHandler: ((NSError) -> Void)?)

        wcSession?.sendMessage(["selected_city": selectedCity().rawValue], replyHandler: replyHandler, errorHandler:errorHandler)
    }
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        print("did launch")
        showCustomizedAlert("did launch")
        startWCSession()
        scheduleBgRefresh(style: .inOneMinute)
        scheduleDownloadTask()
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

}
