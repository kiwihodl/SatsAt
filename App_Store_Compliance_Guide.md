# App Store Compliance Guide for Bitcoin Apps

## 🏪 Navigating App Store Guidelines for Satsat

Based on research into recent App Store rejections and approvals for Bitcoin/crypto apps, here's a comprehensive compliance strategy.

## Critical App Store Guidelines

### Guideline 3.1.1 - In-App Purchases
**"Apps may not use their own mechanisms to unlock content or functionality, such as license keys, augmented reality markers, QR codes, cryptocurrencies and cryptocurrency wallets, etc."**

### Guideline 3.1.5 - Cryptocurrencies
**"Apps may facilitate transactions or transmissions of cryptocurrency on an approved exchange, provided they are offered only in countries or regions where the app has appropriate licensing and permissions to provide a cryptocurrency exchange."**

## 🚨 Common Rejection Patterns

### Apps That Have Been Rejected:
- **Coinbase Wallet**: Blocked for requiring gas fees via IAP for NFT transfers
- **1inch**: Rejected for direct marketplace links and "Buy" language
- **OpenSea iOS**: Removed ability to purchase NFTs directly
- **Magic Eden**: Required to clearly state NFTs are in "third-party services"

### Successful Strategies:
- **Educational positioning** over transactional
- **External web linking** instead of in-app purchases
- **Clear disclaimers** about third-party services
- **Viewing-only** features for assets

## ✅ Compliance Strategy for Satsat

### 1. App Positioning
Position as an **educational savings app** rather than a financial product:

```
PRIMARY MESSAGING:
"Learn Bitcoin savings with friends through collaborative goals"

AVOID:
- "Buy Bitcoin"
- "Trade cryptocurrency" 
- "Exchange" or "wallet" in primary description

USE INSTEAD:
- "Educational Bitcoin experience"
- "Collaborative savings goals"
- "Learn about multisig security"
- "Practice Bitcoin concepts"
```

### 2. Feature Implementation

#### ✅ Allowed Features:
- **Receive-only addresses** (viewing deposits)
- **Goal tracking** (progress monitoring)
- **Educational content** (how multisig works)
- **Group messaging** (encrypted chat)
- **Transaction viewing** (read-only)
- **PSBT sharing** (file export/import)

#### ⚠️ Restricted Features:
- **No in-app Bitcoin purchasing**
- **No direct exchange integration**
- **No gas fee payments via IAP**
- **No "Buy" buttons or language**

#### 🔄 Workaround Implementations:

```swift
// ✅ COMPLIANT: External web linking
func openExternalExchange() {
    let url = URL(string: "https://strike.me")!
    UIApplication.shared.open(url)
}

// ❌ NON-COMPLIANT: In-app purchase
func buyBitcoinInApp() {
    // This would violate 3.1.1
    SKPaymentQueue.default().add(payment)
}

// ✅ COMPLIANT: Educational explanation
Text("To add Bitcoin to your group savings, use external apps like Strike or Cash App, then send to the address below.")

// ❌ NON-COMPLIANT: Direct purchasing
Button("Buy Bitcoin") { /* opens in-app purchase */ }
```

### 3. App Store Description Template

```markdown
📱 Satsat - Bitcoin Savings Education

Learn about Bitcoin and collaborative savings through hands-on experience with friends and family.

🎯 EDUCATIONAL FEATURES:
• Create learning groups with 2-9 trusted friends
• Set collaborative Bitcoin savings goals  
• Understand multisig wallet security
• Practice transaction coordination
• Learn about Bitcoin addresses and keys

🔐 SECURITY EDUCATION:
• Hands-on multisig wallet experience
• PSBT (transaction) signing practice
• Encrypted group communication
• Key management fundamentals

📚 LEARNING OBJECTIVES:
• Understand Bitcoin wallet technology
• Experience collaborative financial planning
• Learn about cryptocurrency security
• Practice responsible savings habits

⚠️ IMPORTANT DISCLAIMERS:
• Educational tool for learning purposes
• Does not provide financial advice
• Bitcoin involves significant financial risk
• Only use amounts you can afford to lose
• Users responsible for obtaining Bitcoin elsewhere

This app teaches Bitcoin concepts through practical experience. To obtain Bitcoin, users must use external licensed services.

Ages 17+ due to financial themes.
```

### 4. User Flow Compliance

