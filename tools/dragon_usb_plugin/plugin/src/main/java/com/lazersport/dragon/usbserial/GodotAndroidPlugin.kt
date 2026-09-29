package com.lazersport.dragon.usbserial

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ActivityInfo
import android.hardware.usb.UsbManager
import android.os.SystemClock
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.util.SerialInputOutputManager
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.nio.charset.StandardCharsets
import java.util.ArrayDeque
import java.util.concurrent.Executors

/** USB serial for the Dragon Bowling Arduino. No COM number or VID/PID is hardcoded. */
class GodotAndroidPlugin(godot: Godot) : GodotPlugin(godot), SerialInputOutputManager.Listener {
    override fun getPluginName() = "DragonUsbSerial"

    private val usbManager: UsbManager by lazy {
        requireNotNull(activity).getSystemService(Context.USB_SERVICE) as UsbManager
    }
    private val lock = Any()
    private val lines = ArrayDeque<String>()
    private val partial = StringBuilder()
    private val writer = Executors.newSingleThreadExecutor()
    private val permissionAskedAt = mutableMapOf<Int, Long>()
    @Volatile private var port: UsbSerialPort? = null
    @Volatile private var io: SerialInputOutputManager? = null
    @Volatile private var error = ""

    private fun drivers(): List<UsbSerialDriver> =
        UsbSerialProber.getDefaultProber().findAllDrivers(usbManager)

    private fun key(driver: UsbSerialDriver): String {
        val d = driver.device
        return "usb:%04X:%04X:%d".format(d.vendorId, d.productId, d.deviceId)
    }

    @UsedByGodot
    fun listPorts(): String = try {
        drivers().joinToString("\n") { key(it) }
    } catch (t: Throwable) {
        error = "Falha ao listar USB: ${t.message}"
        ""
    }

    @UsedByGodot
    fun openPort(portKey: String, baud: Int): Boolean {
        closePort()
        return try {
            val driver = drivers().firstOrNull { key(it) == portKey }
                ?: return fail("USB desconectada")
            val device = driver.device
            if (!usbManager.hasPermission(device)) {
                val now = SystemClock.elapsedRealtime()
                val last = permissionAskedAt[device.deviceId] ?: 0L
                if (last == 0L || now - last > 8000L) {
                    permissionAskedAt[device.deviceId] = now
                    val host = activity ?: return fail("Activity indisponivel")
                    val intent = Intent("${host.packageName}.USB_PERMISSION").setPackage(host.packageName)
                    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                    usbManager.requestPermission(device,
                        PendingIntent.getBroadcast(host, device.deviceId, intent, flags))
                }
                return fail("Autorize o Arduino na janela USB do Android")
            }
            permissionAskedAt.remove(device.deviceId)
            val connection = usbManager.openDevice(device)
                ?: return fail("Android recusou abrir o Arduino")
            val candidate = driver.ports.firstOrNull()
                ?: run { connection.close(); return fail("USB sem porta serial") }
            try {
                candidate.open(connection)
                candidate.setParameters(baud, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
                try { candidate.dtr = true } catch (_: Throwable) { }
                try { candidate.rts = true } catch (_: Throwable) { }
                val manager = SerialInputOutputManager(candidate, this)
                port = candidate
                io = manager
                manager.start()
                error = ""
                true
            } catch (t: Throwable) {
                try { candidate.close() } catch (_: Throwable) { }
                try { connection.close() } catch (_: Throwable) { }
                throw t
            }
        } catch (t: Throwable) {
            closePort()
            fail("Falha USB: ${t.message ?: t.javaClass.simpleName}")
        }
    }

    private fun fail(message: String): Boolean { error = message; return false }

    @UsedByGodot
    fun closePort() {
        val oldIo = io
        val oldPort = port
        io = null
        port = null
        try { oldIo?.stop() } catch (_: Throwable) { }
        try { oldPort?.close() } catch (_: Throwable) { }
        synchronized(lock) { lines.clear(); partial.setLength(0) }
    }

    @UsedByGodot
    fun isOpen(): Boolean = port != null

    @UsedByGodot
    fun writeLine(line: String): Boolean {
        val target = port ?: return fail("USB fechada")
        if (line.length > 32) return fail("Comando serial longo")
        writer.execute {
            try {
                target.write((line.trimEnd() + "\n").toByteArray(StandardCharsets.US_ASCII), 250)
            } catch (t: Throwable) {
                error = "Falha de escrita: ${t.message}"
            }
        }
        return true
    }

    @UsedByGodot
    fun pollLines(): String = synchronized(lock) {
        buildString {
            while (lines.isNotEmpty()) {
                if (isNotEmpty()) append('\n')
                append(lines.removeFirst())
            }
        }
    }

    @UsedByGodot
    fun getLastError(): String = error

    @UsedByGodot
    fun requestPortrait() {
        val host = activity ?: return
        host.runOnUiThread {
            try {
                if (host.requestedOrientation != ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) {
                    host.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                }
            } catch (t: Throwable) {
                error = "Orientacao indisponivel nesta TV Box: ${t.message}"
            }
        }
    }

    override fun onNewData(data: ByteArray) {
        synchronized(lock) {
            for (byte in data) {
                val c = (byte.toInt() and 0xff).toChar()
                if (c == '\n') {
                    val line = partial.toString().trimEnd('\r')
                    partial.setLength(0)
                    if (line.isNotEmpty()) {
                        if (lines.size >= 64) lines.removeFirst()
                        lines.addLast(line)
                    }
                } else if (partial.length < 80) partial.append(c)
                else partial.setLength(0)
            }
        }
    }

    override fun onRunError(e: Exception) {
        error = "USB desconectada: ${e.message}"
        // O Godot fecha a porta no proximo heartbeat, fora do callback da thread USB.
    }
}
