import Foundation
import UIKit
import AVFoundation
import AVKit
import VideoToolbox
import CoreVideo

public class WirelessDisplayPlugin: NSObject, FlutterPlugin {

    static let channelName = "diatar/wireless_display"
    static let framesChannelName = "diatar/wireless_display_frames"

    private var methodChannel: FlutterMethodChannel?
    private var framesChannel: FlutterMethodChannel?

    private var compressionSession: VTCompressionSession?
    private var encoderStarted = false
    private var isStreaming = false
    private var fps = 30
    private let rtspServer = RtspIosServer()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = WirelessDisplayPlugin()
        instance.methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
        instance.framesChannel = FlutterMethodChannel(name: framesChannelName, binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.framesChannel!)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startDiscovery":
            sendConnectionState("discovering")
            sendDeviceList()
            result(nil)
        case "stopDiscovery":
            sendConnectionState(isStreaming ? "streaming" : (selectedRoute != nil ? "connected" : "disconnected"))
            result(nil)
        case "connect":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing deviceId", details: nil))
                return
            }
            selectedRoute = deviceId
            sendConnectionState("connected", deviceId: deviceId)
            result(nil)
        case "disconnect":
            stopStreamingInternal()
            selectedRoute = nil
            sendConnectionState("disconnected")
            result(nil)
        case "startStreaming":
            startStreamingInternal()
            sendConnectionState("streaming")
            result(nil)
        case "stopStreaming":
            stopStreamingInternal()
            result(nil)
        case "showSystemPicker":
            showSystemPicker(result: result)
        case "getStreamUrl":
            result("rtsp://\(RtspIosServer.localIp()):8554/diatar")
        case "startEncoding":
            fps = (call.arguments as? [String: Any])?["fps"] as? Int ?? 30
            startEncoder()
            result(nil)
        case "sendFrame":
            if let bytes = call.arguments as? FlutterStandardTypedData {
                encoderFeedPNG(Data(bytes.data))
            }
            result(nil)
        case "stopEncoding":
            stopStreamingInternal()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private var selectedRoute: String?

    private func sendConnectionState(_ state: String, deviceId: String? = nil) {
        var args: [String: Any] = ["state": state]
        if let deviceId = deviceId {
            args["deviceId"] = deviceId
        }
        methodChannel?.invokeMethod("onConnectionStateChanged", arguments: args)
    }

    private func sendDeviceList() {
        let devices: [[String: Any]] = []
        methodChannel?.invokeMethod("onDevicesChanged", arguments: devices)
    }

    // MARK: - System picker

    private func showSystemPicker(result: @escaping FlutterResult) {
        guard let viewController = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "No root view controller", details: nil))
            return
        }

        let alertController = UIAlertController(
            title: "AirPlay",
            message: "Válaszd ki a célkészüléket.", preferredStyle: .actionSheet
        )
        let pickerView = AVRoutePickerView(frame: CGRect(x: 0, y: 0, width: 260, height: 80))
        pickerView.activeTintColor = UIColor.systemBlue
        pickerView.tintColor = UIColor.systemBlue
        alertController.view.addSubview(pickerView)

        let cancelAction = UIAlertAction(title: "Mégse", style: .cancel) { _ in
            result(true)
        }
        alertController.addAction(cancelAction)

        if let popover = alertController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(alertController, animated: true)
        result(true)
    }

    private func startEncoder() {
        stopEncoderInternal()

        let width = 1920
        let height = 1080

        var sessionOut: VTCompressionSession?
        let bufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]

        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: bufferAttrs as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: { outputCallbackRefCon, _, status, flags, sampleBuffer in
                guard status == noErr, let sampleBuffer = sampleBuffer else { return }
                let plugin = Unmanaged<WirelessDisplayPlugin>.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
                plugin.handleEncodedFrame(sampleBuffer)
            },
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &sessionOut
        )

        guard status == noErr, let session = sessionOut else {
            NSLog("WirelessDisplay: failed to create compression session %d", status)
            return
        }
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Main_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: 30) as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: 10_000_000) as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: NSNumber(value: fps) as CFTypeRef)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTCompressionSessionPrepareToEncodeFrames(session)
        compressionSession = session
        encoderStarted = true

        rtspServer.start(port: 8554)
        isStreaming = true
        sendConnectionState("streaming")
    }

    private func stopEncoderInternal() {
        encoderStarted = false
        if let session = compressionSession {
            VTCompressionSessionCompleteFrames(session, untilPresentationTimeStamp: .invalid)
            VTCompressionSessionInvalidate(session)
        }
        compressionSession = nil
        rtspServer.stop()
        isStreaming = false
    }

    private func stopStreamingInternal() {
        stopEncoderInternal()
        sendConnectionState(selectedRoute != nil ? "connected" : "disconnected")
    }

    private func encoderFeedPNG(_ pngData: Data) {
        guard encoderStarted, let session = compressionSession else { return }
        guard let pixelBuffer = makePixelBuffer(fromPNG: pngData, width: 1920, height: 1080) else { return }

        let time = CMTime(value: CMTimeValue(frameCounter), timescale: CMTimeScale(fps))
        frameCounter += 1
        VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: time,
            duration: CMTime(value: 1, timescale: CMTimeScale(fps)),
            frameProperties: nil,
            infoFlagsOut: nil,
            outputHandler: { _, _, _ in }
        )
    }

    private var frameCounter: Int64 = 0

    private func handleEncodedFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        if let description = CMSampleBufferGetFormatDescription(sampleBuffer),
           let (sps, pps) = extractParameterSets(from: description) {
            rtspServer.setParameterSets(sps: sps, pps: pps)
        }

        var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let ptsSeconds = CMTimeGetSeconds(pts)
        let ptsNs = Int64((ptsSeconds.isFinite ? ptsSeconds : 0) * 1_000_000_000)

        var length: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: &length, dataPointerOut: &dataPointer)
        guard let pointer = dataPointer, length > 0 else { return }

        let avccData = Data(bytes: pointer, count: length)
        let annexB = avccToAnnexB(avccData)
        if !annexB.isEmpty {
            rtspServer.sendH264(annexB, ptsNs: ptsNs)
        }
    }

    private func extractParameterSets(from formatDescription: CMFormatDescription) -> (sps: Data, pps: Data)? {
        let descriptionKeys: Set<CFString> = [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms]
        guard let extensions = CMFormatDescriptionGetExtensions(formatDescription) as? [CFString: Any] else { return nil }
        guard let atoms = extensions[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms] as? [String: Data] else { return nil }
        guard let avcC = atoms["avcC"] else { return nil }

        var payload = [UInt8](avcC)
        var offset = 0
        func readU8() -> UInt8? {
            guard offset < payload.count else { return nil }
            let value = payload[offset]
            offset += 1
            return value
        }
        func readU16() -> UInt16? {
            guard offset + 2 <= payload.count else { return nil }
            let value = (UInt16(payload[offset]) << 8) | UInt16(payload[offset + 1])
            offset += 2
            return value
        }
        func readU32() -> UInt32? {
            guard offset + 4 <= payload.count else { return nil }
            let value = (UInt32(payload[offset]) << 24) | (UInt32(payload[offset + 1]) << 16) |
                (UInt32(payload[offset + 2]) << 8) | UInt32(payload[offset + 3])
            offset += 4
            return value
        }
        func readLengthPrefixed() -> Data? {
            guard let len = readU16(), offset + Int(len) <= payload.count else { return nil }
            let data = Data(payload[offset..<offset + Int(len)])
            offset += Int(len)
            return data
        }

        offset = 0
        guard readU8() == 1 else { return nil }
        readU8()
        readU8()
        readU8()
        _ = readU8()
        let numSPS = Int(readU8() ?? 0) & 0x1F
        guard numSPS > 0, let sps = readLengthPrefixed() else { return nil }
        let numPPS = Int(readU8() ?? 0)
        guard numPPS > 0, let pps = readLengthPrefixed() else { return nil }
        return (sps, pps)
    }

    private func avccToAnnexB(_ avcc: Data) -> Data {
        let bytes = [UInt8](avcc)
        var out = Data()
        var i = 0
        while i + 4 <= bytes.count {
            let length = (Int(bytes[i]) << 24) | (Int(bytes[i + 1]) << 16) | (Int(bytes[i + 2]) << 8) | Int(bytes[i + 3])
            if length < 0 || i + 4 + length > bytes.count {
                break
            }
            out.append(contentsOf: [0, 0, 0, 1])
            out.append(contentsOf: bytes[i + 4..<i + 4 + length])
            i += 4 + length
        }
        return out
    }

    private func makePixelBuffer(fromPNG pngData: Data, width: Int, height: Int) -> CVPixelBuffer? {
        guard let image = UIImage(data: pngData), let cgImage = image.cgImage else { return nil }

        var pixelBufferOut: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            attrs as CFDictionary,
            &pixelBufferOut
        )
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let uvBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            return nil
        }
        let yRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let uvRowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

        let rgbaRowBytes = width * 4
        var rgba = [UInt8](repeating: 0, count: height * rgbaRowBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: &rgba,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rgbaRowBytes,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        ctx?.clear(CGRect(x: 0, y: 0, width: width, height: height))
        ctx?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let yPlane = yBase.assumingMemoryBound(to: UInt8.self)
        let uvPlane = uvBase.assumingMemoryBound(to: UInt8.self)

        for row in 0..<height {
            for col in 0..<width {
                let rgbaIndex = (height - 1 - row) * rgbaRowBytes + col * 4
                let r = CGFloat(rgba[rgbaIndex])
                let g = CGFloat(rgba[rgbaIndex + 1])
                let b = CGFloat(rgba[rgbaIndex + 2])
                let y = UInt8(((66 * r + 129 * g + 25 * b + 128) / 256) + 16)
                yPlane[row * yRowBytes + col] = y
            }
        }

        for row in 0..<(height / 2) {
            for col in 0..<(width / 2) {
                let srcRow = row * 2
                let srcCol = col * 2
                let r = CGFloat(rgba[(height - 1 - srcRow) * rgbaRowBytes + srcCol * 4])
                let g = CGFloat(rgba[(height - 1 - srcRow) * rgbaRowBytes + srcCol * 4 + 1])
                let b = CGFloat(rgba[(height - 1 - srcRow) * rgbaRowBytes + srcCol * 4 + 2])
                let u = UInt8(((-38 * r - 74 * g + 112 * b + 128) / 256) + 128)
                let v = UInt8(((112 * r - 94 * g - 18 * b + 128) / 256) + 128)
                let uvIndex = row * uvRowBytes + col * 2
                uvPlane[uvIndex] = u
                uvPlane[uvIndex + 1] = v
            }
        }
        return pixelBuffer
    }
}

