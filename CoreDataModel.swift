// CoreDataModel.swift
// Core Data model definitions for Satsat encrypted storage

import Foundation
import CoreData

// MARK: - Core Data Stack

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        // Use programmatic model instead of .xcdatamodeld file
        let managedObjectModel = CoreDataModelBuilder.createModel()
        let container = NSPersistentContainer(name: "Satsat", managedObjectModel: managedObjectModel)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Core Data Model Entities

/// Encrypted group data entity (for xpubs, balances, goals)
/// All group members can decrypt this data using group master key
@objc(EncryptedGroupData)
public class EncryptedGroupData: NSManagedObject {
    @NSManaged public var groupId: String
    @NSManaged public var dataType: String        // "xpubs", "balances", "goals"
    @NSManaged public var encryptedData: Data     // JSON serialized EncryptedData struct
    @NSManaged public var lastModified: Date
    @NSManaged public var version: Int32          // For future key rotation support
    @NSManaged public var createdBy: String       // User who created this data
}

/// Encrypted user data entity (for messages, private keys, notes)  
/// Only the specific user can decrypt this data using personal master key
@objc(EncryptedUserData)
public class EncryptedUserData: NSManagedObject {
    @NSManaged public var userId: String
    @NSManaged public var dataType: String        // "messages", "keys", "notes"
    @NSManaged public var identifier: String      // Specific ID for the data item
    @NSManaged public var encryptedData: Data     // JSON serialized EncryptedData struct
    @NSManaged public var lastModified: Date
    @NSManaged public var version: Int32          // For future key rotation support
    @NSManaged public var groupId: String?        // Optional group association
}

/// Group metadata (basic info stored unencrypted for UI)
@objc(GroupMetadata)
public class GroupMetadata: NSManagedObject {
    @NSManaged public var groupId: String
    @NSManaged public var displayName: String     // Group display name
    @NSManaged public var memberCount: Int32      // Number of members
    @NSManaged public var threshold: Int32        // Multisig threshold (e.g., 2 of 3)
    @NSManaged public var createdAt: Date
    @NSManaged public var lastActivity: Date
    @NSManaged public var isActive: Bool
    @NSManaged public var userRole: String        // "creator", "member", "observer"
}

/// User profile (basic info stored unencrypted for UI)
@objc(UserProfile)
public class UserProfile: NSManagedObject {
    @NSManaged public var userId: String
    @NSManaged public var displayName: String
    @NSManaged public var nostrPubkey: String     // Public key for Nostr
    @NSManaged public var avatarColor: String     // Hex color for avatar
    @NSManaged public var createdAt: Date
    @NSManaged public var lastSeen: Date
    @NSManaged public var isActive: Bool
}

/// App settings (user preferences)
@objc(AppSettings)
public class AppSettings: NSManagedObject {
    @NSManaged public var userId: String
    @NSManaged public var isDarkMode: Bool
    @NSManaged public var biometricsEnabled: Bool
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var autoLockTimeout: Int32  // Minutes
    @NSManaged public var defaultCurrency: String // "USD", "EUR", etc.
    @NSManaged public var lastModified: Date
}

// MARK: - Core Data Model Extensions

extension EncryptedGroupData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EncryptedGroupData> {
        return NSFetchRequest<EncryptedGroupData>(entityName: "EncryptedGroupData")
    }
    
    /// Fetch all encrypted data for a specific group
    static func fetchGroupData(groupId: String, context: NSManagedObjectContext) throws -> [EncryptedGroupData] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "groupId == %@", groupId)
        request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        return try context.fetch(request)
    }
    
    /// Fetch specific data type for a group
    static func fetchGroupData(groupId: String, dataType: String, context: NSManagedObjectContext) throws -> EncryptedGroupData? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "groupId == %@ AND dataType == %@", groupId, dataType)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

extension EncryptedUserData {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<EncryptedUserData> {
        return NSFetchRequest<EncryptedUserData>(entityName: "EncryptedUserData")
    }
    
