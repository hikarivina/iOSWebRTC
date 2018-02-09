//
//  ChatViewController.swift
//  WebRTCHandsOn
//
//  Created by Takumi Minamoto on 2017/05/27.
//  Copyright © 2017 tnoho. All rights reserved.
//

import UIKit
import WebRTC
import SwiftyJSON
import Firebase

class ChatViewController: UIViewController {
    
    var peerConnectionFactory: RTCPeerConnectionFactory! = nil
    var peerConnection: RTCPeerConnection! = nil
    var remoteVideoTrack: RTCVideoTrack?
    var audioSource: RTCAudioSource?
    var videoSource: RTCAVFoundationVideoSource?
    
    var observerSignalRef: DatabaseReference?
    var offerSignalRef: DatabaseReference?
    
    var sender: Int = 1
    var receiver: Int = 2

    @IBOutlet weak var cameraPreview: RTCCameraPreviewView!
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    
    
    deinit {
        if peerConnection != nil {
            hangUp()
        }
        audioSource = nil
        videoSource = nil
        peerConnectionFactory = nil
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.remoteVideoView.delegate = self
        // RTCPeerConnectionFactoryの初期化
        self.peerConnectionFactory = RTCPeerConnectionFactory()
        
        self.startVideo()
        self.setupFirebase()
    }
    
    
    func setupFirebase() {
        
        self.observerSignalRef = Database.database().reference().child("Call/\(receiver)")
        self.offerSignalRef = Database.database().reference().child("Call/\(sender)")
        
        self.offerSignalRef?.onDisconnectRemoveValue()
        self.observerSingnal()
    }
    
    
    
