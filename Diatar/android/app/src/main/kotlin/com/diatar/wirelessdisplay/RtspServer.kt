package com.diatar.wirelessdisplay

import android.util.Base64
import android.util.Log
import java.io.OutputStream
import java.net.InetAddress
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import java.net.SocketTimeoutException
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicBoolean

class RtspServer(
    private val fps: Int,
    private val port: Int,
) {

    private val tag = "RtspServer"
    private val running = AtomicBoolean(false)
    private var serverSocket: ServerSocket? = null
    private val clients = CopyOnWriteArrayList<Client>()
    private val ssrc = (0x10000000..0x7FFFFFFF).random()
    private val sessionId = "12345678"
    @Volatile
    private var spsPps: ByteArray? = null

    private class Client(val socket: Socket) {
        val output: OutputStream = socket.getOutputStream()
        @Volatile
        var playing = false
        @Volatile
        var sequence = 0
        @Volatile
        var timestamp = 0L
    }

    val isRunning: Boolean
        get() = running.get()

    val localIp: String?
        get() = localIpAddress()

    fun start() {
        if (!running.compareAndSet(false, true)) return
        val serverThread = Thread {
            try {
                val server = ServerSocket(port)
                server.reuseAddress = true
                server.soTimeout = 1000
                serverSocket = server
                Log.i(tag, "RTSP listening on rtsp://${localIpAddress()}:$port/diatar")
                while (running.get()) {
                    val socket = try {
                        server.accept()
                    } catch (e: SocketTimeoutException) {
                        continue
                    }
                    val client = Client(socket)
                    clients.add(client)
                    val clientThread = Thread { handleClient(client) }
                    clientThread.name = "DiatarRtspClient"
                    clientThread.isDaemon = true
                    clientThread.start()
                }
                runCatching { server.close() }
            } catch (e: Exception) {
                Log.e(tag, "RTSP server failed", e)
            }
        }
        serverThread.name = "DiatarRtspServer"
        serverThread.isDaemon = true
        serverThread.start()
    }

    fun stop() {
        running.set(false)
        runCatching { serverSocket?.close() }
        serverSocket = null
        clients.forEach { runCatching { it.socket.close() } }
        clients.clear()
    }

    fun sendH264(annexB: ByteArray, ptsNs: Long) {
        for (client in clients) {
            if (!client.playing) continue
            try {
                val ts = ((ptsNs / 1000) * 90).coerceAtLeast(client.timestamp + 1)
                sendFrame(client, annexB, ts)
            } catch (e: Exception) {
                runCatching { client.socket.close() }
                clients.remove(client)
            }
        }
    }

    private fun sendFrame(client: Client, annexB: ByteArray, ts: Long) {
        val nals = parseNals(annexB)
        for (nal in nals) {
            if (nal.size < 2) continue
            val nalType = nal[0].toInt() and 0x1F
            when (nalType) {
                7, 8 -> {
                    spsPps = annexB
                    sendSingleNal(client, nal, ts, 0)
                }
                else -> packetizeNal(client, nal, ts)
            }
        }
        client.timestamp = ts
    }

    private fun sendSingleNal(client: Client, nal: ByteArray, ts: Long, marker: Int) {
        val size = 12 + nal.size
        val rtp = rtpHeader(size, marker)
        System.arraycopy(nal, 0, rtp, 12, nal.size)
        writeInterleaved(client, 0, rtp, ts)
    }

    private fun packetizeNal(client: Client, nal: ByteArray, ts: Long) {
        val header = nal[0].toInt() and 0xFF
        val nalType = header and 0x1F
        val maxPayload = 1200
        if (nal.size <= maxPayload) {
            sendSingleNal(client, nal, ts, 1)
            return
        }
        val fuHeaderType = 0x1C
        val fuIndicator = ((header and 0x60) or (fuHeaderType and 0x1F)).toByte()
        val n = ((nal.size - 1) + maxPayload - 1) / maxPayload
        for (i in 0 until n) {
            val offset = 1 + i * maxPayload
            val length = minOf(maxPayload, nal.size - 1 - i * maxPayload)
            val marker = if (i == n - 1) 1 else 0
            val fuBytes = ByteArray(length + 2)
            fuBytes[0] = fuIndicator
            val fuHeader = ((if (i == 0) 1 else 0) shl 7) or
                ((if (i == n - 1) 1 else 0) shl 6) or
                (nalType and 0x1F)
            fuBytes[1] = fuHeader.toByte()
            System.arraycopy(nal, offset, fuBytes, 2, length)
            val size = 12 + fuBytes.size
            val rtp = rtpHeader(size, marker)
            System.arraycopy(fuBytes, 0, rtp, 12, fuBytes.size)
            writeInterleaved(client, 0, rtp, ts)
        }
    }

    private fun rtpHeader(totalSize: Int, marker: Int): ByteArray {
        val rtp = ByteArray(totalSize)
        rtp[0] = 0x80.toByte()
        val pt = 96
        rtp[1] = (((marker and 1) shl 7) or (pt and 0x7F)).toByte()
        return rtp
    }

    private fun writeInterleaved(client: Client, channel: Int, rtp: ByteArray, ts: Long) {
        val seq = ((client.sequence and 0xFFFF) + 1) and 0xFFFF
        client.sequence = seq
        rtp[2] = ((seq shr 8) and 0xFF).toByte()
        rtp[3] = (seq and 0xFF).toByte()
        rtp[4] = ((ts shr 24) and 0xFF).toByte()
        rtp[5] = ((ts shr 16) and 0xFF).toByte()
        rtp[6] = ((ts shr 8) and 0xFF).toByte()
        rtp[7] = (ts and 0xFF).toByte()
        rtp[8] = ((ssrc shr 24) and 0xFF).toByte()
        rtp[9] = ((ssrc shr 16) and 0xFF).toByte()
        rtp[10] = ((ssrc shr 8) and 0xFF).toByte()
        rtp[11] = (ssrc and 0xFF).toByte()

        val header = ByteArray(4)
        header[0] = 0x24.toByte()
        header[1] = channel.toByte()
        header[2] = ((rtp.size shr 8) and 0xFF).toByte()
        header[3] = (rtp.size and 0xFF).toByte()
        client.output.write(header)
        client.output.write(rtp)
        client.output.flush()
    }

    private fun handleClient(client: Client) {
        try {
            client.socket.soTimeout = 30_000
            val reader = client.socket.getInputStream().bufferedReader()
            val writer = client.output
            loop@ while (running.get()) {
                val line = reader.readLine() ?: break
                if (line.isEmpty()) continue
                if (line.contains("RTSP/1.0")) {
                    val method = line.substringBefore(' ').trim().uppercase()
                    val cseq = readCSeq(reader)
                    when (method) {
                        "OPTIONS" -> {
                            respond(writer, cseq, "200 OK",
                                "Public: OPTIONS, DESCRIBE, SETUP, PLAY, TEARDOWN\r\n")
                        }
                        "DESCRIBE" -> {
                            val body = describeBody()
                            respond(writer, cseq, "200 OK",
                                "Content-Type: application/sdp\r\nContent-Length: ${body.toByteArray().size}\r\n",
                                body)
                        }
                        "SETUP" -> {
                            respond(writer, cseq, "200 OK",
                                "Transport: RTP/AVP/TCP;unicast;interleaved=0-1;ssrc=${ssrc.toString(16)}\r\nSession: $sessionId\r\n")
                        }
                        "PLAY" -> {
                            client.playing = true
                            respond(writer, cseq, "200 OK",
                                "Range: npt=0.000-\r\nSession: $sessionId\r\n")
                        }
                        "TEARDOWN" -> {
                            respond(writer, cseq, "200 OK", "")
                            break@loop
                        }
                        else -> respond(writer, cseq, "501 Not Implemented", "")
                    }
                }
            }
        } catch (_: Exception) {
        } finally {
            runCatching { client.socket.close() }
            clients.remove(client)
        }
    }

    private fun readCSeq(reader: java.io.BufferedReader): String {
        var result = "1"
        var line = reader.readLine()
        while (line != null && line.isNotEmpty()) {
            if (line.startsWith("CSeq", ignoreCase = true)) {
                result = line.substringAfter(':').trim()
            }
            line = reader.readLine()
        }
        return result
    }

    private fun respond(
        writer: OutputStream,
        cseq: String,
        status: String,
        headers: String,
        body: String = "",
    ) {
        val sb = StringBuilder()
        sb.append("RTSP/1.0 ").append(status).append("\r\n")
        sb.append("CSeq: ").append(cseq).append("\r\n")
        sb.append("Server: DiatarRtsp/1.0\r\n")
        sb.append(headers)
        if (sb.toString().endsWith("\r\n") && !sb.toString().endsWith("\r\n\r\n")) {
            sb.append("\r\n")
        }
        sb.append(body)
        writer.write(sb.toString().toByteArray(Charsets.UTF_8))
        writer.flush()
    }

    private fun describeBody(): String {
        val profile = "42001f"
        val spsPps = this.spsPps
        var sprop = ""
        if (spsPps != null) {
            val sps = extractSps(spsPps)
            val pps = extractPps(spsPps)
            if (sps != null && pps != null) {
                sprop = "; sprop-parameter-sets=${Base64.encodeToString(sps, Base64.NO_WRAP)},${Base64.encodeToString(pps, Base64.NO_WRAP)}"
            }
        }
        val sb = StringBuilder()
        sb.append("v=0\r\n")
        sb.append("o=- 1 1 IN IP4 0.0.0.0\r\n")
        sb.append("s=Diatar Projection\r\n")
        sb.append("c=IN IP4 0.0.0.0\r\n")
        sb.append("t=0 0\r\n")
        sb.append("a=range:npt=0-\r\n")
        sb.append("m=video 0 RTP/AVP 96\r\n")
        sb.append("a=rtpmap:96 H264/90000\r\n")
        sb.append("a=fmtp:96 packetization-mode=1; profile-level-id=$profile$sprop\r\n")
        sb.append("a=control:track1\r\n")
        return sb.toString()
    }

    private fun extractSps(annexB: ByteArray): ByteArray? {
        val nals = parseNals0(annexB)
        return nals.firstOrNull { (it[0].toInt() and 0x1F) == 7 }
    }

    private fun extractPps(annexB: ByteArray): ByteArray? {
        val nals = parseNals0(annexB)
        return nals.firstOrNull { (it[0].toInt() and 0x1F) == 8 }
    }

    private fun parseNals(data: ByteArray): List<ByteArray> {
        return parseNals0(data)
    }

    private fun parseNals0(data: ByteArray): List<ByteArray> {
        val result = mutableListOf<ByteArray>()
        var start = findStartCode(data, 0)
        while (start >= 0) {
            val startCodeSize = if (start + 3 < data.size && data[start + 3] == 0x01.toByte()) 4 else 3
            val naluStart = start + startCodeSize
            val nextStart = findStartCode(data, naluStart)
            val end = if (nextStart < 0) data.size else nextStart
            if (end > naluStart) {
                result.add(data.copyOfRange(naluStart, end))
            }
            if (nextStart < 0) break
            start = nextStart
        }
        return result
    }

    private fun findStartCode(data: ByteArray, from: Int): Int {
        var i = from
        while (i < data.size - 3) {
            if (data[i] == 0x00.toByte() && data[i + 1] == 0x00.toByte() && data[i + 2] == 0x01.toByte()) {
                return i
            }
            if (data[i] == 0x00.toByte() && data[i + 1] == 0x00.toByte() && data[i + 2] == 0x00.toByte() && data[i + 3] == 0x01.toByte()) {
                return i
            }
            i++
        }
        return -1
    }

    private fun localIpAddress(): String? {
        return try {
            NetworkInterface.getNetworkInterfaces()?.asSequence()?.toList()?.forEach { iface ->
                if (iface.isLoopback || !iface.isUp) return@forEach
                val addresses = iface.inetAddresses
                while (addresses.hasMoreElements()) {
                    val addr = addresses.nextElement() as? InetAddress ?: continue
                    if (addr.isLoopbackAddress) continue
                    val host = addr.hostAddress ?: continue
                    if (host.contains(':')) continue
                    if (host.startsWith("169.254.")) continue
                    return host
                }
            }
            null
        } catch (e: Exception) {
            "0.0.0.0"
        }
    }

    companion object {
        fun localIp(): String {
            return try {
                NetworkInterface.getNetworkInterfaces()?.asSequence()?.toList()?.forEach { iface ->
                    if (iface.isLoopback || !iface.isUp) return@forEach
                    val addresses = iface.inetAddresses
                    while (addresses.hasMoreElements()) {
                        val addr = addresses.nextElement() as? InetAddress ?: continue
                        if (addr.isLoopbackAddress) continue
                        val host = addr.hostAddress ?: continue
                        if (host.contains(':')) continue
                        if (host.startsWith("169.254.")) continue
                        return host
                    }
                }
                "127.0.0.1"
            } catch (e: Exception) {
                "127.0.0.1"
            }
        }
    }
}