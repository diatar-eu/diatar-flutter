package com.diatar.wirelessdisplay

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.util.Log
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class H264Encoder(
    private val width: Int,
    private val height: Int,
    val fps: Int,
    private val onNal: (ByteArray, Long) -> Unit,
) : Thread("DiatarH264Drain") {

    private val tag = "H264Encoder"
    private var codec: MediaCodec? = null
    private var running = false

    init {
        isDaemon = true
    }

    fun startEncode() {
        if (running) return
        running = true
        val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
        format.setInteger(MediaFormat.KEY_BIT_RATE, 10_000_000)
        format.setInteger(MediaFormat.KEY_FRAME_RATE, fps)
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        format.setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420SemiPlanar,
        )
        codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        codec.start()
        this.codec = codec
        start()
    }

    fun feedPng(pngBytes: ByteArray) {
        val codec = codec ?: return
        if (!running) return
        val yuv = decodePngToNv12(pngBytes, width, height) ?: return
        try {
            val index = codec.dequeueInputBuffer(20_000)
            if (index < 0) return
            val buffer = codec.getInputBuffer(index) ?: return
            buffer.clear()
            buffer.put(yuv)
            codec.queueInputBuffer(index, 0, yuv.size, System.nanoTime() / 1000, 0)
        } catch (e: Exception) {
            Log.e(tag, "feed failed", e)
        }
    }

    override fun run() {
        val codec = codec ?: return
        val info = MediaCodec.BufferInfo()
        var psSent = false
        var durationUs = 0L
        while (running) {
            try {
                val index = codec.dequeueOutputBuffer(info, 30_000)
                when {
                    index == MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                    index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val csd0 = codec.outputFormat.getByteBuffer("csd-0")
                        if (csd0 != null) {
                            val spsPps = ByteArray(csd0.remaining())
                            csd0.get(spsPps)
                            onNal(avccToAnnexB(spsPps), 0)
                            psSent = true
                        }
                    }
                    index >= 0 -> {
                        val buffer = codec.getOutputBuffer(index) ?: continue
                        val size = info.size
                        val data = ByteArray(size)
                        buffer.get(data)
                        codec.releaseOutputBuffer(index, false)
                        if (size > 0) {
                            val annexB = avccToAnnexB(data)
                            onNal(annexB, durationUs)
                            durationUs += 33_333
                        }
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            break
                        }
                    }
                }
            } catch (e: IllegalStateException) {
                break
            }
        }
        running = false
        runCatching { codec.stop() }
        runCatching { codec.release() }
    }

    fun release() {
        running = false
        runCatching { codec?.stop() }
        runCatching { codec?.release() }
        codec = null
    }

    companion object {
        fun avccToAnnexB(avcc: ByteArray): ByteArray {
            val out = ByteArrayOutputStream(avcc.size + 32)
            var i = 0
            while (i + 4 <= avcc.size) {
                val len = ((avcc[i].toInt() and 0xFF) shl 24) or
                    ((avcc[i + 1].toInt() and 0xFF) shl 16) or
                    ((avcc[i + 2].toInt() and 0xFF) shl 8) or
                    (avcc[i + 3].toInt() and 0xFF)
                if (len < 0 || i + 4 + len > avcc.size) break
                out.write(0)
                out.write(0)
                out.write(0)
                out.write(1)
                out.write(avcc, i + 4, len)
                i += 4 + len
            }
            if (out.size() == 0) {
                return avcc
            }
            return out.toByteArray()
        }

        fun decodePngToNv12(pngBytes: ByteArray, width: Int, height: Int): ByteArray? {
            val bitmap = try {
                BitmapFactory.decodeByteArray(pngBytes, 0, pngBytes.size)
            } catch (e: Exception) {
                null
            } ?: return null
            val scaled = Bitmap.createScaledBitmap(bitmap, width, height, true)
            if (scaled != bitmap) {
                bitmap.recycle()
            }
            val size = width * height * 3 / 2
            val out = ByteArray(size)
            val pixels = IntArray(width * height)
            scaled.getPixels(pixels, 0, width, 0, 0, width, height)
            scaled.recycle()

            var yIndex = 0
            val ySize = width * height
            var uvIndex = ySize
            for (j in 0 until height) {
                for (i in 0 until width) {
                    val pixel = pixels[j * width + i]
                    val r = (pixel shr 16) and 0xFF
                    val g = (pixel shr 8) and 0xFF
                    val b = pixel and 0xFF
                    val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                    out[yIndex++] = y.toByte()
                }
            }
            for (j in 0 until height step 2) {
                for (i in 0 until width step 2) {
                    val pixel = pixels[j * width + i]
                    val r = (pixel shr 16) and 0xFF
                    val g = (pixel shr 8) and 0xFF
                    val b = pixel and 0xFF
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    out[uvIndex++] = u.toByte()
                    out[uvIndex++] = v.toByte()
                }
            }
            return out
        }
    }
}