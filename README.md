# Satsat - Bitcoin Group Savings App

A revolutionary iOS app for collaborative Bitcoin savings with trusted friends using multisig wallets and Nostr protocol.

## 🚀 **Project Status: ACTIVE DEVELOPMENT**

✅ **Build Status**: SUCCESSFUL  
✅ **All Compilation Errors**: RESOLVED  
✅ **UI/UX Styling**: COMPLETE  
✅ **Core Features**: IMPLEMENTING
🔄 **BDK Integration**: COMING TOMORROW

---

## 🎯 **Core Features**

### **Bitcoin & Lightning**

- **Multisig Wallets**: 2-of-3, 3-of-5 configurations with threshold signing
- **PSBT Coordination**: Advanced transaction signing with member coordination
- **Lightning Network**: NWC (Nostr Wallet Connect) integration for instant deposits
- **Address Generation**: Secure Bitcoin address generation and validation
- **Fee Management**: Dynamic fee calculation with RBF support

### **Nostr Integration**

- **End-to-End Encryption**: NIP-44 compliant encrypted group messaging
- **Group Coordination**: Custom event types (1000-1009) for group activities
- **Invite System**: QR-based group invitations with expiration controls
- **Multi-Relay Support**: Redundant relay connections with auto-failover

### **Security & Privacy**

- **Two-Tier Encryption**: AES-256-GCM with HKDF key derivation
- **iOS Keychain**: Hardware-backed secure key storage
- **Optional Biometrics**: Face ID/Touch ID with passcode fallback
- **Zero Knowledge**: No custody or control of user funds

### **Professional UI/UX**

- **Modern Dark Theme**: Professional dark mode interface with consistent styling
- **Real-time Updates**: Live balance and progress tracking
- **Push Notifications**: Smart milestone and signing alerts
- **QR Code Integration**: Camera scanning and generation
- **Import Key Flow**: Streamlined hardware wallet key import with QR/Manual options

---

## 🏗️ **Architecture Overview**

```
Satsat/
├── Core/
│   ├── Security/          # Encryption, Keychain, Biometrics
│   ├── Bitcoin/           # Multisig, PSBT, Address Management
│   ├── Lightning/         # NWC Integration, Invoice Generation
│   ├── Nostr/            # Client, Encryption, Event Management
│   ├── Data/             # Core Data, Encrypted Storage
│   └── UI/               # Design System, Components
├── Features/
│   ├── Groups/           # Group Creation, Management
│   ├── Wallet/           # Send, Receive, Balance Views
│   ├── Lightning/        # Lightning Deposits, NWC Connection
│   ├── PSBT/            # Transaction Signing, Coordination
│   └── Compliance/       # App Store Compliance, Onboarding
├── Services/
│   ├── GroupManager/     # Group Lifecycle Management
│   ├── MessageManager/   # Encrypted Messaging
│   └── NotificationService/ # Push Notifications
└── Testing/
    └── ComprehensiveTestSuite/ # 30+ Automated Tests
```

---

## 🔐 **Security Implementation**

### **Encryption**

- **Personal Data**: User-specific AES-256-GCM encryption
- **Group Data**: Shared encryption for financial coordination
- **Context-Specific Keys**: HKDF key derivation for data isolation
- **Hardware Security**: iOS Keychain with Secure Enclave protection

### **Bitcoin Security**

- **Multisig Standards**: BIP-48 derivation paths, P2WSH scripts
- **PSBT Workflow**: Secure transaction signing and coordination
- **Network Security**: Testnet/mainnet support with proper validation
- **Key Management**: Hardware-backed private key storage

---

## ⚡ **Lightning Network Integration**

### **NWC (Nostr Wallet Connect) Primary**

- **Zero Custody**: Users connect their own Lightning wallets
- **Universal Support**: Alby, Zeus, Mutiny, phoenixd, LNbits, Voltage
- **Group Contributions**: Lightning invoices for group goal funding
- **Perfect Compliance**: No custodial Lightning infrastructure

### **Fallback Strategy**

- **Onchain Only**: Users without Lightning wallets use Bitcoin only
- **No Shared Infrastructure**: Complete privacy between deployments
- **Educational Positioning**: App Store compliant educational tool

---

## 📱 **App Store Compliance**

### **Educational Positioning**

- **Learning Tool**: Positioned as Bitcoin education platform
- **External Service Links**: Proper linking to licensed Bitcoin services
- **Risk Disclosures**: Comprehensive financial risk warnings
- **Age Restriction**: 17+ with mandatory age verification

- **No Custodial Services**: Users manage their own keys and funds
- **External Service Integration**: Strike, Coinbase, and other exchanges
- **Compliance Documentation**: Complete regulatory compliance package
- **Privacy-First Design**: Zero data collection beyond app functionality

### **Technical Compliance**

- **iOS 18.5+ Support**: Latest iOS features and security
- **App Store Guidelines**: Full compliance with Apple's requirements
- **Privacy Manifest**: Complete privacy transparency
- **Security Best Practices**: Enterprise-grade security implementation

---

## 🎨 **UI/UX Design System**

### **Dark Theme Consistency**

- **Background Colors**: `backgroundPrimary` (black), `backgroundSecondary` (dark gray)
- **Text Colors**: White text with proper contrast ratios
- **Accent Colors**: Orange (`#FF9500`) for primary actions
- **Component Styling**: Consistent rounded corners and spacing

### **Key UI Components**

- **Wallet Cards**: Black background with orange borders
- **Search Bars**: Dark gray background with white text
- **Import Key Flow**: Streamlined QR/Manual options
- **Receive View**: Clean interface with address display and copy functionality

---

### **Coming Tomorrow**

- 🔄 **BDK Integration**: Bitcoin Development Kit for enhanced wallet functionality
- 🔄 **Advanced Transaction Features**: Improved PSBT handling
- 🔄 **Performance Optimizations**: Faster wallet operations

---

## 🛠️ **Development Setup**

### **Requirements**

- **Xcode 16+**: Latest Xcode version
- **iOS 18.5+**: Target iOS version
- **Swift 5.9+**: Latest Swift language features
- **macOS 14+**: Required for development

### **Build Instructions**

```bash
# Clone the repository
git clone https://github.com/yourusername/satsat.git
cd satsat

# Open in Xcode
open Satsat.xcodeproj

# Build and run
# Use Xcode's build system for development
```

### **Configuration**

- **Bundle Identifier**: `SatsNot.Bits`
- **Development Team**: Configure in Xcode
- **Signing**: Automatic signing for development

---

## 📄 **License**

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Built with ❤️ for the Bitcoin community**
