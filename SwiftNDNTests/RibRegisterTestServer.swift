//
//  RibRegisterTestServer.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/9/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

import SwiftNDN

open class RibRegisterTestServer: NSObject, GCDAsyncSocketDelegate {
    
    var acceptSocket: GCDAsyncSocket!
    var clientSocket: GCDAsyncSocket!
    
    var host = "127.0.0.1"
    var port: UInt16 = 12345
    var buffer = [UInt8]()
    
    var timer: SwiftNDN.Timer?
    
    public override init() {
        super.init()
        self.timer = SwiftNDN.Timer()
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
                    if let command = ControlCommand(block: blk) {
                        processCommand(sock, command: command)
                    }
                    buffer.removeSubrange(0..<decoded.lengthRead)
                } else {
                    break
                }
            }
        }
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    func sendInterest(_ name: Name) {
        let interest = Interest()
        interest.name = name
        let instEncode = interest.wireEncode()
        let inst = Foundation.Data(bytes: UnsafePointer<UInt8>(instEncode), count: instEncode.count)
        self.clientSocket.write(inst, withTimeout: -1, tag: 0)
    }
    
    func processCommand(_ sock: GCDAsyncSocket!, command: ControlCommand) {
        if command.prefix.toUri() == "/localhost/nfd" {
            if let prefix = command.parameters.name {
                if prefix.toUri() == "/swift/ndn/face/test" {
                    let response = ControlResponse()
                    response.statusCode = StatusCode(value: 200)
                    response.statusText = StatusText(value: "OK")!
                    let responseEncode = response.wireEncode()
                    let data = SwiftNDN.Data()
                    data.name = Name(name: command.name)
                    data.setContent(responseEncode)
                    data.signatureValue = SwiftNDN.Data.SignatureValue(value: [UInt8](repeating: 11, count: 64))
                    let encoded = data.wireEncode()
                    let echoData = Foundation.Data(bytes: UnsafePointer<UInt8>(encoded), count: encoded.count)
                    sock.write(echoData, withTimeout: -1, tag: 0)
                    self.timer?.setTimeout(2000) { [unowned self] in
                        self.sendInterest(Name(url: "/swift/ndn/wrong/prefix")!)
                        self.sendInterest(Name(url: "/swift/ndn/face/test/001")!)
                    }
                }
            }
        }
    }
}
