//
//  Settings.swift
//  Locke
//

import SwiftUI

// Every user setting Locke stores in UserDefaults. The raw values are the stored keys and must not
// change, or existing users lose their settings.
enum SettingsKey: String, CaseIterable {
    case ejectOnClose = "setting.EjectOnClose"
    case compactOnDetach = "setting.CompactOnDetach"
    case autoEject = "setting.AutoEject"
    case autoEjectTimeout = "setting.AutoEjectTimeout"
    case showRecentsInMenu = "setting.ShowRecentsInMenu"

    // Applies to both AWS and Backblaze backups (the key name predates Backblaze support)
    case backupUseDate = "setting.BackupAWSUseDate"

    case awsAccessKeyId = "setting.AWSAccessKeyId"
    case awsS3ResourcePath = "setting.AWSS3ResourcePath"

    case backblazeKeyId = "setting.BackblazeKeyId"
    case backblazeEndpoint = "setting.BackblazeEndpoint"
    case backblazeResourcePath = "setting.BackblazeResourcePath"

    case resticRepositoryURL = "setting.ResticRepositoryURL"
    case resticExecutablePath = "setting.ResticExecutablePath"
    case resticKeychainAccount = "setting.ResticKeychainAccount"
    case resticExtraTags = "setting.ResticExtraTags"

    // The value used when the user has never changed the setting
    var defaultValue: Any {
        switch self {
        case .ejectOnClose, .compactOnDetach, .autoEject, .showRecentsInMenu: return true
        case .backupUseDate: return false
        case .autoEjectTimeout: return 100
        default: return ""
        }
    }

    // Register every default so UserDefaults reads agree with what the Settings screen shows.
    // Call once at launch, before anything reads a setting.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: Dictionary(uniqueKeysWithValues: allCases.map { ($0.rawValue, $0.defaultValue) }))
    }
}

extension UserDefaults {
    func bool(_ key: SettingsKey) -> Bool { bool(forKey: key.rawValue) }
    func integer(_ key: SettingsKey) -> Int { integer(forKey: key.rawValue) }

    // The stored string with surrounding whitespace removed ("" when unset)
    func trimmedString(_ key: SettingsKey) -> String {
        (string(forKey: key.rawValue) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension AppStorage {
    init(wrappedValue: Value, _ key: SettingsKey) where Value == Bool {
        self.init(wrappedValue: wrappedValue, key.rawValue)
    }
    init(wrappedValue: Value, _ key: SettingsKey) where Value == Int {
        self.init(wrappedValue: wrappedValue, key.rawValue)
    }
    init(wrappedValue: Value, _ key: SettingsKey) where Value == String {
        self.init(wrappedValue: wrappedValue, key.rawValue)
    }
}
