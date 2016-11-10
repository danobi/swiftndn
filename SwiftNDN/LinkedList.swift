//
//  LinkedList.swift
//  SwiftNDN
//
//  Created by Wentao Shang on 3/7/15.
//  Copyright (c) 2015 Wentao Shang. All rights reserved.
//

import Foundation

open class ListEntry<T> {
    weak var prev: ListEntry?
    var next: ListEntry?
    
    open var value: T?
    
    public init() {
        self.prev = nil
        self.next = nil
        self.value = nil
    }
    
    public init(value: T) {
        self.value = value
        self.prev = nil
        self.next = nil
    }
    
    open func detach() {
        self.prev?.next = self.next
        self.next?.prev = self.prev
    }
}

open class LinkedList<T> {
    var head: ListEntry<T>
    var tail: ListEntry<T>
    
    // O(n) complexity
    open var size: Int {
        var s = 0
        var iter = head.next
        while iter !== tail && iter != nil {
            s += 1
            iter = iter?.next
        }
        return s
    }
    
    public init() {
        head = ListEntry<T>()
        tail = ListEntry<T>()
        
        head.next = tail
        tail.prev = head
    }
    
    open var isEmpty: Bool {
        return head.next! === tail
    }
    
    open func appendAtTail(_ t: T) -> ListEntry<T> {
        let entry = ListEntry<T>(value: t)
        tail.prev?.next = entry
        entry.prev = tail.prev
        entry.next = tail
        tail.prev = entry
        return entry
    }
    
    open func appendInFront(_ t: T) -> ListEntry<T> {
        let entry = ListEntry<T>(value: t)
        head.next?.prev = entry
        entry.next = head.next
        entry.prev = head
        head.next = entry
        return entry
    }
    
    open func forEach(_ action: (_ t: T) -> Void) {
        var iter = head.next
        while iter !== tail && iter != nil {
            if let value = iter!.value {
                action(value)
            }
            iter = iter!.next
        }
    }
    
    open func forEachEntry(_ action: (_ t: ListEntry<T>) -> Void) {
        var iter = head.next
        while iter !== tail && iter != nil {
            let iterNext = iter!.next
            action(iter!)
            iter = iterNext
        }
    }
    
    open func findOneIf(_ condition: (_ t: T) -> Bool) -> T? {
        var iter = head.next
        while iter !== tail && iter != nil {
            if let entry = iter {
                if let value = entry.value {
                    if condition(value) {
                        return value
                    }
                }
            }
            iter = iter?.next
        }
        return nil
    }
    
    open func findAllIf(_ condition: (_ t: T) -> Bool) -> [T] {
        var arr = [T]()
        var iter = head.next
        while iter !== tail && iter != nil {
            if let entry = iter {
                if let value = entry.value {
                    if condition(value) {
                        arr.append(value)
                    }
                }
            }
            iter = iter?.next
        }
        return arr
    }

    
    open func removeOneIf(_ condition: (_ t: T) -> Bool) -> Bool {
        var iter = head.next
        while iter !== tail && iter != nil {
            let iterNext = iter?.next
            if let entry = iter {
                if let value = entry.value {
                    if condition(value) {
                        entry.detach()
                        return true
                    }
                }
            }
            iter = iterNext
        }
        return false
    }
    
    open func removeAllIf(_ condition: (_ t: T) -> Bool) -> Bool {
        var removedSomething = false
        var iter = head.next
        while iter !== tail && iter != nil {
            let iterNext = iter?.next
            if let entry = iter {
                if let value = entry.value {
                    if condition(value) {
                        entry.detach()
                        removedSomething = true
                    }
                }
            }
            iter = iterNext
        }
        return removedSomething
    }
}
