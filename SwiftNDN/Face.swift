//
//  Face.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/5/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

open class Timer {
    
    var timer: DispatchSource!
    var callback: (() -> Void)?
    var isSet = false
    var isFired = false
    
    public init?() {
        timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: DispatchQueue.main) /*Migrator FIXME: Use DispatchSourceTimer to avoid the cast*/ as! DispatchSource
        
        
        if timer == nil {
            return nil
        }
    }
    
    deinit {
        if !isSet {
            if !isFired {
                // Cancel the unfired event before releasing the resource
                self.cancel()
            }
            // Need to balance the resume/suspend count before releasing the timer
            self.timer.resume();
        }
    }
    
    open func setTimeout(_ ms: UInt64, callback: @escaping () -> Void) {
        self.callback = callback
        self.isSet = true
        
        let delay = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(ms))
        
        self.timer.scheduleRepeating(deadline: delay, interval: DispatchTimeInterval.nanoseconds(Int.max), leeway: DispatchTimeInterval.milliseconds(Int(ms)))        
        self.timer.setEventHandler(handler: { [unowned self] in self.handler() })
        self.timer.resume()
    }
    
    fileprivate func handler() {
        self.isFired = true
        self.callback?()
        self.cancel()
    }
    
    open func cancel() {
        self.timer.cancel()
    }
}

public protocol FaceDelegate: class {
    func onOpen()
    func onClose()
    func onError(_ reason: String)
}

open class Face: AsyncTransportDelegate {
    
    var transport: AsyncTcpTransport!
    weak var delegate: FaceDelegate!
    
    var host = "127.0.0.1"
    var port: UInt16 = 6363
    
    open var isOpen: Bool = false
    
    var isConnectedToLocalNFD: Bool {
        if let remoteIP = transport?.socket?.connectedHost {
            if remoteIP == "127.0.0.1" {
                return true
            }
        }
        return false
    }
    
#if os(iOS)
    public func enableBackgroundMode() {
        self.transport.socket.performBlock() { [unowned self] in
            self.transport.socket.enableBackgroundingOnSocket()
            return
        }
    }
#endif
    
    public typealias OnDataCallback = (Interest, Data) -> Void
    public typealias OnTimeoutCallback = (Interest) -> Void
    public typealias OnInterestCallback = (Interest) -> Void
    public typealias OnRegisterSuccessCallback = (Name) -> Void
    public typealias OnRegisterFailureCallback = (String) -> Void
    
    class ExpressedInterestTable {
        
        class Entry {
            var interest: Interest
            var onData: OnDataCallback?
            var onTimeout: OnTimeoutCallback?
            var timer: Timer!
            
            init?(interest: Interest, onDataCb: OnDataCallback?,
                onTimeoutCb: OnTimeoutCallback?)
            {
                self.interest = interest
                self.onData = onDataCb
                self.onTimeout = onTimeoutCb
                self.timer = Timer()
                if self.timer == nil {
                    return nil
                }
            }
        }
        
        var table = LinkedList<Entry>()
        
        func append(_ interest: Interest, onDataCb: OnDataCallback?,
            onTimeoutCb: OnTimeoutCallback?)
        {
            if let entry = Entry(interest: interest,
                onDataCb: onDataCb, onTimeoutCb: onTimeoutCb)
            {
                let listEntry = table.appendAtTail(entry)
                let lifetime = interest.getInterestLifetime() ?? 4000
                entry.timer.setTimeout(lifetime, callback: {
                    listEntry.detach()
                    if let cb = entry.onTimeout {
                        cb(entry.interest)
                    }
                })
            }
        }
        
        func consumeWithData(_ data: Data) {
            table.forEachEntry() { listEntry in
                if let entry = listEntry.value {
                    if entry.interest.matchesData(data) {
                        listEntry.detach()
                        entry.timer?.cancel()
                        entry.timer = nil
                        if let onData = entry.onData {
                            onData(entry.interest, data)
                        }
                    }
                }
            }
        }
    }
    
