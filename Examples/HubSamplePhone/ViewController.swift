//
//  ViewController.swift
//  HubSamplePhone
//
//  Created by Pawel Kadluczka on 2/11/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//

import UIKit
import SignalRClient

struct MessageData: Decodable {
    let user: String
    let message: String
}

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    // Update the Url accordingly
    private let serverUrl = "http://192.168.1.109:4060/chat"  // /chat or /chatLongPolling or /chatWebSockets
    private let dispatchQueue = DispatchQueue(label: "hubsamplephone.queue.dispatcheueu")

    @ReadWriteLock private var chatHubConnection: HubConnection?
    private var name = ""
    private var messages: [String] = []
    private var reconnectAlert: UIAlertController?
    private var startTask: Task<Void,Error>?
    private let restartQueue = DispatchQueue(label: "ThreadSafeRestart")
    @FairLock var connections: [HubConnection] = []

    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var msgTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.chatTableView.delegate = self
        self.chatTableView.dataSource = self

//        let queue = DispatchQueue(label: "test")
//        queue.async() { [weak self] in
//            (1...50).forEach { index in
//                // Create connection on background thread with random delay
//                let queueInst = DispatchQueue(label: "test_\(index)")
//                queueInst.async() { [weak self] in
//                    guard let self else { return }
//                    let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
//                        .withLogging(minLogLevel: .debug)
//                        .withAutoReconnect()
//                        .build()
//
//                    connection.delegate = self
//                    connection.on(method: "NewMessage", callback: { _ in })
//                    connection.start()
//
//                    // Store temporarily
//                    connections.append(connection)
//
//                    // Stop after random delay (while receive might be pending)
//                    DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 10...20)) {
//                        let currentTime = Date().timeIntervalSince1970 * 1000
//                        connection.invoke(method: "Broadcast", "name", "Hello from \(index) 1_50") { error in
//                            if let e = error {
//                                self.appendMessage(message: "Error: \(e)")
//                            }
//                            print("The message time is \((Date().timeIntervalSince1970 * 1000) - currentTime)")
//                        }
//                        DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 0.01...0.7)) {
//                            connection.stop()
//                        }
//
//                        // Remove from array to allow deallocation
//                        //                    DispatchQueue.main.async { [weak self] in
//                        ////                              self?.connections.removeAll { $0 === connection }
//                        //                    }
//                    }
//                }
//            }
//        }
    }
    
    override func viewDidAppear(_ animated: Bool) {

        let alert = UIAlertController(title: "Enter your Name", message:"", preferredStyle: UIAlertController.Style.alert)
        alert.addTextField() { textField in textField.placeholder = "Name"}
        let OKAction = UIAlertAction(title: "OK", style: .default) { [weak self] action in
            guard let self else { return }
            name = alert.textFields?.first?.text ?? "Anonymous"
//            (1...100).forEach { index in
//                let randomTimeAwait = Double.random(in: 0.1..<0.7) * Double(Int.random(in: 1..<7))
//                DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 0.1..<0.7)) { [weak self] in
//                    guard let self else { return }
//                    let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
//                        .withLogging(minLogLevel: .debug)
//                        .withAutoReconnect()
//                    chatHubConnection?.stop()
//                    chatHubConnection = connection.build()
//                    chatHubConnection!.delegate = self
//                    chatHubConnection!.on(method: "NewMessage", callback: {[weak self] data in
//                        do {
//                            let messageData = try data.getArgument(type: MessageData.self)
//                            guard let self else { return }
//                            let test = data.getArgumentsDicts()
//                            self.appendMessage(message: "\(messageData.user): \(messageData.message)")
//                        } catch (let error) {
//                            print(error.localizedDescription)
//                        }
//                    })
//                    chatHubConnection?.start()
////                    chatHubConnection?.invoke(method: "Broadcast", name, "test") { error in
////                        if let e = error {
////                            self.appendMessage(message: "Error: \(e)")
////                        }
////                    }
//                }
////                DispatchQueue.global().asyncAfter(deadline: .now() + Double.random(in: 5.1..<15.7)) { [weak self] in
////                    guard let self else { return }
////                    DispatchQueue.global().async { [weak self] in
////                        guard let self else { return }
////                        chatHubConnection?.start()
////                    }
////                    chatHubConnection?.stop()
////                }
//            }
//            (1...100).forEach { index in
                self.chatHubConnection?.stop()
                let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
                    .withLogging(minLogLevel: .debug)
                    .withAutoReconnect()
                self.chatHubConnection = connection.build()
                self.chatHubConnection!.delegate = self
                self.chatHubConnection!.on(method: "NewMessage", callback: {[weak self] data in
                    do {
                        let messageData = try data.getArgument(type: MessageData.self)
                        guard let self else { return }
                        let test = data.getArgumentsDicts()
                        self.appendMessage(message: "\(messageData.user): \(messageData.message)")
                    } catch (let error) {
                        print(error.localizedDescription)
                    }
                })
                self.chatHubConnection?.start()
//            }

//            (1...100).forEach { index in
//                  DispatchQueue.global().async {
//                      // Local variable - will be deallocated when scope exits
//                      let tempConnection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
//                          .withLogging(minLogLevel: .debug)
//                          .build()
//                      tempConnection.start()
////                      DispatchQueue.global().async {
////                          tempConnection.invoke(method: "Broadcast", "name", "Hello from \(index) 1_100") { error in
////                              if let e = error {
////                                  self.appendMessage(message: "Error: \(e)")
////                              }
////                          }
////                      }
//
//                      // Small delay then stop
//                      usleep(UInt32.random(in: 10000...100000)) // 10-100ms
//                      tempConnection.stop()
//                      // tempConnection deallocates here while callback might be pending
//                  }
//              }


//            (1...1000).forEach {_ in
//                Task.detached {
//                    self.startConnection()
//                }
//                Task.detached {
//                    self.restart()
//                }
//            }


            //This ( iteration below )  is for memroy leak test
//            (1...100).forEach { item in
//                let randomTimeAwait = Double.random(in: 0.5..<0.7) * Double(Int.random(in: 1..<7))
//                DispatchQueue.global().asyncAfter(deadline: .now() + randomTimeAwait) { [weak self] in
//                    guard let self else { return }
//                    chatHubConnection?.stop()
//                    self.chatHubConnectionDelegate = ChatHubConnectionDelegate(controller: self)
//                    let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
//                        .withLogging(minLogLevel: .debug)
//                        .withAutoReconnect()
//                        .withHubConnectionDelegate(delegate: self.chatHubConnectionDelegate!)
//                        .build()
//                    self.chatHubConnection = connection
//                    self.chatHubConnection!.on(method: "NewMessage", callback: {[weak self] data in
//                        do {
//                            let messageData = try data.getArgument(type: MessageData.self)
//                            guard let self else { return }
//                            let test = data.getArgumentsDicts()
//                            self.appendMessage(message: "\(messageData.user): \(messageData.message)")
//                        } catch (let error) {
//                            print(error.localizedDescription)
//                        }
//                    })
//                    self.chatHubConnection!.start()
////                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
////                        connection.stop()
////                    }
//                }
//            }
        }
        alert.addAction(OKAction)
        self.present(alert, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        chatHubConnection?.stop()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func btnSend(_ sender: Any) {
        let message = msgTextField.text
//        if message == "asdf" {
            chatHubConnection?.invoke(method: "Broadcast", name, message) { error in
                if let e = error {
                    self.appendMessage(message: "Error: \(e)")
                }
            }
            msgTextField.text = ""
//        }
//        if message != "" {
//            chatHubConnection?.invoke(method: "Broadcast", name, message) { error in
//                if let e = error {
//                    self.appendMessage(message: "Error: \(e)")
//                }
//            }
//            msgTextField.text = ""
//        }
    }

    @IBAction func closeBtn(_ sender: Any) {
        DispatchQueue.global().async { [weak self] in
            guard let self else { return }
            chatHubConnection?.stop()
        }
    }

    @IBAction func restartBtn(_ sender: Any) {
        restart()
    }

    private func restart() {
        restartQueue.async { [weak self] in
            guard let self else { return }
            chatHubConnection?.stop()
            chatHubConnection = nil
            startConnection()
        }
    }

    private func startConnection() {
        let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
            .withLogging(minLogLevel: .debug)
            .withAutoReconnect()
        chatHubConnection = connection.build()
        chatHubConnection?.delegate = self
        chatHubConnection?.on(method: "NewMessage", callback: {[weak self] data in
            do {
                let messageData = try data.getArgument(type: MessageData.self)
                guard let self else { return }
                let test = data.getArgumentsDicts()
                self.appendMessage(message: "\(messageData.user): \(messageData.message)")
            } catch (let error) {
                print(error.localizedDescription)
            }
        })
        chatHubConnection?.start()
    }

    private func initConnectionInstance() {
        let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
                                .withLogging(minLogLevel: .debug)
                                .withAutoReconnect()
                            chatHubConnection = connection.build()
                            chatHubConnection!.delegate = self
                            chatHubConnection!.on(method: "NewMessage", callback: {[weak self] data in
                                do {
                                    let messageData = try data.getArgument(type: MessageData.self)
                                    guard let self else { return }
                                    let test = data.getArgumentsDicts()
                                    self.appendMessage(message: "\(messageData.user): \(messageData.message)")
                                } catch (let error) {
                                    print(error.localizedDescription)
                                }
                            })
    }

    private func appendMessage(message: String) {
        self.dispatchQueue.sync {
            self.messages.append(message)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.chatTableView.reloadData()

//            self.chatTableView.beginUpdates()
//            self.chatTableView.insertRows(at: [IndexPath(row: messages.count - 1, section: 0)], with: .automatic)
//            self.chatTableView.endUpdates()
            self.chatTableView.scrollToRow(at: IndexPath(item: messages.count-1, section: 0), at: .bottom, animated: true)
        }
    }

    func blockUI(message: String, error: Error?) {
        var message = message
        if let e = error {
            message.append(" Error: \(e)")
        }
        appendMessage(message: message)
        toggleUI(isEnabled: false)
    }

    func toggleUI(isEnabled: Bool) {
        sendButton.isEnabled = isEnabled
        msgTextField.isEnabled = isEnabled
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count = -1
        dispatchQueue.sync {
            count = self.messages.count
        }
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath)
        let row = indexPath.row
        cell.textLabel?.text = messages[row]
        return cell
    }
}

