import CoreData
import Foundation
import SwiftData
import os

enum WorkoutSchema: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            StoredCatalogItem.self,
            StoredExerciseProfile.self,
            StoredPlan.self,
            StoredActiveSession.self,
            StoredCompletedSession.self,
        ]
    }

    @Model
    final class StoredCatalogItem {
        @Attribute(.unique) var id: UUID
        var name: String
        var aliasesData: Data
        var categoryRaw: String

        init(
            id: UUID,
            name: String,
            aliasesData: Data,
            categoryRaw: String
        ) {
            self.id = id
            self.name = name
            self.aliasesData = aliasesData
            self.categoryRaw = categoryRaw
        }
    }

    @Model
    final class StoredExerciseProfile {
        @Attribute(.unique) var id: UUID
        var exerciseID: UUID
        var trainingMax: Double?
        var preferredIncrement: Double?

        init(
            id: UUID,
            exerciseID: UUID,
            trainingMax: Double?,
            preferredIncrement: Double?
        ) {
            self.id = id
            self.exerciseID = exerciseID
            self.trainingMax = trainingMax
            self.preferredIncrement = preferredIncrement
        }
    }

    @Model
    final class StoredPlan {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        var pinnedTemplateID: UUID?
        var payloadData: Data
        var summaryData: Data

        init(
            id: UUID,
            name: String,
            createdAt: Date,
            pinnedTemplateID: UUID?,
            payloadData: Data,
            summaryData: Data
        ) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.pinnedTemplateID = pinnedTemplateID
            self.payloadData = payloadData
            self.summaryData = summaryData
        }
    }

    @Model
    final class StoredActiveSession {
        @Attribute(.unique) var id: UUID
        var planID: UUID?
        var templateID: UUID
        var templateNameSnapshot: String
        var startedAt: Date
        var lastUpdatedAt: Date
        var notes: String
        var restTimerEndsAt: Date?
        var payloadData: Data

        init(
            id: UUID,
            planID: UUID?,
            templateID: UUID,
            templateNameSnapshot: String,
            startedAt: Date,
            lastUpdatedAt: Date,
            notes: String,
            restTimerEndsAt: Date?,
            payloadData: Data
        ) {
            self.id = id
            self.planID = planID
            self.templateID = templateID
            self.templateNameSnapshot = templateNameSnapshot
            self.startedAt = startedAt
            self.lastUpdatedAt = lastUpdatedAt
            self.notes = notes
            self.restTimerEndsAt = restTimerEndsAt
            self.payloadData = payloadData
        }
    }

    @Model
    final class StoredCompletedSession {
        @Attribute(.unique) var id: UUID
        var planID: UUID?
        var templateID: UUID
        var templateNameSnapshot: String
        var completedAt: Date
        var payloadData: Data

        init(
            id: UUID,
            planID: UUID?,
            templateID: UUID,
            templateNameSnapshot: String,
            completedAt: Date,
            payloadData: Data
        ) {
            self.id = id
            self.planID = planID
            self.templateID = templateID
            self.templateNameSnapshot = templateNameSnapshot
            self.completedAt = completedAt
            self.payloadData = payloadData
        }
    }
}

typealias StoredCatalogItem = WorkoutSchema.StoredCatalogItem
typealias StoredExerciseProfile = WorkoutSchema.StoredExerciseProfile
typealias StoredPlan = WorkoutSchema.StoredPlan
typealias StoredActiveSession = WorkoutSchema.StoredActiveSession
typealias StoredCompletedSession = WorkoutSchema.StoredCompletedSession

struct PersistenceStartupIssue: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let recoveryDirectoryURL: URL?

    init(title: String, message: String, recoveryDirectoryURL: URL? = nil) {
        self.title = title
        self.message = message
        self.recoveryDirectoryURL = recoveryDirectoryURL
    }
}

enum PersistenceDiagnostics {
    private static let logger = Logger(subsystem: "com.cam.workouttracker", category: "Persistence")

