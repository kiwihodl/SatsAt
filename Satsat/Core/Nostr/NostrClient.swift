// NostrClient.swift
// Enhanced Nostr client implementation for Satsat group coordination and messaging

import Foundation
import Combine
import SwiftUI

// MARK: - Enhanced Nostr Client

class NostrClient: ObservableObject {
    static let shared = NostrClient()
    
    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var activeRelays: [RelayConnection] = []
    @Published var receivedEvents: [NostrEvent] = []
    @Published var subscriptionCount: Int = 0
    @Published var eventCacheSize: Int = 0
    @Published var networkHealth: NetworkHealth = .unknown
    
    private var webSockets: [String: URLSessionWebSocketTask] = [:]
    private var subscriptions: [String: NostrSubscription] = [:]
    private var relayStates: [String: RelayState] = [:]
    private var reconnectionTimers: [String: Timer] = [:]
    private var eventCache: [String: NostrEvent] = [:] // Prevent duplicate events
    private var messageQueue: [String: [String]] = [:] // Queue messages when disconnected
    
    private let encryptionManager = SatsatEncryptionManager.shared
    private let keychainManager = KeychainManager.shared
    private let maxReconnectionDelay: TimeInterval = 30.0
    private let maxCacheSize = 1000
    private let connectionTimeout: TimeInterval = 10.0
    
