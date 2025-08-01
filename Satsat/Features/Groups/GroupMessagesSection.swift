// GroupMessagesSection.swift
// Group messaging interface under the progress bar

import SwiftUI
import Foundation

struct GroupMessagesSection: View {
    let group: SavingsGroup
    @EnvironmentObject var messageManager: MessageManager
    @State private var newMessage = ""
    @State private var showingAllMessages = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: SatsatDesignSystem.Spacing.sm) {
            // Section header
            HStack {
                Text("Group Chat")
                    .font(SatsatDesignSystem.Typography.headline)
                    .foregroundColor(SatsatDesignSystem.Colors.textPrimary)
                
                Spacer()
                
                                    Button("View All") {
                        showingAllMessages = true
                    }
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(.blue)
            }
            
            // Recent messages (last 3)
            if let recentMessages = messageManager.groupMessages[group.id]?.suffix(3) {
                ForEach(Array(recentMessages), id: \.id) { message in
                    MessageBubble(message: message)
                }
            } else {
                Text("No messages yet")
                    .font(SatsatDesignSystem.Typography.caption)
                    .foregroundColor(SatsatDesignSystem.Colors.textSecondary)
                    .padding(.vertical, 8)
            }
            
            // Message input
            HStack(spacing: SatsatDesignSystem.Spacing.sm) {
                TextField("Type a message...", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(newMessage.isEmpty ? .gray : .blue)
                }
                .disabled(newMessage.isEmpty)
            }
        }
        .sheet(isPresented: $showingAllMessages) {
            GroupChatView(group: group)
                .environmentObject(messageManager)
        }
    }
    
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        Task {
            do {
                try await messageManager.sendMessage(newMessage, to: group.id)
                await MainActor.run {
                    newMessage = ""
                }
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
}

// MessageBubble and GroupChatView structs moved to ContentView.swift to avoid duplication