    static func record(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func record(_ message: String, error: any Error) {
        logger.error(
            "\(message, privacy: .public): \(String(describing: error), privacy: .private)"
        )
    }
}

enum PersistenceRecoveryClassifier {
    private static let resettableSQLiteCodes: Set<Int> = [
        11, // SQLITE_CORRUPT
        26, // SQLITE_NOTADB
    ]
    private static let resettableCocoaCodes: Set<Int> = [
        NSPersistentStoreIncompatibleSchemaError,
        NSPersistentStoreIncompatibleVersionHashError,
        NSMigrationError,
        NSMigrationMissingSourceModelError,
    ]

    static func shouldAttemptReset(after error: any Error, storeURL: URL? = nil) -> Bool {
        if flattenedErrors(from: error).contains(where: isResettableStoreError) {
            return true
        }

        let errorDescription = String(describing: error).lowercased()
        if isResettableMigrationDescription(errorDescription) {
            return true
        }

        guard let storeURL else {
            return false
        }

        return errorDescription.contains("loadissuemodelcontainer")
            && hasExistingPersistentStoreArtifact(at: storeURL)
    }

    private static func isResettableStoreError(_ error: NSError) -> Bool {
        if error.domain == "NSSQLiteErrorDomain",
            resettableSQLiteCodes.contains(error.code)
        {
            return true
        }

        if error.domain == NSCocoaErrorDomain,
            resettableCocoaCodes.contains(error.code)
        {
            return true
        }

        let description = [
            error.localizedDescription,
            error.userInfo[NSLocalizedFailureReasonErrorKey] as? String,
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        return description.contains("corrupt")
            || description.contains("malformed")
            || description.contains("not a database")
            || isResettableMigrationDescription(description)
    }

    private static func isResettableMigrationDescription(_ description: String) -> Bool {
        description.contains("cannot migrate store in-place")
            || description.contains("persistent store migration")
            || description.contains("mandatory destination attribute")
            || description.contains("missing attribute values")
    }

    private static func hasExistingPersistentStoreArtifact(at url: URL) -> Bool {
        storeArtifactURLs(for: url).contains { candidate in
            var isDirectory = ObjCBool(false)
            let exists = FileManager.default.fileExists(
                atPath: candidate.path,
                isDirectory: &isDirectory
            )
            return exists && !isDirectory.boolValue
        }
    }

    private static func storeArtifactURLs(for url: URL) -> [URL] {
        [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal"),
        ]
    }

    private static func flattenedErrors(from error: any Error) -> [NSError] {
        var flattened: [NSError] = []
        var visited = Set<ObjectIdentifier>()

        func append(_ error: NSError) {
            let identifier = ObjectIdentifier(error)
            guard visited.insert(identifier).inserted else {
                return
            }

            flattened.append(error)

            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                append(underlyingError)
            } else if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? any Error {
                append(underlyingError as NSError)
            }

            if let detailedErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] {
                detailedErrors.forEach(append)
            }

            if let multipleUnderlyingErrors = error.userInfo["NSMultipleUnderlyingErrorsKey"] as? [NSError] {
                multipleUnderlyingErrors.forEach(append)
            }
        }

        append(error as NSError)
        return flattened
    }
}

enum WorkoutModelContainerFactory {
    private static let schema = Schema(versionedSchema: WorkoutSchema.self)
    private static let storeDirectoryName = "WorkoutTracker"
    private static let storeFilename = "WorkoutTracker.store"
    nonisolated(unsafe) private static var pendingStartupIssue: PersistenceStartupIssue?
    private static let storageUnavailableMessage =
        "WorkoutTracker could not open its local database, so the app started with temporary "
        + "in-memory storage. Data from this launch will not persist after you close the app."
    private static let storageResetMessage =
        "WorkoutTracker reset its local database after a storage error. Existing saved plans "
        + "and workout history may need to be recreated."
    private static let storageResetBackupSuffix =
        " A backup of the previous store was saved locally when possible."