    /// Fetch all encrypted data for a specific user
    static func fetchUserData(userId: String, context: NSManagedObjectContext) throws -> [EncryptedUserData] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        return try context.fetch(request)
    }
    
    /// Fetch specific data type for a user
    static func fetchUserData(userId: String, dataType: String, context: NSManagedObjectContext) throws -> [EncryptedUserData] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@ AND dataType == %@", userId, dataType)
        request.sortDescriptors = [NSSortDescriptor(key: "lastModified", ascending: false)]
        return try context.fetch(request)
    }
}

extension GroupMetadata {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<GroupMetadata> {
        return NSFetchRequest<GroupMetadata>(entityName: "GroupMetadata")
    }
    
    /// Fetch all active groups for UI display
    static func fetchActiveGroups(context: NSManagedObjectContext) throws -> [GroupMetadata] {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "lastActivity", ascending: false)]
        return try context.fetch(request)
    }
}

extension UserProfile {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserProfile> {
        return NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }
    
    /// Fetch current user profile
    static func fetchCurrentUser(userId: String, context: NSManagedObjectContext) throws -> UserProfile? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

extension AppSettings {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<AppSettings> {
        return NSFetchRequest<AppSettings>(entityName: "AppSettings")
    }
    
    /// Fetch or create app settings for user
    static func fetchOrCreateSettings(userId: String, context: NSManagedObjectContext) throws -> AppSettings {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "userId == %@", userId)
        request.fetchLimit = 1
        
        if let existing = try context.fetch(request).first {
            return existing
        } else {
            // Create default settings
            let settings = AppSettings(context: context)
            settings.userId = userId
            settings.isDarkMode = true        // Dark mode by default
            settings.biometricsEnabled = true
            settings.notificationsEnabled = true
            settings.autoLockTimeout = 5     // 5 minutes
            settings.defaultCurrency = "USD"
            settings.lastModified = Date()
            return settings
        }
    }
}

// MARK: - Core Data Model Creation

/// Creates the Core Data model programmatically
/// This replaces the need for .xcdatamodeld file
class CoreDataModelBuilder {
    static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Create entities
        let encryptedGroupDataEntity = createEncryptedGroupDataEntity()
        let encryptedUserDataEntity = createEncryptedUserDataEntity()
        let groupMetadataEntity = createGroupMetadataEntity()
        let userProfileEntity = createUserProfileEntity()
        let appSettingsEntity = createAppSettingsEntity()
        
        // Add entities to model
        model.entities = [
            encryptedGroupDataEntity,
            encryptedUserDataEntity,
            groupMetadataEntity,
            userProfileEntity,
            appSettingsEntity
        ]
        
