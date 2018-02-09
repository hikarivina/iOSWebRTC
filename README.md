# SwiftでWebRTC
Clone from [tnoho/WebRTCHandsOn](https://github.com/tnoho/WebRTCHandsOn)
And modify to using Firebase database for SDP signaling

# Usage

### 1. Config your [Firebase project](https://firebase.google.com/docs/database/ios/start?authuser=0)
+ Make your database rule allow read/write at `Call/`:
```
"Call": {
".read": true,
".write": true
}
```
### 2. Build:
you need use 2 device to test conection
+ Before build app on first one, make sure
```
var sender: Int = 1
var receiver: Int = 2
```
in `ChatViewController`

+ And change it when build the second:
```
var sender: Int = 2
var receiver: Int = 1
```