    static func makeContainer(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) -> ModelContainer {
        pendingStartupIssue = nil

        if isStoredInMemoryOnly {
            do {
                return try makeInMemoryContainer()
            } catch {
                fatalError("Failed to initialize in-memory SwiftData container: \(error)")
            }
        }

        guard let resolvedStoreURL = try? persistentStoreURL(explicitURL: storeURL) else {
            PersistenceDiagnostics.record("Failed to resolve persistent store URL. Falling back to in-memory storage.")
            return fallbackInMemoryContainer(
                title: "Storage Unavailable",
                message: storageUnavailableMessage
            )
        }

        do {
            return try makePersistentContainer(at: resolvedStoreURL)
        } catch {
            PersistenceDiagnostics.record("Failed to initialize persistent SwiftData container", error: error)

            guard PersistenceRecoveryClassifier.shouldAttemptReset(
                after: error,
                storeURL: resolvedStoreURL
            ) else {
                PersistenceDiagnostics.record(
                    "Persistent store failure did not match a resettable corruption signature. Falling back to in-memory storage."
                )
                return fallbackInMemoryContainer(
                    title: "Storage Unavailable",
                    message: storageUnavailableMessage
                )
            }

            do {
                let backupURL = try backupPersistentStoreArtifacts(at: resolvedStoreURL)
                try removePersistentStoreArtifacts(at: resolvedStoreURL)
                let recoveredContainer = try makePersistentContainer(at: resolvedStoreURL)
                pendingStartupIssue = PersistenceStartupIssue(
                    title: "Storage Reset",
                    message: storageResetMessage + storageResetBackupSuffix,
                    recoveryDirectoryURL: backupURL
                )
                PersistenceDiagnostics.record(
                    "Recovered persistent store by resetting the local database. A backup was saved locally."
                )
                return recoveredContainer
            } catch {
                PersistenceDiagnostics.record(
                    "Failed to recover persistent SwiftData container. Falling back to in-memory storage",
                    error: error
                )
                return fallbackInMemoryContainer(
                    title: "Storage Unavailable",
                    message: storageUnavailableMessage
                )
            }
        }
    }

    static func consumeStartupIssue() -> PersistenceStartupIssue? {
        defer { pendingStartupIssue = nil }
        return pendingStartupIssue
    }

    private static func makePersistentContainer(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            configurations: configuration
        )
    }

    private static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            configurations: configuration
        )
    }

    private static func fallbackInMemoryContainer(title: String, message: String) -> ModelContainer {
        pendingStartupIssue = PersistenceStartupIssue(title: title, message: message)

        do {
            return try makeInMemoryContainer()
        } catch {
            fatalError("Failed to initialize fallback SwiftData container: \(error)")
        }
    }

    private static func persistentStoreURL(explicitURL: URL?) throws -> URL {
        if let explicitURL {
            try FileManager.default.createDirectory(
                at: explicitURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return explicitURL
        }

        let supportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let storeDirectory = supportDirectory.appendingPathComponent(storeDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        return storeDirectory.appendingPathComponent(storeFilename)
    }

    private static func removePersistentStoreArtifacts(at url: URL) throws {
        let fileManager = FileManager.default
        for candidate in relatedPersistentStoreURLs(at: url)
        where fileManager.fileExists(atPath: candidate.path) {
            try fileManager.removeItem(at: candidate)
        }
    }

    private static func backupPersistentStoreArtifacts(at url: URL) throws -> URL {
        let fileManager = FileManager.default
        let existingURLs = relatedPersistentStoreURLs(at: url).filter { fileManager.fileExists(atPath: $0.path) }
        let backupRoot = url.deletingLastPathComponent()
            .appendingPathComponent("Recovery", isDirectory: true)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupDirectory = backupRoot.appendingPathComponent(
            "\(url.deletingPathExtension().lastPathComponent)-\(formatter.string(from: .now))",
            isDirectory: true
        )

        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        for sourceURL in existingURLs {
            let destinationURL = backupDirectory.appendingPathComponent(sourceURL.lastPathComponent)
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }

        return backupDirectory
    }

    private static func relatedPersistentStoreURLs(at url: URL) -> [URL] {
        [
            url,
            URL(fileURLWithPath: url.path + "-shm"),
            URL(fileURLWithPath: url.path + "-wal"),
        ]
    }
}