        return model
    }
    
    private static func createEncryptedGroupDataEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "EncryptedGroupData"
        entity.managedObjectClassName = "EncryptedGroupData"
        
        let groupIdAttr = NSAttributeDescription()
        groupIdAttr.name = "groupId"
        groupIdAttr.attributeType = .stringAttributeType
        groupIdAttr.isOptional = false
        
        let dataTypeAttr = NSAttributeDescription()
        dataTypeAttr.name = "dataType"
        dataTypeAttr.attributeType = .stringAttributeType
        dataTypeAttr.isOptional = false
        
        let encryptedDataAttr = NSAttributeDescription()
        encryptedDataAttr.name = "encryptedData"
        encryptedDataAttr.attributeType = .binaryDataAttributeType
        encryptedDataAttr.isOptional = false
        
        let lastModifiedAttr = NSAttributeDescription()
        lastModifiedAttr.name = "lastModified"
        lastModifiedAttr.attributeType = .dateAttributeType
        lastModifiedAttr.isOptional = false
        
        let versionAttr = NSAttributeDescription()
        versionAttr.name = "version"
        versionAttr.attributeType = .integer32AttributeType
        versionAttr.isOptional = false
        versionAttr.defaultValue = 1
        
        let createdByAttr = NSAttributeDescription()
        createdByAttr.name = "createdBy"
        createdByAttr.attributeType = .stringAttributeType
        createdByAttr.isOptional = false
        
        entity.properties = [groupIdAttr, dataTypeAttr, encryptedDataAttr, lastModifiedAttr, versionAttr, createdByAttr]
        return entity
    }
    
    private static func createEncryptedUserDataEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "EncryptedUserData"
        entity.managedObjectClassName = "EncryptedUserData"
        
        let userIdAttr = NSAttributeDescription()
        userIdAttr.name = "userId"
        userIdAttr.attributeType = .stringAttributeType
        userIdAttr.isOptional = false
        
        let dataTypeAttr = NSAttributeDescription()
        dataTypeAttr.name = "dataType"
        dataTypeAttr.attributeType = .stringAttributeType
        dataTypeAttr.isOptional = false
        
        let identifierAttr = NSAttributeDescription()
        identifierAttr.name = "identifier"
        identifierAttr.attributeType = .stringAttributeType
        identifierAttr.isOptional = false
        
        let encryptedDataAttr = NSAttributeDescription()
        encryptedDataAttr.name = "encryptedData"
        encryptedDataAttr.attributeType = .binaryDataAttributeType
        encryptedDataAttr.isOptional = false
        
        let lastModifiedAttr = NSAttributeDescription()
        lastModifiedAttr.name = "lastModified"
        lastModifiedAttr.attributeType = .dateAttributeType
        lastModifiedAttr.isOptional = false
        
        let versionAttr = NSAttributeDescription()
        versionAttr.name = "version"
        versionAttr.attributeType = .integer32AttributeType
        versionAttr.isOptional = false
        versionAttr.defaultValue = 1
        
        let groupIdAttr = NSAttributeDescription()
        groupIdAttr.name = "groupId"
        groupIdAttr.attributeType = .stringAttributeType
        groupIdAttr.isOptional = true
        
        entity.properties = [userIdAttr, dataTypeAttr, identifierAttr, encryptedDataAttr, lastModifiedAttr, versionAttr, groupIdAttr]
        return entity
    }
    
    private static func createGroupMetadataEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "GroupMetadata"
        entity.managedObjectClassName = "GroupMetadata"
        
        let groupIdAttr = NSAttributeDescription()
        groupIdAttr.name = "groupId"
        groupIdAttr.attributeType = .stringAttributeType
        groupIdAttr.isOptional = false
        
        let displayNameAttr = NSAttributeDescription()
        displayNameAttr.name = "displayName"
        displayNameAttr.attributeType = .stringAttributeType
        displayNameAttr.isOptional = false
        
        let memberCountAttr = NSAttributeDescription()
        memberCountAttr.name = "memberCount"
        memberCountAttr.attributeType = .integer32AttributeType
        memberCountAttr.isOptional = false
        memberCountAttr.defaultValue = 0
        
        let thresholdAttr = NSAttributeDescription()
        thresholdAttr.name = "threshold"
        thresholdAttr.attributeType = .integer32AttributeType
        thresholdAttr.isOptional = false
        thresholdAttr.defaultValue = 2
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let lastActivityAttr = NSAttributeDescription()
        lastActivityAttr.name = "lastActivity"
        lastActivityAttr.attributeType = .dateAttributeType
        lastActivityAttr.isOptional = false
        
        let isActiveAttr = NSAttributeDescription()
        isActiveAttr.name = "isActive"
        isActiveAttr.attributeType = .booleanAttributeType
        isActiveAttr.isOptional = false
        isActiveAttr.defaultValue = true
        
        let userRoleAttr = NSAttributeDescription()
        userRoleAttr.name = "userRole"
        userRoleAttr.attributeType = .stringAttributeType
        userRoleAttr.isOptional = false
        userRoleAttr.defaultValue = "member"
        
        entity.properties = [groupIdAttr, displayNameAttr, memberCountAttr, thresholdAttr, createdAtAttr, lastActivityAttr, isActiveAttr, userRoleAttr]
        return entity
    }
    
    private static func createUserProfileEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "UserProfile"
        entity.managedObjectClassName = "UserProfile"
        
        let userIdAttr = NSAttributeDescription()
        userIdAttr.name = "userId"
        userIdAttr.attributeType = .stringAttributeType
        userIdAttr.isOptional = false
        
        let displayNameAttr = NSAttributeDescription()
        displayNameAttr.name = "displayName"
        displayNameAttr.attributeType = .stringAttributeType
        displayNameAttr.isOptional = false
        
        let nostrPubkeyAttr = NSAttributeDescription()
        nostrPubkeyAttr.name = "nostrPubkey"
        nostrPubkeyAttr.attributeType = .stringAttributeType
        nostrPubkeyAttr.isOptional = false
        
        let avatarColorAttr = NSAttributeDescription()
        avatarColorAttr.name = "avatarColor"
        avatarColorAttr.attributeType = .stringAttributeType
        avatarColorAttr.isOptional = false
        avatarColorAttr.defaultValue = "#FF9500" // Orange
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let lastSeenAttr = NSAttributeDescription()
        lastSeenAttr.name = "lastSeen"
        lastSeenAttr.attributeType = .dateAttributeType
        lastSeenAttr.isOptional = false
        
        let isActiveAttr = NSAttributeDescription()
        isActiveAttr.name = "isActive"
        isActiveAttr.attributeType = .booleanAttributeType
        isActiveAttr.isOptional = false
        isActiveAttr.defaultValue = true
        
        entity.properties = [userIdAttr, displayNameAttr, nostrPubkeyAttr, avatarColorAttr, createdAtAttr, lastSeenAttr, isActiveAttr]
        return entity
    }
    
    private static func createAppSettingsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "AppSettings"
        entity.managedObjectClassName = "AppSettings"
        
        let userIdAttr = NSAttributeDescription()
        userIdAttr.name = "userId"
        userIdAttr.attributeType = .stringAttributeType
        userIdAttr.isOptional = false
        
        let isDarkModeAttr = NSAttributeDescription()
        isDarkModeAttr.name = "isDarkMode"
        isDarkModeAttr.attributeType = .booleanAttributeType
        isDarkModeAttr.isOptional = false
        isDarkModeAttr.defaultValue = true
        
        let biometricsEnabledAttr = NSAttributeDescription()
        biometricsEnabledAttr.name = "biometricsEnabled"
        biometricsEnabledAttr.attributeType = .booleanAttributeType
        biometricsEnabledAttr.isOptional = false
        biometricsEnabledAttr.defaultValue = true
        
        let notificationsEnabledAttr = NSAttributeDescription()
        notificationsEnabledAttr.name = "notificationsEnabled"
        notificationsEnabledAttr.attributeType = .booleanAttributeType
        notificationsEnabledAttr.isOptional = false
        notificationsEnabledAttr.defaultValue = true
        
        let autoLockTimeoutAttr = NSAttributeDescription()
        autoLockTimeoutAttr.name = "autoLockTimeout"
        autoLockTimeoutAttr.attributeType = .integer32AttributeType
        autoLockTimeoutAttr.isOptional = false
        autoLockTimeoutAttr.defaultValue = 5
        
        let defaultCurrencyAttr = NSAttributeDescription()
        defaultCurrencyAttr.name = "defaultCurrency"
        defaultCurrencyAttr.attributeType = .stringAttributeType
        defaultCurrencyAttr.isOptional = false
        defaultCurrencyAttr.defaultValue = "USD"
        
        let lastModifiedAttr = NSAttributeDescription()
        lastModifiedAttr.name = "lastModified"
        lastModifiedAttr.attributeType = .dateAttributeType
        lastModifiedAttr.isOptional = false
        
        entity.properties = [userIdAttr, isDarkModeAttr, biometricsEnabledAttr, notificationsEnabledAttr, autoLockTimeoutAttr, defaultCurrencyAttr, lastModifiedAttr]
        return entity
    }
}