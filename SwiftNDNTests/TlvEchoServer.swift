//
//  TlvEchoServer.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/3/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

import SwiftNDN

open class TlvEchoServer: NSObject, GCDAsyncSocketDelegate {
    
    var acceptSocket: GCDAsyncSocket!
    var clientSocket: GCDAsyncSocket!
    
    var host = "127.0.0.1"
    var port: UInt16 = 12345
    var buffer = [UInt8]()
    
    public override init() {
        super.init()
    }
    
    open func start() {
        acceptSocket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue.main)

        do {
            try acceptSocket.accept(onInterface: host, port: port)
        } catch let error as NSError {
            print("TlvEchoServer: acceptOnInterface: \(error.localizedDescription)")
            return
        }
    }
    
    open func socket(_ sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        //println("TlvEchoServer: didAcceptNewSocket: client accepted")
        clientSocket = newSocket
        clientSocket.readData(withTimeout: -1, tag: 0)
        // Stop accepting new client
        acceptSocket = nil
    }
    
    open func socket(_ sock: GCDAsyncSocket!, didRead data: Foundation.Data!, withTag tag: Int) {
        if let bytes = AsyncTcpTransport.byteArrayFromNSData(data) {
            buffer += bytes
            while buffer.count > 0 {
                let decoded = Tlv.Block.wireDecodeWithBytes(buffer)
                if let blk = decoded.block {
                    //println("TlvEchoServer: didReadData: \(buffer)")
                    //println("TlvEchoServer: didReadData: \(blk)")
                    let encoded = blk.wireEncode()
                    //println("TlvEchoServer: didReadData: \(encoded)")
                    let echoData = Foundation.Data(bytes: UnsafePointer<UInt8>(encoded), count: encoded.count)
                    sock.write(echoData, withTimeout: -1, tag: 0)
                    buffer.removeSubrange(0..<decoded.lengthRead)
                } else {
                    break
                }
            }
        }
        sock.readData(withTimeout: -1, tag: 0)
    }
    
//    public func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
//        println("TlvEchoServer: socketDidDisconnect: \(sock)")
//    }

}
