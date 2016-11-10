//
//  KeyChain.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/4/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation
import Security

open class KeyChain {
    
    fileprivate var pubKey: SecKey!
    fileprivate var priKey: SecKey!
    fileprivate let keyLable = "/ndn/swift/dummy/key"
    
    public init?() {
        var pubKeyPointer: SecKey? = nil
        var priKeyPointer: SecKey? = nil
        let param = [
            kSecAttrKeyType as String : kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String : 1024,
            kSecAttrLabel as String : keyLable
        ] as [String : Any]
        let status = SecKeyGeneratePair(param as CFDictionary, &pubKeyPointer, &priKeyPointer)
        if status == errSecSuccess {
            pubKey = pubKeyPointer!
            priKey = priKeyPointer!
        } else {
            return nil
        }
    }
    
    open func clean() {
        let param = [
            kSecClass as String : kSecClassKey,
            kSecAttrLabel as String : keyLable,
            kSecMatchLimit as String : kSecMatchLimitAll
        ] as [String : Any]
        SecItemDelete(param as CFDictionary)
    }
    
    open func sign(_ data: Data, onFinish: @escaping (Data) -> Void, onError: @escaping (String) -> Void) {
        // Clear existing signature
        data.signatureInfo = Data.SignatureInfo()
        data.signatureInfo.keyLocator = Data.SignatureInfo.KeyLocator(name: Name(url: keyLable)!)
        data.signatureValue = Data.SignatureValue()
        
        let signedPortion = data.getSignedPortion()
        var signedData = Foundation.Data(bytes: UnsafePointer<UInt8>(signedPortion), count: signedPortion.count)
        
        if let signer: SecTransform = SecSignTransformCreate(priKey, nil) {
            if !SecTransformSetAttribute(signer, kSecTransformInputAttributeName, signedData as CFTypeRef, nil) {
                onError("KeyChain.sign: failed to set data to be signed")
                return
            }
            if !SecTransformSetAttribute(signer, kSecDigestTypeAttribute, kSecDigestSHA2, nil) {
                onError("KeyChain.sign: failed to set digest algorithm")
                return
            }
            if !SecTransformSetAttribute(signer, kSecDigestLengthAttribute, 256 as CFTypeRef, nil) {
                onError("KeyChain.sign: failed to set digest length")
                return
            }
            
            func makeSignResultCollector() ->
                ((_ message: Optional<AnyObject>, _ error: Optional<CFError>, _ isFinal: Bool) -> Void) {
                    var pendingResult = [UInt8]()
                    return {
                        (message: Optional<AnyObject>, error: Optional<CFError>, isFinal: Bool) -> Void in
                        
                        if error != nil {
                            onError("KeyChain.sign: \(CFErrorCopyDescription(error))")
                            return
                        }
                        if let signatureData = message as? Foundation.Data! {
                            if let signature = signatureData {
                                var arr = [UInt8](repeating: 0, count: signature.count)
                                (signature as NSData).getBytes(&arr, length: signature.count)
                                pendingResult += arr
                            }
                        }
                        
                        if isFinal {
                            if pendingResult.isEmpty {
                                onError("KeyChain.sign: failed to extract signature result")
                            } else {
                                data.setSignature(pendingResult)
                                onFinish(data)
                            }
                        }
                    }
            }
            
            SecTransformExecuteAsync(signer, DispatchQueue.main, makeSignResultCollector())
        } else {
            onError("KeyChain.sign: failed to create signer")
        }
        return
    }
    
    open func verify(_ data: Data, onSuccess: @escaping () -> Void, onFailure: @escaping (String) -> Void) {
        let signedPortion = data.getSignedPortion()
        var signedData = Foundation.Data(bytes: UnsafePointer<UInt8>(signedPortion), count: signedPortion.count)
        var signature = Foundation.Data(bytes: UnsafePointer<UInt8>(data.signatureValue.value), count: data.signatureValue.value.count)
        
        if let verifier: SecTransform  = SecVerifyTransformCreate(pubKey, signature as CFData?, nil) {
            if !SecTransformSetAttribute(verifier, kSecTransformInputAttributeName, signedData as CFTypeRef, nil) {
                onFailure("KeyChain.verify: failed to set data to be verified")
                return
            }
            if !SecTransformSetAttribute(verifier, kSecDigestTypeAttribute, kSecDigestSHA2, nil) {
                onFailure("KeyChain.verify: failed to set digest algorithm")
                return
            }
            if !SecTransformSetAttribute(verifier, kSecDigestLengthAttribute, 256 as CFTypeRef, nil) {
                onFailure("KeyChain.verify: failed to set digest length")
                return
            }

            func makeVerifyResultCollector() ->
                ((_ message: Optional<AnyObject>, _ error: Optional<CFError>, _ isFinal: Bool) -> Void) {
                    var success = true
                    return {
                        (message: Optional<AnyObject>, error: Optional<CFError>, isFinal: Bool) -> Void in
                    
                        if error != nil {
                            onFailure("KeyChain.verify: \(CFErrorCopyDescription(error))")
                            return
                        }
                        if let verified = message as! CFBoolean! {
                            if verified == kCFBooleanTrue {
                                success = success && true
                            } else {
                                success = false
                            }
                        }

                        if isFinal {
                            if success {
                                onSuccess()
                            } else {
                                onFailure("KeyChain.verify: signature is incorrect")
                            }
                        }
                    }
            }
        
            SecTransformExecuteAsync(verifier, DispatchQueue.main, makeVerifyResultCollector())
        } else {
            onFailure("KeyChain.verify: failed to create verifier")
        }

        return
    }
}