// MARK: - RTSP

class RtspIosServer {
    private var serverFD: Int32 = -1
    private var socketsLock = NSLock()
    private var clients: [Int32] = []
    private var running = false
    private var queue = DispatchQueue(label: "diatar.rtsp")
    private var sendQueue = DispatchQueue(label: "diatar.rtsp.send")

    var sps: Data?
    var pps: Data?
    private let ssrc: UInt32 = 0x12345678
    private let sessionId = "12345678"

    func setParameterSets(sps: Data, pps: Data) {
        self.sps = sps
        self.pps = pps
    }

    func start(port: UInt16) {
        guard !running else { return }
        running = true
        queue.async { [weak self] in
            self?.serverLoop(port: port)
        }
    }

    func stop() {
        running = false
        socketsLock.lock()
        let _ = clients
        socketsLock.unlock()
        if serverFD >= 0 {
            close(serverFD)
            serverFD = -1
        }
    }

    private func serverLoop(port: UInt16) {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        serverFD = fd
        var opt: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            return
        }
        listen(fd, 4)

        while running {
            let clientFD = accept(fd, nil, nil)
            guard clientFD >= 0 else { continue }
            socketsLock.lock()
            clients.append(clientFD)
            socketsLock.unlock()
            let clientQueue = DispatchQueue(label: "diatar.rtsp.client")
            clientQueue.async { [weak self] in
                self?.handleClient(clientFD)
            }
        }
    }

    private func handleClient(_ clientFD: Int32) {
        defer { close(clientFD) }
        var isPlaying = false
        var input = Data()
        var socket = clientFD
        let bufferSize = 4096

        func setPlaying(_ value: Bool) { isPlaying = value }

        func readLine() -> String? {
            while true {
                if let range = input.range(of: Data("\r\n".utf8)) {
                    let lineData = input[input.startIndex..<range.lowerBound]
                    input.removeSubrange(input.startIndex..<range.upperBound)
                    return String(data: Data(lineData), encoding: .utf8)
                }
                var buffer = [UInt8](repeating: 0, count: bufferSize)
                let n = read(socket, &buffer, bufferSize)
                if n <= 0 { return nil }
                input.append(contentsOf: buffer[0..<n])
            }
        }

        func respond(_ status: String, headers: String, body: String = "") {
            var text = "RTSP/1.0 \(status)\r\nCSeq: 1\r\nServer: DiatarRtsp/1.0\r\n"
            text += headers
            if !text.hasSuffix("\r\n\r\n") {
                if text.hasSuffix("\r\n") {
                    text += "\r\n"
                }
            }
            text += body
            let data = Data(text.utf8)
            data.withUnsafeBytes { _ = write(socket, $0.baseAddress!, data.count) }
        }

        while running {
            guard let line = readLine(), !line.isEmpty else { break }
            if !line.contains("RTSP/1.0") { continue }
            let method = line.components(separatedBy: " ").first ?? ""

            switch method {
            case "OPTIONS":
                respond("200 OK", headers: "Public: OPTIONS, DESCRIBE, SETUP, PLAY, TEARDOWN\r\n")
            case "DESCRIBE":
                let body = describeBody()
                let contentLength = body.utf8.count
                respond("200 OK", headers: "Content-Type: application/sdp\r\nContent-Length: \(contentLength)\r\n", body: body)
            case "SETUP":
                respond("200 OK", headers: "Transport: RTP/AVP/TCP;unicast;interleaved=0-1;ssrc=\(String(ssrc, radix: 16))\r\nSession: \(sessionId)\r\n")
            case "PLAY":
                setPlaying(true)
                respond("200 OK", headers: "Range: npt=0.000-\r\nSession: \(sessionId)\r\n")
            case "TEARDOWN":
                respond("200 OK", headers: "")
                setPlaying(false)
                return
            default:
                respond("501 Not Implemented", headers: "")
            }
        }
    }

    private func describeBody() -> String {
        var profile = "42001f"
        var sprop = ""
        if let sps = sps, let pps = pps {
            sprop = "; sprop-parameter-sets=\(sps.base64EncodedString()),\(pps.base64EncodedString())"
        }
        var s = "v=0\r\n"
        s += "o=- 1 1 IN IP4 0.0.0.0\r\n"
        s += "s=Diatar Projection\r\n"
        s += "c=IN IP4 0.0.0.0\r\n"
        s += "t=0 0\r\n"
        s += "a=range:npt=0-\r\n"
        s += "m=video 0 RTP/AVP 96\r\n"
        s += "a=rtpmap:96 H264/90000\r\n"
        s += "a=fmtp:96 packetization-mode=1; profile-level-id=\(profile)\(sprop)\r\n"
        s += "a=control:track1\r\n"
        return s
    }

    func sendH264(_ annexB: Data, ptsNs: Int64) {
        guard running else { return }
        socketsLock.lock()
        let snapshot = clients
        socketsLock.unlock()
        guard !snapshot.isEmpty else { return }

        let nals = parseNals(annexB)
        let ts = UInt32(clamping: (ptsNs / 1000) * 90)

        sendQueue.async { [weak self] in
            for clientFD in snapshot {
                for nal in nals {
                    guard nal.count >= 2 else { continue }
                    let nalType = Int(nal[0]) & 0x1F
                    if nalType == 7 || nalType == 8 {
                        self?.sendSingleNal(clientFD, nal: nal, ts: ts)
                    } else {
                        self?.packetizeNal(clientFD, nal: nal, ts: ts)
                    }
                }
            }
        }
    }

    private func packetizeNal(_ fd: Int32, nal: Data, ts: UInt32) {
        let bytes = [UInt8](nal)
        let header = Int(bytes[0])
        let nalType = header & 0x1F
        let maxPayload = 1200
        if bytes.count <= maxPayload {
            sendSingleNal(fd, nal: nal, ts: ts)
            return
        }
        let fuIndicator = UInt8(((header & 0x60) | (0x1C & 0x1F)))
        let n = (bytes.count - 1 + maxPayload - 1) / maxPayload
        for i in 0..<n {
            let offset = 1 + i * maxPayload
            let length = min(maxPayload, bytes.count - 1 - i * maxPayload)
            let fuHeader = UInt8(((i == 0 ? 1 : 0) << 7) | ((i == n - 1 ? 1 : 0) << 6) | (nalType & 0x1F))
            var payload = [UInt8]()
            payload.append(fuIndicator)
            payload.append(fuHeader)
            payload.append(contentsOf: bytes[offset..<offset + length])
            sendRtp(fd, payload: payload, ts: ts, marker: i == n - 1 ? 1 : 0)
        }
    }

    private func sendSingleNal(_ fd: Int32, nal: Data, ts: UInt32) {
        sendRtp(fd, payload: [UInt8](nal), ts: ts, marker: 1)
    }

    private func sendRtp(_ fd: Int32, payload: [UInt8], ts: UInt32, marker: Int) {
        var seq: UInt16 = 0
        socketsLock.lock()
        seq = nextSequence
        nextSequence += 1
        socketsLock.unlock()
        let payloadLen = payload.count
        var rtp = [UInt8](repeating: 0, count: 12 + payloadLen)
        rtp[0] = 0x80
        rtp[1] = UInt8((marker << 7) | (96 & 0x7F))
        rtp[2] = UInt8((seq >> 8) & 0xFF)
        rtp[3] = UInt8(seq & 0xFF)
        rtp[4] = UInt8((ts >> 24) & 0xFF)
        rtp[5] = UInt8((ts >> 16) & 0xFF)
        rtp[6] = UInt8((ts >> 8) & 0xFF)
        rtp[7] = UInt8(ts & 0xFF)
        rtp[8] = UInt8((ssrc >> 24) & 0xFF)
        rtp[9] = UInt8((ssrc >> 16) & 0xFF)
        rtp[10] = UInt8((ssrc >> 8) & 0xFF)
        rtp[11] = UInt8(ssrc & 0xFF)
        rtp.replaceSubrange(12..<(12 + payloadLen), with: payload)

        var header = [UInt8](repeating: 0, count: 4)
        header[0] = 0x24
        header[1] = 0
        header[2] = UInt8((rtp.count >> 8) & 0xFF)
        header[3] = UInt8(rtp.count & 0xFF)
        header.withUnsafeBytes { _ = write(fd, $0.baseAddress!, header.count) }
        rtp.withUnsafeBytes { _ = write(fd, $0.baseAddress!, rtp.count) }
    }

    private var nextSequence: UInt16 = 0

    private func parseNals(_ data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var result: [Data] = []
        var i = 0
        while i < bytes.count - 3 {
            let start: Int?
            if bytes[i] == 0 && bytes[i + 1] == 0 && bytes[i + 2] == 1 {
                start = i
            } else if i + 3 < bytes.count, bytes[i] == 0, bytes[i + 1] == 0, bytes[i + 2] == 0, bytes[i + 3] == 1 {
                start = i
            } else {
                start = nil
            }
            guard let s = start else {
                i += 1
                continue
            }
            let size = (bytes[s] == 0 && bytes[s + 1] == 0 && bytes[s + 2] == 0 && s + 3 < bytes.count && bytes[s + 3] == 1) ? 4 : 3
            let naluStart = s + size
            var j = naluStart
            var nextStart: Int? = nil
            while j < bytes.count - 3 {
                if bytes[j] == 0 && bytes[j + 1] == 0 && bytes[j + 2] == 1 {
                    nextStart = j
                    break
                }
                if j + 3 < bytes.count, bytes[j] == 0, bytes[j + 1] == 0, bytes[j + 2] == 0, bytes[j + 3] == 1 {
                    nextStart = j
                    break
                }
                j += 1
            }
            let end = nextStart ?? bytes.count
            if end > naluStart {
                result.append(Data(bytes[naluStart..<end]))
            }
            if nextStart == nil { break }
            i = nextStart!
        }
        return result
    }

    static func localIp() -> String {
        var address = "127.0.0.1"
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddrPtr) == 0 {
            var ptr = ifaddrPtr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                guard let ifa = ptr?.pointee else { continue }
                let family = ifa.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    let name = String(cString: ifa.ifa_name)
                    if name.hasPrefix("en") {
                        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                        let hostString = String(cString: host)
                        if !hostString.hasPrefix("169.254") && hostString != "0.0.0.0" {
                            address = hostString
                        }
                    }
                }
            }
            freeifaddrs(ifaddrPtr)
        }
        return address
    }
}