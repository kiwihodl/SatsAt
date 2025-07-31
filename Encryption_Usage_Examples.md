# Satsat Encryption Usage Examples

## Real-World Implementation of Two-Tier Encryption

Based on your Seed-E encryption approach, here's how the encryption works in practice for Satsat's specific requirements.

## 🔑 Key Requirements Addressed

1. **Users encrypted** - Personal data only user can access
2. **Messages encrypted** - Private messaging between users  
3. **Extended public keys in database** - Group-shared, encrypted but all members can decrypt
4. **Database snooping prevention** - No plaintext sensitive data
5. **Group access to xpubs** - For balance/goal tracking and contribution monitoring

## 📋 Usage Examples

### 1. Creating a New Group (Group Creator)

```swift
// GroupCreationService.swift
class GroupCreationService {
    private let encryptionManager = SatsatEncryptionManager.shared
    private let groupService = EncryptedGroupService(context: persistentContainer.viewContext)
    private let nostrClient = NostrClient.shared
    
    func createGroup(name: String, members: [Member], threshold: Int, goal: UInt64) async throws -> String {
        let groupId = UUID().uuidString
        
        // 1. Generate group master key (shared among all members)
        let groupMasterKey = encryptionManager.generateGroupMasterKey()
        try encryptionManager.storeGroupMasterKey(groupMasterKey, for: groupId)
        
        // 2. Create member xpub data (all members need this)
        let memberXpubData = try members.map { member in
            MemberXpubData(
                memberId: member.id,
                memberName: member.name,
                xpub: member.extendedPublicKey, // This is what everyone needs to see
                derivationPath: member.derivationPath,
                joinedAt: Date()
            )
        }
        
        // 3. Encrypt and store group xpubs (group-shared encryption)
        try groupService.storeGroupXpubs(memberXpubData, groupId: groupId)
        
        // 4. Create initial goal data (group-shared)
        let goalData = GroupBalanceData(
            totalBalance: 0,
            goalAmount: goal,
            contributions: [:],
            lastUpdated: Date()
        )
        try groupService.storeGroupBalances(goalData, groupId: groupId)
        
        // 5. Share group master key with all members via Nostr
        let memberPubkeys = members.map { $0.nostrPubkey }
        let encryptedKeys = try encryptionManager.shareGroupKeyViaNostr(
            groupKey: groupMasterKey,
            memberPubkeys: memberPubkeys,
            senderPrivkey: nostrClient.keys.privateKeyHex
        )
        
        // 6. Send encrypted group keys via Nostr DMs
        for (memberPubkey, encryptedKey) in encryptedKeys {
            try await sendGroupInvite(
                groupId: groupId,
                memberPubkey: memberPubkey,
                encryptedGroupKey: encryptedKey
            )
        }
        
        return groupId
    }
}
```

### 2. Joining a Group (Invited Member)

```swift
// GroupJoinService.swift
class GroupJoinService {
    private let encryptionManager = SatsatEncryptionManager.shared
    private let groupService = EncryptedGroupService(context: persistentContainer.viewContext)
    
    func handleGroupInvite(inviteEvent: NostrEvent) throws {
        // 1. Decrypt the group master key from Nostr DM
        guard let encryptedGroupKey = extractEncryptedGroupKey(from: inviteEvent) else {
            throw GroupError.invalidInvite
        }
        
        let groupId = extractGroupId(from: inviteEvent)
        
        // 2. Decrypt and store the group master key
        try encryptionManager.receiveGroupKeyFromNostr(
            encryptedKey: encryptedGroupKey,
            senderPubkey: inviteEvent.pubkey,
            recipientPrivkey: nostrClient.keys.privateKeyHex,
            groupId: groupId
        )
        
        // 3. Now I can access group-shared data!
        let groupXpubs = try groupService.loadGroupXpubs(groupId: groupId)
        let balanceData = try groupService.loadGroupBalances(groupId: groupId)
        
        print("Successfully joined group with \(groupXpubs.count) members")
        print("Group goal: \(balanceData.goalAmount) sats")
        
        // 4. Update local group list
        try updateLocalGroupList(groupId: groupId, memberData: groupXpubs)
    }
}
```

### 3. Checking Group Balance & Contributions

```swift
// BalanceMonitorService.swift
class BalanceMonitorService {
    private let groupService = EncryptedGroupService(context: persistentContainer.viewContext)
    
    func updateGroupBalance(groupId: String) async throws {
        // 1. Load encrypted xpubs (all group members can decrypt this)
        let memberXpubs = try groupService.loadGroupXpubs(groupId: groupId)
        
        var totalBalance: UInt64 = 0
        var contributions: [String: UInt64] = [:]
        
        // 2. Query blockchain for each member's contributions
        for memberData in memberXpubs {
            let balance = try await queryBlockchainBalance(xpub: memberData.xpub)
            contributions[memberData.memberId] = balance
            totalBalance += balance
        }
        
        // 3. Update group balance data (encrypted, group-shared)
        let updatedBalanceData = GroupBalanceData(
            totalBalance: totalBalance,
            goalAmount: currentGoal,
            contributions: contributions,
            lastUpdated: Date()
        )
        
        try groupService.storeGroupBalances(updatedBalanceData, groupId: groupId)
        
        // 4. Notify group if goal reached
        if totalBalance >= currentGoal {
            try await notifyGroupGoalReached(groupId: groupId, amount: totalBalance)
        }
    }
    
    private func queryBlockchainBalance(xpub: String) async throws -> UInt64 {
        // Query blockchain API (Mempool.space, BlockCypher, etc.)
        // Return balance for this extended public key
        return 50_000 // Placeholder
    }
}
```

