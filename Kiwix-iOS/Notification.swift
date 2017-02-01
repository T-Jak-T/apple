//
//  Notifications.swift
//  Kiwix
//
//  Created by Chris Li on 9/19/16.
//  Copyright © 2016 Chris Li. All rights reserved.
//

import UserNotifications

class AppNotification: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotification()
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerActions()
    }
    
    let downloadFinishIdentifier = "org.kiwix.download-finished"
    let refreshLibraryIdentifier = "org.kiwix.library-refreshed"
    
    func requestAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _ in }
    }
    
    func registerActions() {
        let bookDownload = UNNotificationCategory(identifier: downloadFinishIdentifier, actions: [
            UNNotificationAction(identifier: "loadMain", title: "Open Main Page", options: .foreground)
        ], intentIdentifiers: [])
        let refreshLibrary = UNNotificationCategory(identifier: refreshLibraryIdentifier, actions: [
            UNNotificationAction(identifier: "openLibrary", title: "Open Library", options: .foreground)
        ], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([bookDownload, refreshLibrary])
    }
    
    func downloadFinished(bookID: String, bookTitle: String, fileSizeDescription: String) {
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            guard settings.alertSetting == .enabled else {return}
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = self.downloadFinishIdentifier
            content.title = bookTitle + " is downloaded!"
            content.body = fileSizeDescription + " has been transferred."
            let request = UNNotificationRequest(identifier: [self.downloadFinishIdentifier, bookID].joined(separator: "."), content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        })
    }
    
    func libraryRefreshed(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            guard settings.alertSetting == .enabled else {return}
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = self.refreshLibraryIdentifier
            content.title = "Library was refreshed successfully"
            let request = UNNotificationRequest(identifier: self.refreshLibraryIdentifier, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error) in
                completion()
            })
        })
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert, .sound])
    }
        
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let requestIdentifier = response.notification.request.identifier
        if requestIdentifier.hasPrefix(downloadFinishIdentifier) {
            let bookID = requestIdentifier.replacingOccurrences(of: downloadFinishIdentifier + ".", with: "")
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier || response.actionIdentifier == "loadMain" {
                let load = ArticleLoadOperation(bookID: bookID)
                load.addDidFinishBlockObserver(block: { (procedure, errors) in
                    completionHandler()
                })
                GlobalQueue.shared.add(articleLoad: load)
            }
        } else if requestIdentifier.hasPrefix(downloadFinishIdentifier) {
            AppDelegate.mainController.didTapLibraryButton()
        }
    }
}