    var expressedInterests = ExpressedInterestTable()
    
    class RegisteredPrefixTable {
        
        struct Entry {
            var prefix: Name
            var onInterest: OnInterestCallback?
        }
        
        var table = LinkedList<Entry>()
        
        func append(_ prefix: Name, onInterestCb: OnInterestCallback?) -> ListEntry<Entry>
        {
            let entry = Entry(prefix: prefix, onInterest: onInterestCb)
            let lentry = table.appendAtTail(entry)
            return lentry
        }
        
        func dispatchInterest(_ interest: Interest) {
            table.forEachEntry() { listEntry in
                if let entry = listEntry.value {
                    if entry.prefix.isPrefixOf(interest.name) {
                        if let onInterest = entry.onInterest {
                            onInterest(interest)
                        }
                    }
                }
            }
        }
    }

    var registeredPrefixes = RegisteredPrefixTable()

    public init(delegate: FaceDelegate) {
        self.delegate = delegate
        self.transport = AsyncTcpTransport(face: self, host: host, port: port)
    }
    
    public init(delegate: FaceDelegate, host: String, port: UInt16) {
        self.delegate = delegate
        self.host = host
        self.port = port
        self.transport = AsyncTcpTransport(face: self, host: host, port: port)
    }
    
    open func onOpen() {
        self.isOpen = true
        self.delegate.onOpen()
    }
    
    open func onClose() {
        self.isOpen = false
        self.delegate.onClose()
    }
    
    open func onError(_ reason: String) {
        //TODO: close face upon any error??
        self.delegate.onError(reason)
    }
    
    open func open() {
        if !isOpen {
            transport.connect()
        }
    }

    open func close() {
        transport.close()
    }
    
    open func onMessage(_ block: Tlv.Block) {
        if let interest = Interest(block: block) {
            registeredPrefixes.dispatchInterest(interest)
        } else if let data = Data(block: block) {
            expressedInterests.consumeWithData(data)
        }
    }
    
    open func expressInterest(_ interest: Interest,
        onData: OnDataCallback?, onTimeout: OnTimeoutCallback?) -> Bool
    {
        if !isOpen {
            return false
        }
        
        let wire = interest.wireEncode()
        expressedInterests.append(interest, onDataCb: onData, onTimeoutCb: onTimeout)
        transport.send(wire)
        return true
    }
    
    open func registerPrefix(_ prefix: Name, onInterest: OnInterestCallback?,
        onRegisterSuccess: OnRegisterSuccessCallback?,
        onRegisterFailure: OnRegisterFailureCallback?)
    {
        if !isOpen {
            return
        }
        
        // Append to table first
        let lentry = registeredPrefixes.append(prefix, onInterestCb: onInterest)

        // Prepare command interest
        let param = ControlParameters()
        param.name = prefix
        
        var ribRegPrefix: Name
        if isConnectedToLocalNFD {
            ribRegPrefix = Name(url: "/localhost/nfd")!
        } else {
            ribRegPrefix = Name(url: "/localhop/nfd")!
        }
        
        let nfdRibRegisterInterest = ControlCommand(prefix: ribRegPrefix,
            module: Name.Component(url: "rib")!, verb: Name.Component(url: "register")!, param: param)
        let ret = self.expressInterest(nfdRibRegisterInterest, onData: { _, d in
            let content = d.getContent()
            if let response = ControlResponse.wireDecode(content) {
                if response.statusCode.integerValue == 200 {
                    onRegisterSuccess?(prefix)
                } else {
                    onRegisterFailure?("Register command failure")
                }
            } else {
                onRegisterFailure?("Malformat control response")
            }
            }, onTimeout: { [unowned lentry] _ in
                onRegisterFailure?("Command Interest timeout")
                lentry.detach()
        })
        
        if !ret {
            // Failed in sending the command interest
            onRegisterFailure?("Failed to send Command Interest")
            lentry.detach()
        }
    }
    
    open func put(_ data: Data) {
        transport.send(data.wireEncode())
    }
}