    // Enhanced relay list with priorities
    private let defaultRelays: [RelayInfo] = [
        RelayInfo(url: "wss://nos.lol", priority: .high, description: "nos.lol - General"),
        RelayInfo(url: "wss://relay.damus.io", priority: .high, description: "Damus - Popular"),
        RelayInfo(url: "wss://relay.nostr.band", priority: .medium, description: "Nostr Band - Analytics"),
        RelayInfo(url: "wss://relay.snort.social", priority: .medium, description: "Snort - Social"),
        RelayInfo(url: "wss://nostr.wine", priority: .low, description: "Nostr Wine - Backup"),
        RelayInfo(url: "wss://relay.current.fyi", priority: .low, description: "Current - Backup")
    ]
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNetworkMonitoring()
        setupPeriodicHealthCheck()
    }
    
    // MARK: - Network Monitoring Setup
    
    private func setupNetworkMonitoring() {
        // App state monitoring will be handled by SatsatApp.swift
        print("NostrClient network monitoring initialized")
    }
    
    private func setupPeriodicHealthCheck() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performHealthCheck()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Enhanced Connection Management
    
    func connect() {
        guard connectionStatus != .connecting else { return }
        
        connectionStatus = .connecting
        networkHealth = .connecting
        
        // Clear any existing state
        clearReconnectionTimers()
        
        // Connect to relays by priority
        let sortedRelays = defaultRelays.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        for relayInfo in sortedRelays {
            connectToRelay(relayInfo)
        }
        
        // Set connection timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + connectionTimeout) {
            self.checkInitialConnectionStatus()
        }
    }
    
    func disconnect() {
        connectionStatus = .disconnecting
        clearReconnectionTimers()
        
        for (relayURL, socket) in webSockets {
            socket.cancel()
            relayStates[relayURL] = .disconnected
        }
        
        webSockets.removeAll()
        subscriptions.removeAll()
        relayStates.removeAll()
        messageQueue.removeAll()
        
        DispatchQueue.main.async {
            self.activeRelays.removeAll()
            self.isConnected = false
            self.connectionStatus = .disconnected
            self.networkHealth = .disconnected
            self.subscriptionCount = 0
        }
    }
    
    private func connectToRelay(_ relayInfo: RelayInfo) {
        guard let url = URL(string: relayInfo.url) else { return }
        
        // Skip if already connected or connecting
        if let state = relayStates[relayInfo.url],
           state == .connected || state == .connecting {
            return
        }
        
        relayStates[relayInfo.url] = .connecting
        
        let session = URLSession(configuration: .default)
        let webSocketTask = session.webSocketTask(with: url)
        
        webSockets[relayInfo.url] = webSocketTask
        webSocketTask.resume()
        
        // Initialize message queue for this relay
        if messageQueue[relayInfo.url] == nil {
            messageQueue[relayInfo.url] = []
        }
        
        // Start receiving messages
        receiveMessage(from: webSocketTask, relayURL: relayInfo.url)
        
        print("Connecting to relay: \(relayInfo.description)")
    }
    
    private func reconnectToRelay(_ relayURL: String, delay: TimeInterval = 5.0) {
        // Cancel existing reconnection timer
        reconnectionTimers[relayURL]?.invalidate()
        
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.attemptReconnection(relayURL)
        }
        
        reconnectionTimers[relayURL] = timer
        print("Scheduled reconnection to \(relayURL) in \(delay) seconds")
    }
    
    private func attemptReconnection(_ relayURL: String) {
        guard let relayInfo = defaultRelays.first(where: { $0.url == relayURL }) else { return }
        
        print("Attempting reconnection to \(relayURL)")
        connectToRelay(relayInfo)
    }
    
    private func clearReconnectionTimers() {
        for (_, timer) in reconnectionTimers {
            timer.invalidate()
        }
        reconnectionTimers.removeAll()
    }
    
    private func checkInitialConnectionStatus() {
        let connectedCount = activeRelays.count
        
        if connectedCount == 0 {
            DispatchQueue.main.async {
                self.connectionStatus = .disconnected
                self.networkHealth = .poor
            }
        } else if connectedCount < defaultRelays.count / 2 {
            DispatchQueue.main.async {
                self.connectionStatus = .connected
                self.networkHealth = .poor
            }
        } else {
            DispatchQueue.main.async {
                self.connectionStatus = .connected
                self.networkHealth = .good
            }
        }
    }
    
    // MARK: - URLSession WebSocket Implementation
    
    private func receiveMessage(from webSocketTask: URLSessionWebSocketTask, relayURL: String) {
        webSocketTask.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text: text, relayURL: relayURL)
                case .data(let data):
                    print("Received binary data from \(relayURL): \(data.count) bytes")
                @unknown default:
                    break
                }
                // Continue receiving messages
                self?.receiveMessage(from: webSocketTask, relayURL: relayURL)
                
            case .failure(let error):
                self?.handleError(error: error, relayURL: relayURL)
            }
        }
    }
    
    private func handleConnectionSuccess(relayURL: String) {
        
        relayStates[relayURL] = .connected
        
        // Create relay connection object
        let relayConnection = RelayConnection(
            url: relayURL,
            status: .connected,
            connectedAt: Date(),
            lastMessage: Date(),
            messageCount: 0,
            subscriptionCount: 0
        )
        
        DispatchQueue.main.async {
            // Remove existing entry and add updated one
            self.activeRelays.removeAll { $0.url == relayURL }
            self.activeRelays.append(relayConnection)
            self.isConnected = !self.activeRelays.isEmpty
            self.connectionStatus = .connected
            self.updateNetworkHealth()
        }
        
        print("✅ Connected to Nostr relay: \(relayURL)")
        
        // Process queued messages for this relay
        processQueuedMessages(for: relayURL)
        
        // Re-establish subscriptions for this relay
        reestablishSubscriptions(for: relayURL)
        
        // Cancel any pending reconnection timer
        reconnectionTimers[relayURL]?.invalidate()
        reconnectionTimers.removeValue(forKey: relayURL)
    }
    
    private func handleDisconnection(relayURL: String, reason: String, code: UInt16) {
        
        relayStates[relayURL] = .disconnected
        
        DispatchQueue.main.async {
            self.activeRelays.removeAll { $0.url == relayURL }
            self.isConnected = !self.activeRelays.isEmpty
            self.updateNetworkHealth()
            
            if self.activeRelays.isEmpty {
                self.connectionStatus = .disconnected
            }
        }
        
        print("❌ Disconnected from relay \(relayURL): \(reason) (code: \(code))")
        
        // Clean up WebSocket reference
        webSockets.removeValue(forKey: relayURL)
        
        // Schedule reconnection with exponential backoff
        let reconnectionDelay = calculateReconnectionDelay(for: relayURL)
        reconnectToRelay(relayURL, delay: reconnectionDelay)
    }
    
    private func handleMessage(text: String, relayURL: String) {
        // Update relay connection stats
        DispatchQueue.main.async {
            if let index = self.activeRelays.firstIndex(where: { $0.url == relayURL }) {
                self.activeRelays[index].lastMessage = Date()
                self.activeRelays[index].messageCount += 1
            }
        }
        
        do {
            if let data = text.data(using: .utf8),
               let jsonArray = try JSONSerialization.jsonObject(with: data) as? [Any] {
                try processNostrMessage(jsonArray, from: relayURL)
            }
        } catch {
            print("Error processing Nostr message from \(relayURL): \(error)")
        }
    }
    
    private func handleError(error: Error, relayURL: String) {
        relayStates[relayURL] = .error
        
        print("🚨 WebSocket error for \(relayURL): \(error.localizedDescription)")
        
        // Disconnect and attempt reconnection
        webSockets[relayURL]?.cancel()
        webSockets.removeValue(forKey: relayURL)
        
        let reconnectionDelay = calculateReconnectionDelay(for: relayURL)
        reconnectToRelay(relayURL, delay: reconnectionDelay)
    }
    

    

    
    // MARK: - Network Health Management
    
    private func updateNetworkHealth() {
        let connectedCount = activeRelays.count
        let totalRelays = defaultRelays.count
        
        if connectedCount == 0 {
            networkHealth = .poor
        } else if connectedCount < totalRelays / 2 {
            networkHealth = .fair
        } else if connectedCount >= totalRelays * 3 / 4 {
            networkHealth = .excellent
        } else {
            networkHealth = .good
        }
    }
    
    private func calculateReconnectionDelay(for relayURL: String) -> TimeInterval {
        // Exponential backoff with jitter
        let baseDelay: TimeInterval = 5.0
        let maxDelay = maxReconnectionDelay
        
        // Simple exponential backoff (could be enhanced with failure count tracking)
        let delay = min(baseDelay * pow(2.0, 1), maxDelay)
        let jitter = Double.random(in: 0.8...1.2)
        
        return delay * jitter
    }
    
    private func processQueuedMessages(for relayURL: String) {
        guard let queuedMessages = messageQueue[relayURL],
              !queuedMessages.isEmpty,
              let socket = webSockets[relayURL] else { return }
        
        print("📤 Processing \(queuedMessages.count) queued messages for \(relayURL)")
        
        for message in queuedMessages {
            let messageData = URLSessionWebSocketTask.Message.string(message)
            socket.send(messageData) { error in
                if let error = error {
                    print("Error sending queued message: \(error)")
                }
            }
        }
        
        messageQueue[relayURL] = []
    }
    
    private func reestablishSubscriptions(for relayURL: String) {
        guard let socket = webSockets[relayURL] else { return }
        
        print("🔄 Re-establishing subscriptions for \(relayURL)")
        
        for (subscriptionId, subscription) in subscriptions {
            let message = ["REQ", subscriptionId] + subscription.filters
            
            do {
                let messageJSON = try JSONSerialization.data(withJSONObject: message)
                let messageString = String(data: messageJSON, encoding: .utf8)!
                let messageData = URLSessionWebSocketTask.Message.string(messageString)
                socket.send(messageData) { error in
                    if let error = error {
                        print("Error sending subscription message: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    if let index = self.activeRelays.firstIndex(where: { $0.url == relayURL }) {
                        self.activeRelays[index].subscriptionCount += 1
                    }
                }
            } catch {
                print("Error re-establishing subscription \(subscriptionId): \(error)")
            }
        }
    }
    
    // MARK: - App State Handlers
    
    private func handleAppBecameActive() {
        print("📱 App became active - checking connections")
        performHealthCheck()
    }
    
    private func handleAppWillResignActive() {
        print("📱 App will resign active - maintaining connections")
        // Keep connections alive but reduce activity
    }
    
    private func performHealthCheck() {
        print("🏥 Performing network health check")
        
        let now = Date()
        var unhealthyRelays: [String] = []
        
        // Check for stale connections
        for relay in activeRelays {
            let timeSinceLastMessage = now.timeIntervalSince(relay.lastMessage)
            
            if timeSinceLastMessage > 60 { // No activity for 1 minute
                unhealthyRelays.append(relay.url)
            }
        }
        
        // Reconnect unhealthy relays
        for relayURL in unhealthyRelays {
            print("🔄 Reconnecting potentially stale relay: \(relayURL)")
            webSockets[relayURL]?.cancel()
            webSockets.removeValue(forKey: relayURL)
        }
        
        // Connect to disconnected high-priority relays
        let highPriorityRelays = defaultRelays.filter { $0.priority == .high }
        for relayInfo in highPriorityRelays {
            if relayStates[relayInfo.url] != .connected {
                connectToRelay(relayInfo)
            }
        }
        
        DispatchQueue.main.async {
            self.updateNetworkHealth()
        }
    }
    
    // MARK: - Message Processing
    
    private func processNostrMessage(_ jsonArray: [Any], from relayURL: String) throws {
        guard let messageType = jsonArray.first as? String else { return }
        
        switch messageType {
        case "EVENT":
            try handleEventMessage(jsonArray)
        case "OK":
            handleOKMessage(jsonArray)
        case "NOTICE":
            handleNoticeMessage(jsonArray)
        case "EOSE":
            handleEOSEMessage(jsonArray)
        default:
            print("Unknown message type: \(messageType)")
        }
    }
    
    private func handleEventMessage(_ jsonArray: [Any]) throws {
        guard jsonArray.count >= 3,
              let subscriptionId = jsonArray[1] as? String,
              let eventDict = jsonArray[2] as? [String: Any] else { return }
        
        let event = try NostrEvent.fromDictionary(eventDict)
        
        DispatchQueue.main.async {
            self.receivedEvents.append(event)
        }
        
        // Process specific event types
        try processEvent(event, subscriptionId: subscriptionId)
    }
    
    private func handleOKMessage(_ jsonArray: [Any]) {
        guard jsonArray.count >= 3,
              let eventId = jsonArray[1] as? String,
              let success = jsonArray[2] as? Bool else { return }
        
        print("Event \(eventId) \(success ? "accepted" : "rejected")")
    }
    
    private func handleNoticeMessage(_ jsonArray: [Any]) {
        if let notice = jsonArray[1] as? String {
            print("Relay notice: \(notice)")
        }
    }
    
    private func handleEOSEMessage(_ jsonArray: [Any]) {
        if let subscriptionId = jsonArray[1] as? String {
            print("End of stored events for subscription: \(subscriptionId)")
        }
    }
    
    // MARK: - Event Processing
    
    private func processEvent(_ event: NostrEvent, subscriptionId: String) throws {
        switch event.kind {
        case 1: // Text note
            try processTextNote(event)
        case 4: // Encrypted direct message
            try processEncryptedDM(event)
        case 1000: // Custom: Group invite
            try processGroupInvite(event)
        case 1001: // Custom: PSBT signing request
            try processPSBTRequest(event)
        case 1002: // Custom: Goal update
            try processGoalUpdate(event)
        default:
            print("Unhandled event kind: \(event.kind)")
        }
    }
    
    private func processTextNote(_ event: NostrEvent) throws {
        // Handle public text notes
        print("Text note from \(event.pubkey): \(event.content)")
    }
    
    private func processEncryptedDM(_ event: NostrEvent) throws {
        // Decrypt using NIP-44 encryption
        guard let userPrivateKey = try? getCurrentUserPrivateKey() else { return }
        
        let decryptedContent = try decryptDM(
            encryptedContent: event.content,
            senderPubkey: event.pubkey,
            recipientPrivateKey: userPrivateKey
        )
        
        print("Decrypted DM: \(decryptedContent)")
        // Store in encrypted local storage
    }
    
    private func processGroupInvite(_ event: NostrEvent) throws {
        // Handle group invitation
        print("Group invite received from \(event.pubkey)")
        // Parse invite details and present to user
    }
    
    private func processPSBTRequest(_ event: NostrEvent) throws {
        // Handle PSBT signing request
        print("PSBT signing request received")
        // Trigger notification for group members
        NotificationCenter.default.post(
            name: .psbtSigningRequired,
            object: event
        )
    }
    
    private func processGoalUpdate(_ event: NostrEvent) throws {
        // Handle goal progress update
        print("Goal update received")
    }
    
    // MARK: - Event Publishing
    
    func publishEvent(_ event: NostrEvent) {
        guard !activeRelays.isEmpty else {
            print("No active relays to publish event")
            return
        }
        
        do {
            let eventData = try event.toJSON()
            let message: [Any] = ["EVENT", eventData]
            let messageJSON = try JSONSerialization.data(withJSONObject: message)
            let messageString = String(data: messageJSON, encoding: .utf8)!
            
            // Send to all connected relays
            for (_, webSocketTask) in webSockets {
                let messageData = URLSessionWebSocketTask.Message.string(messageString)
                webSocketTask.send(messageData) { error in
                    if let error = error {
                        print("Error publishing event: \(error)")
                    }
                }
            }
            
        } catch {
            print("Error publishing event: \(error)")
        }
    }
    
    func publishTextNote(_ content: String) async throws {
        let userPrivateKey = try getCurrentUserPrivateKey()
        let event = try NostrEvent.createTextNote(
            content: content,
            privateKey: userPrivateKey
        )
        
        publishEvent(event)
    }
    
    func publishEncryptedDM(_ content: String, to recipientPubkey: String) async throws {
        let userPrivateKey = try getCurrentUserPrivateKey()
        
        let encryptedContent = try encryptDM(
            content: content,
            recipientPubkey: recipientPubkey,
            senderPrivateKey: userPrivateKey
        )
        
        let event = try NostrEvent.createEncryptedDM(
            encryptedContent: encryptedContent,
            recipientPubkey: recipientPubkey,
            privateKey: userPrivateKey
        )
        
        publishEvent(event)
    }
    
    func publishGroupInvite(_ groupData: GroupInviteData) async throws {
        let userPrivateKey = try getCurrentUserPrivateKey()
        let inviteJSON = try JSONEncoder().encode(groupData)
        let inviteString = String(data: inviteJSON, encoding: .utf8)!
        
        let event = try NostrEvent.createCustomEvent(
            kind: 1000,
            content: inviteString,
            privateKey: userPrivateKey
        )
        
        publishEvent(event)
    }
    
    // MARK: - Subscriptions
    
    private func subscribeToUserEvents() {
        guard let userPubkey = try? getCurrentUserPubkey() else { return }
        
        // Subscribe to mentions and DMs
        let subscription = NostrSubscription(
            id: "user_events",
            filters: [
                ["kinds": [1, 4], "#p": [userPubkey]],
                ["kinds": [1000, 1001, 1002], "#p": [userPubkey]]
            ]
        )
        
        subscribe(subscription)
    }
    
    func subscribeToGroupEvents(_ groupId: String) {
        let subscription = NostrSubscription(
            id: "group_\(groupId)",
            filters: [
                ["kinds": [1000, 1001, 1002], "#g": [groupId]]
            ]
        )
        
        subscribe(subscription)
    }
    
    private func subscribe(_ subscription: NostrSubscription) {
        subscriptions[subscription.id] = subscription
        
        let message = ["REQ", subscription.id] + subscription.filters
        
        do {
            let messageJSON = try JSONSerialization.data(withJSONObject: message)
            let messageString = String(data: messageJSON, encoding: .utf8)!
            
            for (_, webSocketTask) in webSockets {
                let messageData = URLSessionWebSocketTask.Message.string(messageString)
                webSocketTask.send(messageData) { error in
                    if let error = error {
                        print("Error subscribing: \(error)")
                    }
                }
            }
        } catch {
            print("Error subscribing: \(error)")
        }
    }
    
    // MARK: - Key Management
    
    private func getCurrentUserPrivateKey() throws -> String {
        // For MVP, use a default user ID
        // In production, this would be dynamically determined
        return try keychainManager.retrieveNostrPrivateKey(for: "default_user")
    }
    
    private func getCurrentUserPubkey() throws -> String {
        let privateKey = try getCurrentUserPrivateKey()
        return try derivePublicKey(from: privateKey)
    }
    
    // MARK: - Encryption (NIP-44 simplified for MVP)
    
    private func encryptDM(content: String, recipientPubkey: String, senderPrivateKey: String) throws -> String {
        // Simplified encryption for MVP
        // In production, use proper NIP-44 implementation
        return "encrypted_\(content.base64Encoded() ?? content)"
    }
    
    private func decryptDM(encryptedContent: String, senderPubkey: String, recipientPrivateKey: String) throws -> String {
        // Simplified decryption for MVP
        if encryptedContent.hasPrefix("encrypted_") {
            let base64Part = String(encryptedContent.dropFirst(10))
            return Data(base64Encoded: base64Part)?.string ?? encryptedContent
        }
        return encryptedContent
    }
    
    private func derivePublicKey(from privateKey: String) throws -> String {
        // Simplified for MVP - in production use secp256k1
        return "pubkey_from_\(privateKey.prefix(8))"
    }
}

