//
// OrientationManager.swift
// bitchat
//
// Manages orientation lock for per-screen rotation control.
// Part of BeyScore Tournament System.
//

import UIKit

/// Manages device orientation locking for per-screen control.
enum OrientationManager {

    /// Lock device to portrait orientation only (iPhone only - iPad always allows all).
    static func lockToPortrait() {
        // iPad should always support all orientations
        if DeviceEnvironment.isIPad {
            AppDelegate.orientationLock = .all
        } else {
            AppDelegate.orientationLock = .portrait
            rotateToPortrait()
        }
    }

    /// Allow all orientations (portrait + landscape).
    static func allowAllOrientations() {
        AppDelegate.orientationLock = DeviceEnvironment.isIPad ? .all : .allButUpsideDown
    }

    /// Force rotation back to portrait (iPhone only).
    private static func rotateToPortrait() {
        // Don't force rotation on iPad
        guard !DeviceEnvironment.isIPad else { return }

        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
