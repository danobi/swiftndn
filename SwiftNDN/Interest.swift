//
//  Interest.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 2/28/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

open class Interest: Tlv.Block {
    
    open class Selectors: Tlv.Block {
        
        open class Exclude: Tlv.Block {
            
            open class AnyType: Tlv.Block {
                
                public init() {
                    super.init(type: Tlv.NDNType.AnyType)
                }
                
                public init?(block: Tlv.Block) {
                    super.init(type: block.type)
                    if block.type != Tlv.NDNType.AnyType {
                        return nil
                    }
                }
            }
            
            var filter = [[UInt8]]()
            
            public init() {
                super.init(type: Tlv.NDNType.Exclude)
            }
            
            public init(filter: [[UInt8]]) {
                super.init(type: Tlv.NDNType.Exclude)
                self.filter = filter
            }
            
            public init?(block: Tlv.Block) {
                super.init(type: block.type, value: block.value)
                if block.type != Tlv.NDNType.Exclude {
                    return nil
                }
                if let blocks = Tlv.Block.wireDecodeBlockArray(block.value) {
                    for blk in blocks {
                        if blk.type == Tlv.NDNType.AnyType {
                            self.filter.append([])
                        } else if let nc = Name.Component(block: blk) {
                            self.filter.append(nc.value)
                        } else {
                            return nil
                        }
                    }
                }
            }

            open func appendAny() {
                self.filter.append([])
            }
            
            open func appendComponent(_ component: Name.Component) {
                self.filter.append(component.value)
            }
            
            // Return true if the component is covered by the exclude filter (i.e., should be excluded)
            // Return false if not covered
            open func matchesComponent(_ component: Name.Component) -> Bool {
                var lowerBound: Name.Component? = nil
                var insideRange = false  // flag
                
                for arr in self.filter {
                    if arr.isEmpty {
                        // Got ANY
                        insideRange = true // set flag
                    } else {
                        let nc = Name.Component(bytes: arr)
                        if insideRange {
                            // Got upper bound
                            if component <= nc {
                                // Check lowerbound if available
                                if let lb = lowerBound {
                                    if lb <= component {
                                        return true
                                    }
                                } else {
                                    // Current range is (*, nc]
                                    return true
                                }
                            }
                            // Clear lowerbound and reset flag
                            lowerBound = nil
                            insideRange = false
                        } else {
                            // Got new lowerbound
                            // If lowerbound is already set, check it before overwriting it
                            if let lb = lowerBound {
                                if lb == component {
                                    return true
                                }
                            }
                            // Set new lowerbound
                            lowerBound = nc
                        }
                    }
                }
                if let lb = lowerBound {
                    if insideRange {
                        // The last range is a right-open range [lb, *)
                        if lb <= component {
                            return true
                        }
                    } else {
                        // The last range is a single component
                        if lb == component {
                            return true
                        }
                    }
                }
                return false
            }
            
            open override func wireEncodeValue() -> [UInt8] {
                let buf = Buffer(capacity: Int(self.length))
                for f in filter {
                    if f.isEmpty {
                        AnyType().wireEncode(buf)
                    } else {
                        Name.Component(bytes: f).wireEncode(buf)
                    }
                }
                self.value = buf.buffer
                return self.value
            }
            
            open override var length: UInt64 {
                var l: UInt64 = 0
                for f in filter {
                    if f.isEmpty {
                        l += AnyType().totalLength
                    } else {
                        l += Name.Component(bytes: f).totalLength
                    }
                }
                return l
            }
        }
        
        open class ChildSelector: NonNegativeIntegerTlv {
            
            public struct Val {
                public static let LeftmostChild: UInt64 = 0
                public static let RightmostChild: UInt64 = 1
            }
            
            override var defaultValue: UInt64 {
                return Val.LeftmostChild
            }
            
            override var tlvType: UInt64 {
                return Tlv.NDNType.ChildSelector
            }
            
        }
        
        open class MustBeFresh: Tlv.Block {
            
            public init() {
                super.init(type: Tlv.NDNType.MustBeFresh)
            }
            
            public init?(block: Tlv.Block) {
                super.init(type: block.type)
                if block.type != Tlv.NDNType.MustBeFresh {
                    return nil
                }
            }
        }
        
        var exclude: Exclude?
        var childSelector: ChildSelector?
        var mustBeFresh: MustBeFresh?
        
        public init() {
            super.init(type: Tlv.NDNType.Selectors)
        }
        