### 4. Private Messaging (User-Only Encryption)

```swift
// MessagingService.swift
class MessagingService {
    private let userService = EncryptedUserService(context: persistentContainer.viewContext)
    private let encryptionManager = SatsatEncryptionManager.shared
    
    func sendPrivateMessage(content: String, to recipient: String, groupId: String) throws {
        let messageId = UUID().uuidString
        
        // 1. Create message data
        let messageData = UserMessageData(
            messageId: messageId,
            content: content,
            sender: currentUserId,
            timestamp: Date(),
            groupId: groupId
        )
        
        // 2. Encrypt with USER-specific key (only sender can decrypt later)
        try userService.storeUserMessage(messageData)
        
        // 3. Send via Nostr with NIP-44 encryption
        try nostrClient.sendGroupMessage(content, to: [recipient])
        
        print("Message encrypted and sent")
    }
    
    func loadMyMessages(groupId: String) throws -> [UserMessageData] {
        // Only I can decrypt my messages
        return try userService.loadUserMessages(userId: currentUserId)
            .filter { $0.groupId == groupId }
    }
}
```

### 5. PSBT Signing with Encrypted Data

```swift
// PSBTSigningService.swift
class PSBTSigningService {
    private let groupService = EncryptedGroupService(context: persistentContainer.viewContext)
    
    func createPSBT(groupId: String, toAddress: String, amount: UInt64) throws -> String {
        // 1. Load group xpubs (encrypted but accessible to all members)
        let memberXpubs = try groupService.loadGroupXpubs(groupId: groupId)
        let balanceData = try groupService.loadGroupBalances(groupId: groupId)
        
        // 2. Verify we have enough funds
        guard balanceData.totalBalance >= amount else {
            throw TransactionError.insufficientFunds
        }
        
        // 3. Create multisig PSBT using the xpub data
        let psbt = try createMultisigPSBT(
            xpubs: memberXpubs.map { $0.xpub },
            toAddress: toAddress,
            amount: amount
        )
        
        // 4. Share PSBT via Nostr (encrypted)
        try sharePSBTWithGroup(psbt: psbt, groupId: groupId)
        
        return psbt
    }
}
```

## 🔍 Database Privacy Analysis

### What Database Admin Sees:
```sql
-- EncryptedGroupData table
SELECT groupId, dataType, encryptedData FROM EncryptedGroupData;
/*
Results:
group123 | xpubs    | 0x8a7b9c2d... (encrypted blob)
group123 | balances | 0x1f4e8b3a... (encrypted blob)  
group123 | goals    | 0x9d2c7f1e... (encrypted blob)
*/

-- EncryptedUserData table  
SELECT userId, dataType, encryptedData FROM EncryptedUserData;
/*
Results:
user456 | messages | 0x3c8f2a1b... (encrypted blob)
user456 | notes    | 0x7e1d9c4a... (encrypted blob)
*/
```

### What Database Admin CANNOT See:
- ❌ Extended public keys (xpubs)
- ❌ Bitcoin addresses
- ❌ Transaction amounts
- ❌ User messages
- ❌ Group member names
- ❌ Savings goals
- ❌ Individual contributions

### What Group Members CAN See (with group key):
- ✅ All member xpubs
- ✅ Total group balance  
- ✅ Individual contributions
- ✅ Savings goals and progress
- ✅ Group transaction history

### What Only Individual User Can See (with personal key):
- ✅ Their own private messages
- ✅ Their own private keys
- ✅ Their personal notes

## 🔐 Security Benefits

### Seed-E Pattern Advantages:
1. **Context Separation**: Different data types use different derived keys
2. **Key Rotation Ready**: Version field supports future key updates
3. **Authenticated Encryption**: AES-GCM provides integrity verification
4. **PBKDF2 Hardening**: 100,000 iterations protect against brute force
5. **Group Key Sharing**: Secure distribution via Nostr NIP-44

### Privacy Guarantees:
- **Database Admin**: Sees only encrypted blobs
- **Group Members**: See shared financial data only
- **Individual Users**: Full access to personal data only
- **External Observers**: Zero access to any sensitive data

This implementation follows your Seed-E encryption pattern while solving the specific challenge of group-shared financial data (xpubs, balances) versus personal private data (messages, keys).