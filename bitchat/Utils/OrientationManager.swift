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

    /// Lock device to portrait orientation only.
    static func lockToPortrait() {
        AppDelegate.orientationLock = .portrait
        rotateToPortrait()
    }

    /// Allow all orientations (portrait + landscape).
    static func allowAllOrientations() {
        AppDelegate.orientationLock = .allButUpsideDown
    }

    /// Force rotation back to portrait.
    private static func rotateToPortrait() {
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }
}