        public init?(block: Tlv.Block) {
            super.init(type: block.type, value: block.value)
            if block.type != Tlv.NDNType.Selectors {
                return nil
            }
            if let blocks = Tlv.Block.wireDecodeBlockArray(block.value) {
                for blk in blocks {
                    if let ex = Exclude(block: blk) {
                        self.exclude = ex
                    } else if let cs = ChildSelector(block: blk) {
                        self.childSelector = cs
                    } else if let mbf = MustBeFresh(block: blk) {
                        self.mustBeFresh = mbf
                    }
                    // Ignore unknown TLVs
                }
            }
        }
        
        open override func wireEncodeValue() -> [UInt8] {
            let buf = Buffer(capacity: Int(self.length))
            
            self.exclude?.wireEncode(buf)
            self.childSelector?.wireEncode(buf)
            self.mustBeFresh?.wireEncode(buf)
            self.value = buf.buffer
            return self.value
        }
        
        open override var length: UInt64 {
            var l: UInt64 = 0
            if let ex = self.exclude {
                l += ex.totalLength
            }
            if let cs = self.childSelector {
                l += cs.totalLength
            }
            if let mbf = self.mustBeFresh {
                l += mbf.totalLength
            }
            return l
        }
    }
    
    open class Scope: NonNegativeIntegerTlv {
        
        public struct Val {
            public static let LocalDaemon: UInt64 = 0
            public static let LocalHost: UInt64 = 1
            public static let LocalHub: UInt64 = 2
        }
        
        override var tlvType: UInt64 {
            return Tlv.NDNType.Scope
        }
        
        override var defaultValue: UInt64 {
            return Val.LocalHost
        }
        
    }
    
    open class InterestLifetime: NonNegativeIntegerTlv {
        
        override var tlvType: UInt64 {
            return Tlv.NDNType.InterestLifetime
        }
        
        override var defaultValue: UInt64 {
            return 4000
        }
        
    }
    
    open class Nonce: Tlv.Block {
        
        public init() {
            super.init(type: Tlv.NDNType.Nonce)
            value = [UInt8](repeating: 0, count: 4)
            
            let random32bit = arc4random()
            value[0] = UInt8((random32bit >> 24) & 0xFF)
            value[1] = UInt8((random32bit >> 16) & 0xFF)
            value[2] = UInt8((random32bit >> 8) & 0xFF)
            value[3] = UInt8(random32bit & 0xFF)
        }
        
        public init?(block: Tlv.Block) {
            super.init(type: block.type, value: block.value)
            if block.type != Tlv.NDNType.Nonce {
                return nil
            }
            if block.value.count != 4 {
                return nil
            }
        }
    }
    
    open var name = Name()
    open var selectors: Selectors?
    open var nonce = Nonce()
    open var scope: Scope?
    open var interestLifetime: InterestLifetime?
    
    public init() {
        super.init(type: Tlv.NDNType.Interest)
    }
    
    public init?(block: Tlv.Block) {
        super.init(type: block.type)
        if block.type != Tlv.NDNType.Interest {
            return nil
        }
        if let blocks = Tlv.Block.wireDecodeBlockArray(block.value) {
            var hasName = false
            var hasNonce = false
            for blk in blocks {
                if let na = Name(block: blk) {
                    self.name = na
                    hasName = true
                } else if let se = Selectors(block: blk) {
                    self.selectors = se
                } else if let no = Nonce(block: blk) {
                    self.nonce = no
                    hasNonce = true
                } else if let so = Scope(block: blk) {
                    self.scope = so
                } else if let il = InterestLifetime(block: blk) {
                    self.interestLifetime = il
                }
            }
            if !hasName || !hasNonce {
                return nil
            }
        }
    }
    
    open func setExclude(_ filter: Selectors.Exclude) {
        if self.selectors == nil {
            self.selectors = Selectors()
        }
        self.selectors!.exclude = filter
    }
    
    open func setExclude(_ value: [[UInt8]]) {
        if self.selectors == nil {
            self.selectors = Selectors()
        }
        self.selectors!.exclude = Selectors.Exclude(filter: value)
    }
    
    open func getExclude() -> Selectors.Exclude? {
        return self.selectors?.exclude
    }
    
    open func setChildSelector(_ value: UInt64) {
        if self.selectors == nil {
            self.selectors = Selectors()
        }
        self.selectors!.childSelector = Selectors.ChildSelector(value: value)
    }
    
    open func getChildSelector() -> UInt64? {
        return self.selectors?.childSelector?.integerValue
    }
    