    func observerSingnal() {
        
        self.observerSignalRef?.observe(.value, with: { (snapshot) in
            
            guard snapshot.exists() else { return }
            LOG("message: \(snapshot.value ?? "NO Value")")
            // 受け取ったメッセージをJSONとしてパース
            let jsonMessage = JSON(snapshot.value!)
            let type = jsonMessage["type"].stringValue
            switch (type) {
            case "offer":
                // offerを受け取った時の処理
                LOG("Received offer ...")
                let offer = RTCSessionDescription(
                    type: RTCSessionDescription.type(for: type),
                    sdp: jsonMessage["sdp"].stringValue)
                self.setOffer(offer)
            case "answer":
                // answerを受け取った時の処理
                LOG("Received answer ...")
                let answer = RTCSessionDescription(
                    type: RTCSessionDescription.type(for: type),
                    sdp: jsonMessage["sdp"].stringValue)
                self.setAnswer(answer)
            case "candidate":
                LOG("Received ICE candidate ...")
                let candidate = RTCIceCandidate(
                    sdp: jsonMessage["ice"]["candidate"].stringValue,
                    sdpMLineIndex: jsonMessage["ice"]["sdpMLineIndex"].int32Value,
                    sdpMid: jsonMessage["ice"]["sdpMid"].stringValue)
                self.addIceCandidate(candidate)
            case "close":
                LOG("peer is closed ...")
                self.hangUp()
            default:
                return
            }
        })
        
    }
    
    

    
    func startVideo() {
        // 音声ソースの設定
        let audioSourceConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        // 音声ソースの生成
        audioSource = peerConnectionFactory.audioSource(with: audioSourceConstraints)
        
        // 映像ソースの設定
        let videoSourceConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        videoSource = peerConnectionFactory.avFoundationVideoSource(with: videoSourceConstraints)
        // 映像ソースをプレビューに設定
        cameraPreview.captureSession = videoSource?.captureSession
    }
    
    
    func prepareNewConnection() -> RTCPeerConnection {
        // STUN/TURNサーバーの指定
        let configuration = RTCConfiguration()
        configuration.iceServers = [RTCIceServer.init(urlStrings: ["stun:stun.l.google.com:19302"])]
        
        // PeerConecctionの設定(今回はなし)
        let peerConnectionConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        // PeerConnectionの初期化
        let peerConnection = peerConnectionFactory.peerConnection(with: configuration, constraints: peerConnectionConstraints, delegate: self)
        
        // 音声トラックの作成
        let localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource!, trackId: "ARDAMSa0")
        // PeerConnectionからSenderを作成
        let audioSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindAudio, streamId: "ARDAMS")
        // Senderにトラックを設定
        audioSender.track = localAudioTrack
        
        
        // 映像トラックの作成
        let localVideoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "ARDAMSv0")
        // PeerConnectionからVideoのSenderを作成
        let videoSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindVideo, streamId: "ARDAMS")
        // Senderにトラックを設定
        videoSender.track = localVideoTrack
        
        return peerConnection
    }
    
  
    @IBAction func connectButtonAction(_ sender: Any) {
        // Connectボタンを押した時
        if peerConnection == nil {
            LOG("make Offer")
            makeOffer()
        } else {
            LOG("peer already exist.")
        }
    }
    
    
    func makeOffer() {
        
        peerConnection = prepareNewConnection() // PeerConnectionを生成
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"],
                                              optionalConstraints: nil) // Offerの設定 今回は映像も音声も受け取る
        let offerCompletion = { (offer: RTCSessionDescription?, error: Error?) in // Offerの生成が完了した際の処理
            
            if error != nil { return }
            LOG("createOffer() succsess")
            let setLocalDescCompletion = {(error: Error?) in // setLocalDescCompletionが完了した際の処理
                
                if error != nil { return }
                LOG("setLocalDescription() succsess")
                
                self.sendSDP(offer!) // 相手に送る
            }
            
            self.peerConnection.setLocalDescription(offer!, completionHandler: setLocalDescCompletion) // 生成したOfferを自分のSDPとして設定
        }
        
        
        self.peerConnection.offer(for: constraints, completionHandler: offerCompletion) // Offerを生成
    }
    
    
    func makeAnswer() {
        LOG("sending Answer. Creating remote session description...")
        if peerConnection == nil {
            LOG("peerConnection NOT exist!")
            return
        }
        
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let answerCompletion = { (answer: RTCSessionDescription?, error: Error?) in
            if error != nil { return }
            LOG("createAnswer() succsess")
            let setLocalDescCompletion = {(error: Error?) in
                if error != nil { return }
                LOG("setLocalDescription() succsess")
                
                self.sendSDP(answer!) // 相手に送る
            }
            self.peerConnection.setLocalDescription(answer!, completionHandler: setLocalDescCompletion)
        }
        
        self.peerConnection.answer(for: constraints, completionHandler: answerCompletion) // Answerを生成
    }
    
    
    func sendSDP(_ desc: RTCSessionDescription) {
        LOG("---sending sdp ---")
        
        let jsonSdp: JSON = [ // JSONを生成
            "sdp": desc.sdp, // SDP本体
            "type": RTCSessionDescription.string(for: desc.type) // offer か answer か
        ]
        let message = jsonSdp.dictionaryObject

        
        self.offerSignalRef?.setValue(message) { (error, ref) in // 相手に送信
            if error != nil {
                print("Dang sendIceCandidate -->> ", error.debugDescription)
            }
        }
    }
    
    
    func setOffer(_ offer: RTCSessionDescription) {
        if peerConnection != nil {
            LOG("peerConnection alreay exist!")
        }
        
        peerConnection = prepareNewConnection() // PeerConnectionを生成する
        self.peerConnection.setRemoteDescription(offer, completionHandler: {(error: Error?) in
            if error == nil {
                LOG("setRemoteDescription(offer) succsess")
                self.makeAnswer() // setRemoteDescriptionが成功したらAnswerを作る
            } else {
                LOG("setRemoteDescription(offer) ERROR: " + error.debugDescription)
            }
        })
    }
    
    
    func setAnswer(_ answer: RTCSessionDescription) {
        if peerConnection == nil {
            LOG("peerConnection NOT exist!")
            return
        }
        
        self.peerConnection.setRemoteDescription(answer, completionHandler: { // 受け取ったSDPを相手のSDPとして設定
            (error: Error?) in
            if error == nil {
                LOG("setRemoteDescription(answer) succsess")
            } else {
                LOG("setRemoteDescription(answer) ERROR: " + error.debugDescription)
            }
        })
    }
    
    
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        if peerConnection != nil {
            peerConnection.add(candidate)
        } else {
            LOG("PeerConnection not exist!")
        }
    }
    
    
    @IBAction func hangupButtonAction(_ sender: Any) {
        
        hangUp() // HangUpボタンを押した時
    }
    
    
    func hangUp() {
        if peerConnection != nil {
            if peerConnection.iceConnectionState != RTCIceConnectionState.closed {
                peerConnection.close()
                let jsonClose: JSON = [
                    "type": "close"
                ]
                
                let message = jsonClose.dictionaryObject
                LOG("sending close message")
                let ref = Database.database().reference().child("Call/\(sender)")
                ref.setValue(message) { (error, ref) in
                    print("Dang send SDP Error -->> ", error.debugDescription)
                }
                
            }
            if remoteVideoTrack != nil {
                remoteVideoTrack?.remove(remoteVideoView)
            }
            
            remoteVideoTrack = nil
            peerConnection = nil
            LOG("peerConnection is closed.")
        }
    }
    
    
    @IBAction func closeButtonAction(_ sender: Any) {
        // Closeボタンを押した時
        hangUp()
        _ = self.navigationController?.popToRootViewController(animated: true)
    }
    
}




