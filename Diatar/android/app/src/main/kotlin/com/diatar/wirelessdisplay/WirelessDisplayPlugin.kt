package com.diatar.wirelessdisplay

import android.content.Context
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import androidx.mediarouter.media.MediaControlIntent
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.ByteBuffer

class WirelessDisplayPlugin :
    FlutterPlugin,
    MethodCallHandler,
    MediaRouter.Callback() {

    private val tag = "WirelessDisplayPlugin"
    private var methodChannel: MethodChannel? = null
    private var framesChannel: MethodChannel? = null

    private var mediaRouter: MediaRouter? = null
    private var mediaRouteSelector: MediaRouteSelector? = null
    private var currentRouteId: String? = null

    private var encoder: H264Encoder? = null
    private var streamServer: RtspServer? = null
    private var streaming = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context: Context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "diatar/wireless_display")
        methodChannel?.setMethodCallHandler(this)
        framesChannel = MethodChannel(binding.binaryMessenger, "diatar/wireless_display_frames")
        framesChannel?.setMethodCallHandler(this)

        mediaRouter = MediaRouter.getInstance(context)
        mediaRouteSelector = MediaRouteSelector.Builder()
            .addControlCategory(MediaControlIntent.CATEGORY_REMOTE_PLAYBACK)
            .addControlCategory(MediaControlIntent.CATEGORY_LIVE_VIDEO)
            .build()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopStreaming()
        mediaRouter?.removeCallback(this)
        mediaRouter = null
        mediaRouteSelector = null
        currentRouteId = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        framesChannel?.setMethodCallHandler(null)
        framesChannel = null
    }

    override fun onRouteAdded(router: MediaRouter, route: MediaRouter.RouteInfo) {
        sendDeviceList()
    }

    override fun onRouteRemoved(router: MediaRouter, route: MediaRouter.RouteInfo) {
        sendDeviceList()
    }

    override fun onRouteChanged(router: MediaRouter, route: MediaRouter.RouteInfo) {
        sendDeviceList()
    }

    override fun onRouteSelected(router: MediaRouter, route: MediaRouter.RouteInfo, reason: Int) {
        currentRouteId = route.id
        sendConnectionState("connected", route.id)
    }

    override fun onRouteUnselected(router: MediaRouter, route: MediaRouter.RouteInfo, reason: Int) {
        if (streaming) {
            stopStreaming()
        }
        currentRouteId = null
        sendConnectionState("disconnected")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startDiscovery" -> {
                val router = mediaRouter
                val selector = mediaRouteSelector
                if (router != null && selector != null) {
                    router.addCallback(selector, this, MediaRouter.CALLBACK_FLAG_REQUEST_DISCOVERY)
                }
                sendDeviceList()
                result.success(null)
            }

            "stopDiscovery" -> {
                mediaRouter?.removeCallback(this)
                result.success(null)
            }

            "connect" -> {
                val deviceId = call.argument<String>("deviceId") ?: ""
                val selector = mediaRouteSelector
                val route = mediaRouter?.routes?.firstOrNull { it.id == deviceId }
                if (route == null || selector == null) {
                    result.error("DEVICE_NOT_FOUND", "Device not found: $deviceId", null)
                } else {
                    currentRouteId = deviceId
                    sendConnectionState("connecting", deviceId)
                    mediaRouter?.selectRoute(route)
                    result.success(null)
                }
            }

            "disconnect" -> {
                disconnect()
                result.success(null)
            }

            "startStreaming" -> {
                startStreamingInternal()
                result.success(null)
            }

            "stopStreaming" -> {
                stopStreaming()
                result.success(null)
            }

            "showSystemPicker" -> {
                result.success(false)
            }

            "getStreamUrl" -> {
                val ip = streamServer?.localIp ?: RtspServer.localIp()
                result.success("rtsp://$ip:8554/diatar")
            }

            "startEncoding" -> {
                val fps = call.argument<Int>("fps") ?: 30
                startEncodingInternal(fps)
                result.success(null)
            }

            "sendFrame" -> {
                val bytes = call.arguments as ByteArray
                encoder?.feedPng(bytes)
                result.success(null)
            }

            "stopEncoding" -> {
                stopStreaming()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun startEncodingInternal(fps: Int) {
        stopStreaming()
        encoder = H264Encoder(1920, 1080, fps) { nal, ptsNs ->
            streamServer?.sendH264(nal, ptsNs)
        }
        encoder?.startEncode()
    }

    private fun startStreamingInternal() {
        if (streaming) return
        streaming = true
        sendConnectionState("streaming")
        streamServer = RtspServer(
            fps = encoder?.fps ?: 30,
            port = 8554,
        )
        streamServer?.start()
    }

    private fun stopStreaming() {
        streaming = false
        runCatching { streamServer?.stop() }
        streamServer = null
        runCatching { encoder?.release() }
        encoder = null
        sendConnectionState(if (currentRouteId != null) "connected" else "disconnected")
    }

    private fun disconnect() {
        stopStreaming()
        mediaRouter?.unselect(MediaRouter.UNSELECT_REASON_UNKNOWN)
        currentRouteId = null
        sendConnectionState("disconnected")
    }

    private fun sendDeviceList() {
        val selector = mediaRouteSelector
        val router = mediaRouter
        if (selector == null || router == null) return
        val devices = mutableListOf<Map<String, Any>>()
        router.routes.forEach { route ->
            if (route.matchesSelector(selector)) {
                devices.add(
                    mapOf(
                        "id" to route.id,
                        "name" to route.name.toString(),
                        "iconPath" to (route.iconUri?.toString() ?: ""),
                    ),
                )
            }
        }
        methodChannel?.invokeMethod("onDevicesChanged", devices, null)
    }

    private fun sendConnectionState(state: String, deviceId: String? = null) {
        val args = mutableMapOf<String, Any>("state" to state)
        deviceId?.let { args["deviceId"] = it }
        methodChannel?.invokeMethod("onConnectionStateChanged", args, null)
    }
}