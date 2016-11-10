//
//  AsyncTransport.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/2/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

public protocol AsyncTransportDelegate: class {
    func onOpen()
    func onClose()
    func onError(_ reason: String)
    func onMessage(_ block: Tlv.Block)
}

open class AsyncTcpTransport: NSObject, GCDAsyncSocketDelegate {
    
    var socket: GCDAsyncSocket!
    
    var host: String
    var port: UInt16
    
    var buffer: [UInt8]
    
    weak var face: AsyncTransportDelegate!
    
    public init(face: AsyncTransportDelegate, host: String, port: UInt16) {
        self.host = host
        self.port = port
        self.buffer = [UInt8]()
        self.face = face
    }
    
    open func connect() {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)
        // or use global dispatch queue for multithreading?
        do {
            try socket.connect(toHost: host, onPort: port)
        } catch let error as NSError {
            print("AsyncTcpTransport: connectToHost: \(error.localizedDescription)")
            face.onError(error.description)
            return
        }
    }
    
    open func socket(_ sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        //println("AsyncTcpTransport: didConnectToHost \(host):\(port)")
        face.onOpen()
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    open class func byteArrayFromNSData(_ data: Foundation.Data) -> [UInt8]? {
        if data.count == 0 {
            return nil
        }
        var array = [UInt8](repeating: 0, count: data.count)
        (data as NSData).getBytes(&array, length: array.count)
        return array
    }
    
    open func socket(_ sock: GCDAsyncSocket!, didRead data: Foundation.Data!, withTag tag: Int) {
        if let bytes = AsyncTcpTransport.byteArrayFromNSData(data) {
            buffer += bytes
            //println("AsyncTcpTransport: didReadData \(buffer)")
            while buffer.count > 0 {
                let decoded = Tlv.Block.wireDecodeWithBytes(buffer)
                if let blk = decoded.block {
                    face.onMessage(blk)
                    buffer.removeSubrange(0..<decoded.lengthRead)
                }
            }
        }
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    open func send(_ bytes: [UInt8]) {
        let data = Foundation.Data(bytes: UnsafePointer<UInt8>(bytes), count: bytes.count)
        socket.write(data, withTimeout: -1, tag: 0)
    }
    
    open func close() {
        socket.disconnectAfterWriting()
    }
    
    open func socketDidDisconnect(_ sock: GCDAsyncSocket!, withError err: NSError!) {
        if let error = err {
            face.onError(error.description)
        } else {
            face.onClose()
        }
    }
    
}