// MARK: - Supporting Structures

struct NostrEvent: Codable {
    let id: String
    let pubkey: String
    let createdAt: Int64
    let kind: Int
    let tags: [[String]]
    let content: String
    let sig: String
    
    enum CodingKeys: String, CodingKey {
        case id, pubkey, kind, tags, content, sig
        case createdAt = "created_at"
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> NostrEvent {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(NostrEvent.self, from: data)
    }
    
    func toJSON() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    
    static func createTextNote(content: String, privateKey: String) throws -> NostrEvent {
        let now = Int64(Date().timeIntervalSince1970)
        let pubkey = try derivePublicKey(from: privateKey)
        
        return NostrEvent(
            id: generateEventId(),
            pubkey: pubkey,
            createdAt: now,
            kind: 1,
            tags: [],
            content: content,
            sig: "mock_signature"
        )
    }
    
    static func createEncryptedDM(encryptedContent: String, recipientPubkey: String, privateKey: String) throws -> NostrEvent {
        let now = Int64(Date().timeIntervalSince1970)
        let pubkey = try derivePublicKey(from: privateKey)
        
        return NostrEvent(
            id: generateEventId(),
            pubkey: pubkey,
            createdAt: now,
            kind: 4,
            tags: [["p", recipientPubkey]],
            content: encryptedContent,
            sig: "mock_signature"
        )
    }
    
