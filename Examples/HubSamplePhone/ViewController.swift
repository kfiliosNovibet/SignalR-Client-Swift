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
    private let serverUrl = "http://192.168.1.128:5000/chat"  // /chat or /chatLongPolling or /chatWebSockets
    private let dispatchQueue = DispatchQueue(label: "hubsamplephone.queue.dispatcheueuq")

    private var chatHubConnection: HubConnection?
    private var chatHubConnectionDelegate: HubConnectionDelegate?
    private var name = ""
    private var messages: [String] = []
    private var reconnectAlert: UIAlertController?

    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var chatTableView: UITableView!
    @IBOutlet weak var msgTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.chatTableView.delegate = self
        self.chatTableView.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let alert = UIAlertController(title: "Enter your Name", message:"", preferredStyle: UIAlertController.Style.alert)
        alert.addTextField() { textField in textField.placeholder = "Name"}
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            //This ( iteration below )  is for memroy leak test
//            (1...100).forEach { item in
//                let randomTimeAwait = Double.random(in: 0.5..<0.7) * Double(Int.random(in: 1..<7))
//                DispatchQueue.global().asyncAfter(deadline: .now() + randomTimeAwait) { [weak self] in
//                    guard let self else { return }
                    self.chatHubConnectionDelegate = ChatHubConnectionDelegate(controller: self)
                    let connection = HubConnectionBuilder(url: URL(string: self.serverUrl)!)
                        .withLogging(minLogLevel: .debug)
                        .withAutoReconnect()
                        .withHubConnectionDelegate(delegate: self.chatHubConnectionDelegate!)
                        .build()
                    self.chatHubConnection = connection
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
                    self.chatHubConnection!.start()
//                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
//                        connection.stop()
//                    }
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
        if message != "" {
            chatHubConnection?.invoke(method: "Broadcast", name, message) { error in
                if let e = error {
                    self.appendMessage(message: "Error: \(e)")
                }
            }
            msgTextField.text = ""
        }
    }

    private func appendMessage(message: String) {
        self.dispatchQueue.sync {
            self.messages.append(message)
        }

        self.chatTableView.beginUpdates()
        self.chatTableView.insertRows(at: [IndexPath(row: messages.count - 1, section: 0)], with: .automatic)
        self.chatTableView.endUpdates()
        self.chatTableView.scrollToRow(at: IndexPath(item: messages.count-1, section: 0), at: .bottom, animated: true)
    }

    fileprivate func connectionDidOpen() {
        toggleUI(isEnabled: true)
    }

    fileprivate func connectionDidFailToOpen(error: Error) {
        blockUI(message: "Connection failed to start.", error: error)
    }

    fileprivate func connectionDidClose(error: Error?) {
        if let alert = reconnectAlert {
            alert.dismiss(animated: true, completion: nil)
        }
        blockUI(message: "Connection is closed.", error: error)
    }

    fileprivate func connectionWillReconnect(error: Error?) {
        guard reconnectAlert == nil else {
            print("Alert already present. This is unexpected.")
            return
        }

        reconnectAlert = UIAlertController(title: "Reconnecting...", message: "Please wait", preferredStyle: .alert)
        self.present(reconnectAlert!, animated: true, completion: nil)
    }

    fileprivate func connectionDidReconnect() {
        reconnectAlert?.dismiss(animated: true, completion: nil)
        reconnectAlert = nil
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

class ChatHubConnectionDelegate: HubConnectionDelegate {

    weak var controller: ViewController?

    init(controller: ViewController) {
        self.controller = controller
    }

    func connectionDidOpen(hubConnection: HubConnection) {
        controller?.connectionDidOpen()
    }

    func connectionDidFailToOpen(error: Error) {
        controller?.connectionDidFailToOpen(error: error)
    }

    func connectionDidClose(error: Error?) {
        controller?.connectionDidClose(error: error)
    }

    func connectionWillReconnect(error: Error) {
        controller?.connectionWillReconnect(error: error)
    }

    func connectionDidReconnect() {
        controller?.connectionDidReconnect()
    }
}
