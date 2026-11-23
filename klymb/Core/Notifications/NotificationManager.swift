//
//  NotificationManager.swift
//  klymb
//
//  Centralized push notification controller, APNs token registration,
//  and deep link dispatcher (PRD §F14 & Backend B14).
//  Follows AGENTS.md Rules 8, 14, 16, 18.
//

import UIKit
import UserNotifications
import Combine

@MainActor
public final class NotificationManager: NSObject, ObservableObject {
    public static let shared = NotificationManager()

    @Published public var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var preferences: NotificationPreferences = NotificationPreferences()
    @Published public var lastNotificationPayload: AppNotificationPayload?

    private var notificationService: NotificationServiceProtocol?
    private weak var appState: AppState?

    public override init() {
        super.init()
    }

    public func configure(service: NotificationServiceProtocol, appState: AppState) {
        self.notificationService = service
        self.appState = appState
        UNUserNotificationCenter.current().delegate = self

        Task {
            await checkStatus()
            await loadPreferences()
        }
    }

    // MARK: - Permissions

    public func checkStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await checkStatus()

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
                HapticManager.celebration()
            }
            return granted
        } catch {
            await checkStatus()
            return false
        }
    }

    // MARK: - APNs Device Token Registration

    public func handleDeviceToken(_ deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()

        #if DEBUG
        let env = "development"
        #else
        let env = "production"
        #endif

        Task {
            do {
                try await notificationService?.registerDeviceToken(token, environment: env)
            } catch {
                // Non-fatal, token retry on next launch
            }
        }
    }

    // MARK: - Preferences

    public func loadPreferences() async {
        do {
            if let prefs = try await notificationService?.getPreferences() {
                self.preferences = prefs
            }
        } catch {
            // Keep default
        }
    }

    public func updatePreferences(
        overtaken: Bool? = nil,
        challengeEnding: Bool? = nil,
        streakRisk: Bool? = nil
    ) async {
        if let o = overtaken { preferences.overtaken = o }
        if let c = challengeEnding { preferences.challengeEnding = c }
        if let s = streakRisk { preferences.streakRisk = s }

        HapticManager.buttonTap()

        do {
            try await notificationService?.updatePreferences(
                overtaken: overtaken,
                challengeEnding: challengeEnding,
                streakRisk: streakRisk
            )
        } catch {
            // Non-critical sync error
        }
    }

    // MARK: - Local Streak Reminder (8:00 PM)

    public func scheduleStreakReminder(at hour: Int = 20, minute: Int = 0) {
        guard preferences.streakRisk else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["klymb.streak.reminder"])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "🔥 Streak at Risk!"
        content.body = "You haven't logged all daily habits yet. Log before midnight to protect your streak!"
        content.sound = .default
        content.userInfo = ["type": "streak_risk", "target": "home"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "klymb.streak.reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Deep Link Routing

    public func routeNotification(userInfo: [AnyHashable: Any]) {
        guard let payload = AppNotificationPayload.parse(from: userInfo) else { return }
        self.lastNotificationPayload = payload
        self.appState?.selectedTab = payload.targetTab
        HapticManager.selection()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        routeNotification(userInfo: userInfo)
        completionHandler()
    }
}