extension ViewController: HubConnectionDelegate {

    func connectionDidFail(_ session: URLSession?, task: URLSessionTask?, at: TransportDidFailPoint, didCompleteWithError error: (any Error)?) {
        blockUI(message: "Connection failed to start.", error: error)
    }
    

    func connectionDidOpen(hubConnection: HubConnection) {
        toggleUI(isEnabled: true)
    }

    func connectionDidFailToOpen(error: Error) {
        blockUI(message: "Connection failed to start.", error: error)
    }

    func connectionDidClose(error: (any Error)?) {
        if let alert = reconnectAlert {
            alert.dismiss(animated: true, completion: nil)
        }
        blockUI(message: "Connection is closed.", error: error)
    }

    func connectionWillReconnect(error: Error) {
        guard reconnectAlert == nil else {
            print("Alert already present. This is unexpected.")
            return
        }

        reconnectAlert = UIAlertController(title: "Reconnecting...", message: "Please wait", preferredStyle: .alert)
        self.present(reconnectAlert!, animated: true, completion: nil)
    }

    func connectionDidReconnect() {
        reconnectAlert?.dismiss(animated: true, completion: nil)
        reconnectAlert = nil
        toggleUI(isEnabled: true)
    }

//    func connectionDidOpen(hubConnection: HubConnection) {
//        connectionDidOpen()
//    }
//
//    func connectionDidFailToOpen(error: Error) {
//        connectionDidFailToOpen(error: error)
//    }
//
//    func connectionDidClose(error: Error?) {
//        connectionDidClose(error: error)
//    }
//
//    func connectionWillReconnect(error: Error) {
//        connectionWillReconnect(error: error)
//    }
//
//    func connectionDidReconnect() {
//        connectionDidReconnect()
//    }
}