    open func setMustBeFresh() {
        if self.selectors == nil {
            self.selectors = Selectors()
        }
        self.selectors!.mustBeFresh = Selectors.MustBeFresh()
    }
    
    open func getMustBeFresh() -> Bool {
        if self.selectors?.mustBeFresh != nil {
            return true
        } else {
            return false
        }
    }
    
    open func setScope(_ value: UInt64) {
        self.scope = Scope(value: value)
    }
    
    open func getScope() -> UInt64? {
        return self.scope?.integerValue
    }
    
    open func setInterestLifetime(_ value: UInt64) {
        self.interestLifetime = InterestLifetime(value: value)
    }
    
    open func getInterestLifetime() -> UInt64? {
        return self.interestLifetime?.integerValue
    }
    
    open class func wireDecode(_ bytes: [UInt8]) -> Interest? {
        let (block, _) = Tlv.Block.wireDecodeWithBytes(bytes)
        if let blk = block {
            return Interest(block: blk)
        } else {
            return nil
        }
    }
    
    open override func wireEncodeValue() -> [UInt8] {
        let buf = Buffer(capacity: Int(self.length))
        self.name.wireEncode(buf)
        self.selectors?.wireEncode(buf)
        self.nonce.wireEncode(buf)
        self.scope?.wireEncode(buf)
        self.interestLifetime?.wireEncode(buf)
        self.value = buf.buffer
        return self.value
    }
    
    open override var length: UInt64 {
        var l: UInt64 = 0
        l += self.name.totalLength
        if let sl = self.selectors {
            l += sl.totalLength
        }
        
        l += self.nonce.totalLength
        
        if let sc = self.scope {
            l += sc.totalLength
        }
        
        if let il = self.interestLifetime {
            l += il.totalLength
        }
        
        return l
    }
    
    open func matchesData(_ data: Data) -> Bool {
        if !self.name.isPrefixOf(data.name) {
            return false
        }
        
        if let exclude = self.selectors?.exclude {
            if self.name.size < data.name.size {
                if let excludedComponent = data.name.getComponentByIndex(self.name.size) {
                    if exclude.matchesComponent(excludedComponent) {
                        return false
                    }
                }
            }
//            else {
//                //TODO: check implicit digest
//            }
        }
        return true
    }
}

public func == (lhs: Interest.Nonce, rhs: Interest.Nonce) -> Bool {
    return lhs.value == rhs.value
}

public func getTimeSinceEpochInMS() -> UInt64 {
    let now = mach_absolute_time()
    var tinfo = mach_timebase_info(numer: 1, denom: 1)
    mach_timebase_info(&tinfo)
    return now * UInt64(tinfo.numer) / UInt64(tinfo.denom) / 1000000
}

open class SignedInterest: Interest {
    
    open var timestamp: UInt64
    open var randomValue: UInt64
    open var signatureInfo: Data.SignatureInfo
    open var signatureValue: Data.SignatureValue
    
    public init(prefix: Name) {
        self.timestamp = getTimeSinceEpochInMS()
        self.randomValue = UInt64(arc4random())
        self.signatureInfo = Data.SignatureInfo()
        self.signatureValue = Data.SignatureValue()
        super.init()
        //FIXME: fill with fake signature for now!!!
        self.signatureValue.value = [UInt8](repeating: 0x77, count: 32)
        let sigInfo = signatureInfo.wireEncode()
        let sigVal = signatureValue.wireEncode()
        self.name = Name(name: prefix)
            .appendNumber(timestamp)
            .appendNumber(randomValue)
            .appendComponent(sigInfo)
            .appendComponent(sigVal)
    }
    
    public override init?(block: Tlv.Block) {
        self.timestamp = 0
        self.randomValue = 0
        self.signatureInfo = Data.SignatureInfo()
        self.signatureValue = Data.SignatureValue()
        super.init(block: block)
        if self.name.size < 4 {
            // Signed Interest name should have at least 4 components
            return nil
        }
        self.timestamp = Buffer.nonNegativeIntegerFromByteArray(self.name.getComponentByIndex(-4)!.value)
        self.randomValue = Buffer.nonNegativeIntegerFromByteArray(self.name.getComponentByIndex(-3)!.value)
        //TODO: parse SignatureInfo and SignatureValue
        //self.name = self.name.getPrefix(self.name.size - 4)
    }
    
    open var prefix: Name {
        return self.name.getPrefix(self.name.size - 4)
    }
}