    static func createCustomEvent(kind: Int, content: String, privateKey: String) throws -> NostrEvent {
        let now = Int64(Date().timeIntervalSince1970)
        let pubkey = try derivePublicKey(from: privateKey)
        
        return NostrEvent(
            id: generateEventId(),
            pubkey: pubkey,
            createdAt: now,
            kind: kind,
            tags: [],
            content: content,
            sig: "mock_signature"
        )
    }
    
    private static func generateEventId() -> String {
        return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
    
    private static func derivePublicKey(from privateKey: String) throws -> String {
        return "pubkey_from_\(privateKey.prefix(8))"
    }
}

struct NostrSubscription {
    let id: String
    let filters: [[String: Any]]
}

struct GroupInviteData: Codable {
    let groupId: String
    let groupName: String
    let threshold: Int
    let creatorPubkey: String
    let inviteCode: String
}

enum ConnectionStatus {
    case disconnected, connecting, connected, disconnecting
}

// MARK: - Notification Names

// MARK: - Supporting Data Structures

struct RelayInfo {
    let url: String
    let priority: RelayPriority
    let description: String
}

enum RelayPriority: Int {
    case high = 3
    case medium = 2
    case low = 1
}

struct RelayConnection: Identifiable {
    let id = UUID()
    let url: String
    var status: RelayConnectionStatus
    let connectedAt: Date
    var lastMessage: Date
    var messageCount: Int
    var subscriptionCount: Int
    