// MARK: - Peer Connection
extension ChatViewController: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        // 接続情報交換の状況が変化した際に呼ばれます
        print("\(#function): 接続情報交換の状況が変化した際に呼ばれます")
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        // 映像/音声が追加された際に呼ばれます
        LOG("-- peer.onaddstream()")
        DispatchQueue.main.async(execute: { () -> Void in
            // mainスレッドで実行
            if (stream.videoTracks.count > 0) {
                // ビデオのトラックを取り出して
                self.remoteVideoTrack = stream.videoTracks[0]
                // remoteVideoViewに紐づける
                self.remoteVideoTrack?.add(self.remoteVideoView)
            }
        })
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        // 映像/音声削除された際に呼ばれます
    }
    
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        // 接続情報の交換が必要になった際に呼ばれます
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        // PeerConnectionの接続状況が変化した際に呼ばれます
        var state = ""
        switch (newState) {
        case RTCIceConnectionState.checking: state = "checking"
        case RTCIceConnectionState.completed: state = "completed"
        case RTCIceConnectionState.connected: state = "connected"
        case RTCIceConnectionState.closed:
            state = "closed"
            hangUp()
        case RTCIceConnectionState.failed:
            state = "failed"
            hangUp()
        case RTCIceConnectionState.disconnected: state = "disconnected"
        default: break
        }
        LOG("ICE connection Status has changed to \(state)")
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        // 接続先候補の探索状況が変化した際に呼ばれます
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // Candidate(自分への接続先候補情報)が生成された際に呼ばれます
        if candidate.sdpMid != nil {
            sendIceCandidate(candidate)
        } else {
            LOG("empty ice event")
        }
    }
    
    
    func sendIceCandidate(_ candidate: RTCIceCandidate) {
        LOG("---sending ICE candidate ---")
        let jsonCandidate: JSON = [
            "type": "candidate",
            "ice": [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid!
            ]
        ]

        let message = jsonCandidate.dictionaryObject
        
        self.offerSignalRef?.setValue(message) { (error, ref) in
            if error != nil {
                print("Dang sendIceCandidate -->> ", error.debugDescription)
            }
        }
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        // DataChannelが作られた際に呼ばれます
    }
    
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        // Candidateが削除された際に呼ばれます
    }
    
}



// MARK: - RTCEAGLVideoViewDelegate
extension ChatViewController: RTCEAGLVideoViewDelegate {
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        let width = self.view.frame.width
        let height = self.view.frame.width * size.height / size.width
        videoView.frame = CGRect(
            x: 0,
            y: (self.view.frame.height - height) / 2,
            width: width,
            height: height)
    }
}



// 参考にさせていただきました！Thanks: http://seesaakyoto.seesaa.net/article/403680516.html
func LOG(_ body: String = "", function: String = #function, line: Int = #line) {
    print("[\(function) : \(line)] \(body)")
}








