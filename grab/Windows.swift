import Foundation
import AppKit
import ScriptingBridge


protocol Searchable {
    var searchStrings : [String] { get }
}

protocol ProcessNameProtocol {
    var processName : String { get }
}

protocol BrowserEntity {
    var rawItem : AnyObject { get }
}

protocol BrowserNamedEntity : BrowserEntity {
    var title : String { get }
}


extension BrowserEntity {
    func performSelectorByName<T>(name : String, defaultValue : T) -> T {
        let sel = Selector(name)
        
        if self.rawItem.responds(to: sel) {
            let selectorResult = self.rawItem.perform(sel)
            
            guard let retainedValue = selectorResult?.takeUnretainedValue() else {
                return defaultValue
            }
            
            guard let result = retainedValue as? T else {
                return defaultValue
            }
            
            return result
        } else {
            return defaultValue
        }
    }
}

extension BrowserNamedEntity {
    var title : String {
        /* Safari uses 'name' as the tab title, while most of the browsers have 'title' there */
        if self.rawItem.responds(to: #selector(getter: MTLFunction.name)) {
            return performSelectorByName(name: "name", defaultValue: "")
        }
        return performSelectorByName(name: "title", defaultValue: "")
    }
}

class BrowserTab : BrowserNamedEntity, Searchable, ProcessNameProtocol {
    private let tabRaw : AnyObject
    private let index : Int?
    
    let windowTitle : String
    let processName : String
    
    init(raw: AnyObject, index: Int?, windowTitle: String, processName: String) {
        tabRaw = raw
        self.index = index
        self.windowTitle = windowTitle
        self.processName = processName
    }
    
    var rawItem: AnyObject {
        return self.tabRaw
    }
    
    var url : String {
        return performSelectorByName(name: "URL", defaultValue: "")
    }
    
    var tabIndex : Int {
        guard let i = index else {
            return 0
        }
        return i
    }
    
    var searchStrings : [String] {
        return ["Browser", self.url, self.title]
    }
    
    /*
     (lldb) po raw.perform("URL").takeRetainedValue()
     https://encrypted.google.com/search?hl=en&q=objc%20mac%20list%20Browser%20tabs#hl=en&q=swift+call+metho+by+name
     
     
     (lldb) po raw.perform("name").takeRetainedValue()
     scriptingbridge Browsertab - Google Search
     */
}

class BrowserWindow : BrowserNamedEntity {
    private let windowRaw : AnyObject
    
    let processName : String
    
    init(raw: AnyObject, processName: String) {
        windowRaw = raw
        self.processName = processName
    }
    
    var rawItem: AnyObject {
        return self.windowRaw
    }
    
    var activeTab: BrowserTab? {
        let sel = Selector(("activeTab"))
        let selectorResult = self.rawItem.perform(sel)
        
        guard let retainedValue = selectorResult?.takeUnretainedValue() else {
            return nil
        }
        
        return BrowserTab(raw: retainedValue, index: 0, windowTitle: self.title, processName: self.processName)
    }
    
    var tabs : [BrowserTab] {
        let result = performSelectorByName(name: "tabs", defaultValue: [AnyObject]())
        
        return result.enumerated().map { (index, element) in
            return BrowserTab(raw: element, index: index + 1, windowTitle: self.title, processName: self.processName)
        }
    }
}

class BrowserApplication : BrowserEntity {
    private let app : SBApplication
    let processName : String
    
    static func connect(processIdentifier pid:pid_t, processName: String) -> BrowserApplication? {
        guard let app = SBApplication(processIdentifier: pid) else {
            return nil
        }
        
        return BrowserApplication(app: app, processName: processName)
    }
    
    static func connect(processName: String) -> BrowserApplication? {
        
        let ws = NSWorkspace.shared
        
        guard let fullPath = ws.fullPath(forApplication: processName) else {
            return nil
        }
        
        let bundle = Bundle(path: fullPath)
        
        guard let bundleId = bundle?.bundleIdentifier else {
            return nil
        }
        
        let runningBrowsers = ws.runningApplications.filter { $0.bundleIdentifier == bundleId }
        
        guard runningBrowsers.count > 0 else {
            return nil
        }
        
        guard let app = SBApplication(bundleIdentifier: bundleId) else {
            return nil
        }
        
        return BrowserApplication(app: app, processName: processName)
    }
    
    init(app: SBApplication, processName: String) {
        self.app = app
        self.processName = processName
    }
    
    var rawItem: AnyObject {
        return app
    }
    
    var windows : [BrowserWindow] {
        let result = performSelectorByName(name: "windows", defaultValue: [AnyObject]())
        return result.map {
            return BrowserWindow(raw: $0, processName: self.processName)
        }
    }
}

import Foundation

class WindowInfoDict : Searchable, ProcessNameProtocol {
    private let windowInfoDict : Dictionary<NSObject, AnyObject>;
    
    init(rawDict : UnsafeRawPointer) {
        windowInfoDict = unsafeBitCast(rawDict, to: CFDictionary.self) as Dictionary
    }
    
    init(dict : CFDictionary) {
        windowInfoDict = dict as Dictionary
    }
    
    var name : String {
        return self.dictItem(key: "kCGWindowName", defaultValue: "")
    }
    
    var windowTitle: String {
        return self.name
    }
    
    var processName : String {
        return self.dictItem(key: "kCGWindowOwnerName", defaultValue: "")
    }
    
    var appName : String {
        return self.dictItem(key: "kCGWindowOwnerName", defaultValue: "")
    }
    
    var pid : Int {
        return self.dictItem(key: "kCGWindowOwnerPID", defaultValue: -1)
    }
    
    var layer : Int {
        return self.dictItem(key: "kCGWindowLayer", defaultValue: -1)
    }
    
    var number : Int {
        return self.dictItem(key: "kCGWindowNumber", defaultValue: -1)
    }
    
    var positionString : String {
        get {
            let b = bounds
            return "(\(Int(b.origin.x)),\(Int(b.origin.y))),(\(Int(b.size.width))x\(Int(b.size.height))"
        }
    }
    
    var bounds : CGRect {
        let dict = self.dictItem(key: "kCGWindowBounds", defaultValue: NSDictionary())
        guard let bounds = CGRect.init(dictionaryRepresentation: dict) else {
            return CGRect.zero
        }
        return bounds
    }
    
    var alpha : Float {
        return self.dictItem(key: "kCGWindowAlpha", defaultValue: 0.0)
    }
    
    var tabIndex: Int {
        return 0
    }
    
    func dictItem<T>(key : String, defaultValue : T) -> T {
        guard let value = windowInfoDict[key as NSObject] as? T else {
            return defaultValue
        }
        return value
    }
    
    static func == (lhs: WindowInfoDict, rhs: WindowInfoDict) -> Bool {
        return lhs.processName == rhs.processName && lhs.name == rhs.name
    }
    
    var hashValue: Int {
        return "\(self.processName)-\(self.name)".hashValue
    }
    
    var searchStrings: [String] {
        return [self.processName, self.name]
    }
    
    var isProbablyMenubarItem : Bool {
        return layer >= NSWindow.Level.mainMenu.rawValue
    }
    
    var isVisible : Bool {
        return self.alpha > 0
    }
}

struct Windows {
    static var all : [WindowInfoDict] {
        guard let wl = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) else {
            return []
        }
        let windows = wl as! [CFDictionary]
        return windows
            .map { WindowInfoDict(dict: $0) }
            .filter { $0.isVisible }
    }
}