    var isHealthy: Bool {
        let timeSinceLastMessage = Date().timeIntervalSince(lastMessage)
        return status == .connected && timeSinceLastMessage < 60
    }
    
    var uptimePercentage: Double {
        let totalTime = Date().timeIntervalSince(connectedAt)
        return totalTime > 0 ? min(1.0, totalTime / 3600) : 0 // Based on 1 hour window
    }
}

enum RelayConnectionStatus {
    case connecting
    case connected
    case disconnected
    case error
    case unstable
}

enum RelayState {
    case disconnected
    case connecting
    case connected
    case error
    case unstable
}

enum NetworkHealth {
    case unknown
    case connecting
    case poor      // 0 connections
    case fair      // < 50% connections
    case good      // 50-75% connections  
    case excellent // > 75% connections
    case disconnected
    
    var color: Color {
        switch self {
        case .unknown, .connecting: return .gray
        case .poor, .disconnected: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .excellent: return .green
        }
    }
    
    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .connecting: return "Connecting..."
        case .poor: return "Poor Connection"
        case .fair: return "Fair Connection" 
        case .good: return "Good Connection"
        case .excellent: return "Excellent Connection"
        case .disconnected: return "Disconnected"
        }
    }
}

// Removed duplicate ConnectionStatus enum - already defined above

