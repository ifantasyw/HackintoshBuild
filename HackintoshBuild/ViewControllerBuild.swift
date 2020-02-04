//
//  ViewController.swift
//  HackintoshBuild
//
//  Created by bugprogrammer on 2020/1/5.
//  Copyright © 2020 bugprogrammer. All rights reserved.
//

import Cocoa

class ViewControllerBuild: NSViewController {
    
    @IBOutlet var buildText: NSTextView!
    @IBOutlet var stopButton: NSButton!
    
    @IBOutlet var progressBar: NSProgressIndicator!
    
    @IBOutlet var buildButton: NSButton!
    @IBOutlet weak var pluginsView: NSTableView!
    
    @IBOutlet var buildLocation: NSPathControl!
    
    @IBOutlet weak var proxyTextField: NSTextField!
    
    let taskQueue = DispatchQueue.global(qos: .background)
    let lock = NSLock()
    
    let pluginsList: [String] = [
        "Clover(时间较长)",
        "OpenCore",
        "n-d-k-OpenCore",
        "AppleSupportPkg",
        "Lilu",
        "AirportBrcmFixup",
        "AppleALC",
        "ATH9KFixup",
        "BT4LEContinuityFixup",
        "CPUFriend",
        "HibernationFixup",
        "NoTouchID",
        "RTCMemoryFixup",
        "SystemProfilerMemoryFixup",
        "VirtualSMC",
        "acidanthera_WhateverGreen",
        "bugprogrammer_WhateverGreen",
        "IntelMausiEthernet",
        "AtherosE2200Ethernet",
        "RTL8111",
        "NVMeFix"
    ]

    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        resetStatus(isRunning: false)
        
        proxyTextField.placeholderString = "http://127.0.0.1:xxxx"
        proxyTextField.stringValue = ""
        proxyTextField.refusesFirstResponder = true
        
        if let kextLocation = UserDefaults.standard.url(forKey: "kextLocation") {
            if FileManager.default.fileExists(atPath: kextLocation.path) {
                self.buildLocation.url = kextLocation
            }
        }
        
        self.pluginsView.reloadData()
    }
    
    var buildTask: Process!
    var itemsArr: [String] = []
    var itemsSting: String = ""
    
    private func resetStatus(isRunning: Bool) {
        if isRunning {
            stopButton.isEnabled = true
            progressBar.isHidden = false
            buildText.string = ""
            buildButton.isEnabled = false
            progressBar.startAnimation(self)
        } else {
            stopButton.isEnabled = false
            buildButton.isEnabled = true
            progressBar.stopAnimation(self)
            progressBar.doubleValue = 0.0
            progressBar.isHidden = true
        }
    }
    
    @IBAction func startBuild(_ sender: Any) {
        
        if let buildURL = buildLocation.url {
            UserDefaults.standard.set(buildURL, forKey: "kextLocation")
            var arguments: [String] = []
            itemsSting = itemsArr.joined(separator: ",")
            arguments.append(buildURL.path)
            arguments.append(itemsSting)
            arguments.append(proxyTextField.stringValue)
            runBuildScripts(arguments)
            MyLog(arguments)
        } else {
            let alert = NSAlert()
            alert.messageText = "请先选择存储位置！"
            alert.runModal()
        }
            
    }
    
    @IBAction func stopBuild(_ sender: Any) {
        if buildTask.suspend() {
            buildTask.terminate()
        }
    }
    
    @IBAction func CheckClicked(_ sender: NSButton) {
        switch sender.state {
        case .on:
            itemsArr.append(String(pluginsView.row(for: sender)))
        case .off:
            itemsArr = itemsArr.filter{$0 != String(pluginsView.row(for: sender))}
        case .mixed:
            MyLog("mixed")
        default: break
        }
        MyLog(itemsArr)
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func runBuildScripts(_ arguments: [String]) {
        self.resetStatus(isRunning: true)
        taskQueue.async {
            if let path = Bundle.main.path(forResource: "Hackintosh_build", ofType:"command") {
                self.buildTask = Process()
                self.buildTask.launchPath = path
                self.buildTask.arguments = arguments
                self.buildTask.terminationHandler = { task in
                    DispatchQueue.main.async(execute: { [weak self] in
                        guard let `self` = self else { return }
                        self.resetStatus(isRunning: false)
                    })
                }
                self.buildOutPut(self.buildTask)
                self.buildTask.launch()
                self.buildTask.waitUntilExit()
            }
        }
    }
    
    func buildOutPut(_ task: Process) {
        let buildTextPipe = Pipe()
        task.standardOutput = buildTextPipe
        buildTextPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: buildTextPipe.fileHandleForReading , queue: nil) { notification in
            let output = buildTextPipe.fileHandleForReading.availableData
            if output.count > 0 {
                buildTextPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
                let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
                DispatchQueue.main.async(execute: {
                    let previousOutput = self.buildText.string
                    let nextOutput = previousOutput + "\n" + outputString
                    self.buildText.string = nextOutput
                    let range = NSRange(location:nextOutput.count, length:0)
                    self.buildText.scrollRangeToVisible(range)
                    self.progressBar.increment(by: 1.9)
                })
            }
        }
    }

}

extension ViewControllerBuild: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return pluginsList.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        return pluginsList[row]
    }
    
}