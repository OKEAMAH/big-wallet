// Copyright © 2021 Tokenary. All rights reserved.

import Foundation
import BigInt

struct Transaction {
    let from: String
    let to: String
    var nonce: String?
    var gasPrice: String?
    var gas: String?
    let value: String?
    let data: String
    
    var hasFee: Bool {
        return gas != nil && gasPrice != nil
    }
    
    var gasPriceGwei: UInt? {
        guard let gasPrice = gasPrice, let value = BigInt(hexString: gasPrice) else { return nil }
        return UInt(value.gwei)
    }
    
    func description(chain: EthereumNetwork, ethPrice: Double?) -> String {
        var result = [String]()
        if let value = valueWithSymbol(chain: chain, ethPrice: ethPrice, withLabel: false) {
            result.append(value)
        }
        result.append(feeWithSymbol(chain: chain, ethPrice: ethPrice))
        result.append(dataWithLabel)
        
        return result.joined(separator: "\n\n")
    }
    
    var nonEmptyDataWithLabel: String? {
        if data.count > 2 {
            return dataWithLabel
        } else {
            return nil
        }
    }
    
    var dataWithLabel: String {
        return "Data: " + data
    }
    
    func gasPriceWithLabel(chain: EthereumNetwork) -> String {
        let gwei: String
        if let gasPriceGwei = gasPriceGwei {
            gwei = String(gasPriceGwei) + (chain.symbolIsETH ? " Gwei" : "")
        } else {
            gwei = Strings.calculating
        }
        return "Gas price: " + gwei
    }
    
    func feeWithSymbol(chain: EthereumNetwork, ethPrice: Double?) -> String {
        let feeString: String
        if let gasPriceString = gasPrice, let gasString = gas,
           let gasPrice = BigInt(hexString: gasPriceString),
           let gas = BigInt(hexString: gasString) {
            let fee = gas * gasPrice
            let costString = chain.hasUSDPrice ? cost(value: fee, price: ethPrice) : ""
            feeString = fee.eth.prefix(7) + " \(chain.symbol)" + costString
        } else {
            feeString = Strings.calculating
        }
        return "Fee: " + feeString
    }
    
    func valueWithSymbol(chain: EthereumNetwork, ethPrice: Double?, withLabel: Bool) -> String? {
        guard let value = value, let value = BigInt(hexString: value) else { return nil }
        let costString = chain.hasUSDPrice ? cost(value: value, price: ethPrice) : ""
        let valueString = "\(value.eth) \(chain.symbol)" + costString
        return withLabel ? "Value: " + valueString : valueString
    }
    
    private func cost(value: BigInt, price: Double?) -> String {
        guard let price = price, let ethValue = Double(value.eth) else { return "" }
        let cost = NSNumber(floatLiteral: price * ethValue)
        let formatter = NumberFormatter()
        formatter.decimalSeparator = "."
        formatter.maximumFractionDigits = 1
        if let costString = formatter.string(from: cost) {
            return " ≈ $\(costString)"
        } else {
            return ""
        }
    }
    
    mutating func setGasPrice(value: Double, inRelationTo info: GasService.Info) {
        let tickValues = info.sortedValues
        let tickValuesCount = tickValues.count
        guard value >= 0, value <= 100, tickValuesCount > 1 else { return }
        
        if value.isZero, let min = tickValues.first {
            setGasPrice(value: min)
            return
        } else if value == 100, let max = tickValues.last {
            setGasPrice(value: max)
            return
        }
        
        let step = Double(100) / Double(tickValuesCount - 1)
        for i in 1..<tickValuesCount where value <= step * Double(i) {
            let partialStep = value - step * Double(i - 1)
            let previousTickValue = tickValues[i - 1]
            let nextTickValue = tickValues[i]
            let current = previousTickValue + UInt((partialStep / step) * Double(nextTickValue - previousTickValue))
            setGasPrice(value: current)
            return
        }
    }
    
    private mutating func setGasPrice(value: UInt) {
        gasPrice = String.hex(value)
    }
    
    func currentGasInRelationTo(info: GasService.Info) -> Double {
        guard let gasPrice = gasPrice, let current = UInt(hexString: gasPrice) else { return 0 }
        let tickValues = info.sortedValues
        let tickValuesCount = tickValues.count
        guard tickValuesCount > 1 else { return 0 }
        
        if current <= tickValues[0] {
            return 0
        } else if current >= tickValues[tickValuesCount - 1] {
            return 100
        }
        
        let step = Double(100) / Double(tickValuesCount - 1)
        
        for i in 1..<tickValuesCount where current < tickValues[i] {
            let partialStep = Double(current - tickValues[i - 1]) / Double(tickValues[i] - tickValues[i - 1])
            let fullSteps = Double(i - 1)
            return (fullSteps + partialStep) * step
        }
        
        return 0
    }
    
}