#### Onboarding Flow:
```swift
struct ComplianceOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Educational Purpose")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Satsat is designed for learning about Bitcoin and collaborative savings. This app does not sell or exchange Bitcoin.")
                .multilineTextAlignment(.center)
            
            Text("To obtain Bitcoin, you'll need to use external licensed services like Strike, Cash App, or Coinbase.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("I Understand") {
                // Proceed to app
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

#### Receiving Bitcoin Flow:
```swift
struct ReceiveView: View {
    @State private var address = "bc1q..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Group Savings Address")
                .font(.headline)
            
            // ✅ COMPLIANT: Educational explanation
            Text("This is your group's multisig Bitcoin address. To add Bitcoin to your savings goal, send from external apps like:")
                .multilineTextAlignment(.center)
            
            HStack {
                ExternalAppButton(name: "Strike", url: "https://strike.me")
                ExternalAppButton(name: "Cash App", url: "https://cash.app")
                ExternalAppButton(name: "Coinbase", url: "https://coinbase.com")
            }
            
            QRCodeView(data: address)
            
            CopyableText(address)
            
            // ✅ COMPLIANT: Educational disclaimer
            Text("Note: This app cannot purchase Bitcoin. Use licensed external services.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ExternalAppButton: View {
    let name: String
    let url: String
    
    var body: some View {
        Button(name) {
            UIApplication.shared.open(URL(string: url)!)
        }
        .buttonStyle(.bordered)
    }
}
```

### 5. PSBT Handling Compliance

```swift
// ✅ COMPLIANT: File-based PSBT sharing
struct PSBTSigningView: View {
    @State private var psbtData: Data?
    
    var body: some View {
        VStack {
            Text("Transaction Signing Practice")
                .font(.headline)
            
            Text("Learn how Bitcoin transactions require multiple signatures in a multisig wallet.")
                .multilineTextAlignment(.center)
            
            if let psbt = psbtData {
                ShareLink(
                    item: psbt,
                    preview: SharePreview("Bitcoin Transaction", image: Image(systemName: "bitcoinsign.circle"))
                ) {
                    Label("Export Transaction", systemImage: "square.and.arrow.up")
                }
            }
            
            Text("Educational Note: In a real scenario, you would sign this transaction with a hardware wallet or secure software.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

### 6. Messaging Compliance

```swift
// ✅ COMPLIANT: Educational group chat
struct GroupChatView: View {
    var body: some View {
        VStack {
            Text("Encrypted Group Communication")
                .font(.headline)
            
            Text("Learn about secure messaging in financial coordination.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Standard messaging UI
            MessageListView()
            MessageInputView()
            
            Text("Educational: This demonstrates secure communication for financial coordination.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

## 📋 Pre-Submission Checklist

### Required Elements:
- [ ] No "Buy", "Sell", "Trade" language in UI
- [ ] Clear educational disclaimers throughout
- [ ] External links for Bitcoin acquisition
- [ ] No in-app Bitcoin purchases
- [ ] No direct exchange integrations
- [ ] Age rating 17+ for financial themes
- [ ] Privacy policy covering Bitcoin data
- [ ] Terms of service with risk disclaimers

### App Review Notes Template:
```
REVIEWER NOTES:

Educational Purpose:
This app teaches Bitcoin multisig concepts through hands-on learning groups. Users create collaborative savings goals to understand Bitcoin security and transaction coordination.

No Financial Services:
- Does not buy, sell, or exchange Bitcoin
- Does not provide investment advice
- All Bitcoin acquisition happens via external licensed services
- App serves educational and coordination purposes only

Compliance with 3.1.1:
- No in-app purchases for Bitcoin or cryptocurrency
- External links to licensed Bitcoin services (Strike, Cash App, Coinbase)
- PSBT transactions handled via file sharing, not in-app purchasing

Target Audience:
Adults (17+) interested in learning Bitcoin technology through practical group experience.

External Dependencies:
Users must obtain Bitcoin from licensed external services. App coordinates but does not facilitate purchases.
```

### 7. Alternative Distribution Considerations

If App Store approval proves difficult:

#### Option A: TestFlight Beta
- Distribute via TestFlight for educational testing
- Gather user feedback and compliance data
- Refine for full App Store submission

#### Option B: Progressive Web App (PWA)
- Build Safari-compatible web version
- Full functionality without App Store restrictions
- Direct installation via Safari

#### Option C: Enterprise Distribution
- If targeting institutional users
- Bypass App Store for corporate/educational use

### 8. Legal Considerations

#### Required Disclaimers:
```swift
struct LegalDisclaimersView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            DisclaimerSection(
                title: "Educational Purpose",
                content: "This app is designed for educational purposes only. It does not provide financial advice or investment recommendations."
            )
            
            DisclaimerSection(
                title: "Risk Warning", 
                content: "Bitcoin and cryptocurrency investments carry significant financial risk. Never invest more than you can afford to lose."
            )
            
            DisclaimerSection(
                title: "No Financial Services",
                content: "This app does not buy, sell, or exchange Bitcoin. Users must obtain Bitcoin from licensed external services."
            )
            
            DisclaimerSection(
                title: "External Services",
                content: "Users are responsible for compliance with terms of external Bitcoin services and applicable laws in their jurisdiction."
            )
        }
    }
}
```

## 🎯 Success Metrics for Approval

### App Store Review Success Factors:
1. **Clear educational positioning** from first launch
2. **No ambiguous financial language** in UI/description  
3. **External service integration** via web links only
4. **Proper risk disclaimers** throughout experience
5. **17+ age rating** with appropriate content warnings
6. **Privacy policy** covering Bitcoin address handling
7. **Terms of service** with comprehensive risk disclosure

### Post-Approval Maintenance:
- Monitor for guideline changes
- Regular compliance audits
- User feedback on educational value
- Documentation of educational outcomes

This compliance strategy maximizes approval chances while maintaining core functionality through careful positioning and external service integration.