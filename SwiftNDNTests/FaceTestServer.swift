//
//  FaceTestServer.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/8/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

import SwiftNDN

open class FaceTestServer: NSObject, GCDAsyncSocketDelegate {
    
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
            print("FaceTestServer: acceptOnInterface: \(error.localizedDescription)")
            return
        }
    }
    
    open func socket(_ sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        //println("FaceTestServer: didAcceptNewSocket: client accepted")
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
                    if let interest = Interest(block: blk) {
                        processInterest(sock, interest: interest)
                    }
                    buffer.removeSubrange(0..<decoded.lengthRead)
                } else {
                    break
                }
            }
        }
        sock.readData(withTimeout: -1, tag: 0)
    }

    func processInterest(_ sock: GCDAsyncSocket!, interest: Interest) {
        if interest.name.toUri() == "/a/b/c" {
            let data = SwiftNDN.Data()
            data.name = Name(name: interest.name)
//            data.name.appendComponent("%00%02")
            data.setContent([0, 1, 2, 3, 4, 5, 6, 7])
            data.signatureValue = SwiftNDN.Data.SignatureValue(value: [UInt8](repeating: 0, count: 64))
            let encoded = data.wireEncode()
            let echoData = Foundation.Data(bytes: UnsafePointer<UInt8>(encoded), count: encoded.count)
            sock.write(echoData, withTimeout: -1, tag: 0)
        }
    }
}
