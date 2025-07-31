// UInt64+Extensions.swift
// Extensions for UInt64 to handle Bitcoin satoshi formatting

import Foundation

extension UInt64 {
    /// Format satoshis as a readable Bitcoin amount
    var formattedSats: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        
        if self == 0 {
            return "0 sats"
        } else if self < 1000 {
            return "\(self) sats"
        } else if self < 100_000_000 {
            // Less than 1 Bitcoin - show as sats with commas
            let formatted = numberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
            return "\(formatted) sats"
        } else {
            // 1 Bitcoin or more - show as BTC
            let btc = Double(self) / 100_000_000.0
            
            if btc >= 1.0 {
                return String(format: "₿%.8f", btc).trimmingZeros()
            } else {
                // Less than 1 BTC but more than 100M sats
                let formatted = numberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
                return "\(formatted) sats"
            }
        }
    }
    
    /// Format as Bitcoin with symbol
    var formattedBTC: String {
        let btc = Double(self) / 100_000_000.0
        return String(format: "₿%.8f", btc).trimmingZeros()
    }
    
    /// Format as raw satoshis with commas
    var formattedSatsOnly: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = ","
        
        let formatted = numberFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
        return "\(formatted) sats"
    }
}

extension String {
    /// Remove trailing zeros from decimal strings
    func trimmingZeros() -> String {
        if self.contains(".") {
            return self.replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
        }
        return self
    }
}

extension Double {
    /// Format as Bitcoin amount
    var formattedBTC: String {
        return String(format: "₿%.8f", self).trimmingZeros()
    }
}

// MARK: - Bitcoin Unit Conversion

enum BitcoinUnit: String, CaseIterable {
    case satoshis = "sats"
    case bitcoin = "BTC"
    case millisats = "msats"
    
    var displayName: String {
        switch self {
        case .satoshis: return "Satoshis"
        case .bitcoin: return "Bitcoin"
        case .millisats: return "Millisatoshis"
        }
    }
    
    var symbol: String {
        switch self {
        case .satoshis: return "sats"
        case .bitcoin: return "₿"
        case .millisats: return "msats"
        }
    }
    
    func convertFrom(_ amount: UInt64, unit: BitcoinUnit) -> Double {
        switch (unit, self) {
        case (.satoshis, .bitcoin):
            return Double(amount) / 100_000_000.0
        case (.bitcoin, .satoshis):
            return Double(amount) * 100_000_000.0
        case (.satoshis, .millisats):
            return Double(amount) * 1000.0
        case (.millisats, .satoshis):
            return Double(amount) / 1000.0
        case (.bitcoin, .millisats):
            return Double(amount) * 100_000_000_000.0
        case (.millisats, .bitcoin):
            return Double(amount) / 100_000_000_000.0
        default:
            return Double(amount)
        }
    }
}

// MARK: - Bitcoin Amount Helper

struct BitcoinAmount {
    let sats: UInt64
    
    init(sats: UInt64) {
        self.sats = sats
    }
    
    init(btc: Double) {
        self.sats = UInt64(btc * 100_000_000)
    }
    
    var btc: Double {
        return Double(sats) / 100_000_000.0
    }
    
    var formattedSats: String {
        return sats.formattedSats
    }
    
    var formattedBTC: String {
        return btc.formattedBTC
    }
    
    func formatted(unit: BitcoinUnit) -> String {
        switch unit {
        case .satoshis:
            return formattedSats
        case .bitcoin:
            return formattedBTC
        case .millisats:
            return "\(sats * 1000) msats"
        }
    }
}

// MARK: - Extension for String to UInt64 Bitcoin parsing

extension String {
    /// Parse string as Bitcoin amount and return satoshis
    var parsedAsBitcoin: UInt64? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common suffixes
        let cleanString = trimmed
            .replacingOccurrences(of: " sats", with: "")
            .replacingOccurrences(of: " sat", with: "")
            .replacingOccurrences(of: " BTC", with: "")
            .replacingOccurrences(of: "₿", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        if let directSats = UInt64(cleanString) {
            // Direct satoshi input
            return directSats
        } else if let btcValue = Double(cleanString) {
            // Bitcoin decimal input
            return UInt64(btcValue * 100_000_000)
        }
        
        return nil
    }
}