// MARK: - Enhanced Subscription Management

extension NostrClient {
    
    // subscribe function already defined in main class - removed duplicate
    
    func unsubscribe(_ subscriptionId: String) {
        subscriptions.removeValue(forKey: subscriptionId)
        
        let message = ["CLOSE", subscriptionId]
        
        do {
            let messageJSON = try JSONSerialization.data(withJSONObject: message)
            let messageString = String(data: messageJSON, encoding: .utf8)!
            
            for (_, webSocketTask) in webSockets {
                let messageData = URLSessionWebSocketTask.Message.string(messageString)
                webSocketTask.send(messageData) { error in
                    if let error = error {
                        print("Error closing subscription: \(error)")
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.subscriptionCount = self.subscriptions.count
            }
            
        } catch {
            print("Error closing subscription: \(error)")
        }
    }
    
    /// Subscribe to events for a specific group with enhanced filtering
    func subscribeToGroupEvents(_ groupId: String, eventKinds: [Int] = [1000, 1001, 1002, 1003, 1004, 1005]) {
        let subscription = NostrSubscription(
            id: "group_\(groupId)",
            filters: [
                ["kinds": eventKinds, "#g": [groupId]],
                ["kinds": eventKinds, "#t": ["satsat", "group:\(groupId)"]]
            ]
        )
        
        subscribe(subscription)
    }
    
    // subscribeToUserEvents function already defined in main class - removed duplicate
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let psbtSigningRequired = Notification.Name("psbtSigningRequired")
    static let groupInviteReceived = Notification.Name("groupInviteReceived")
    static let goalUpdateReceived = Notification.Name("goalUpdateReceived")
    static let nostrRelayConnected = Notification.Name("nostrRelayConnected")
    static let nostrRelayDisconnected = Notification.Name("nostrRelayDisconnected")
    static let nostrNetworkHealthChanged = Notification.Name("nostrNetworkHealthChanged")
}

// MARK: - Extensions

extension String {
    func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }
}

extension Data {
    var string: String {
        return String(data: self, encoding: .utf8) ?? ""
    }
}