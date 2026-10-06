package com.lazersport.dragon.usbserial;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.os.SystemClock;

import com.hoho.android.usbserial.driver.UsbSerialDriver;
import com.hoho.android.usbserial.driver.UsbSerialPort;
import com.hoho.android.usbserial.driver.UsbSerialProber;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.nio.charset.Charset;
import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * USB serial do Arduino dos LEDs do Dragon Bowling (Godot 3.6, plugin v1).
 *
 * POR QUE ESTA VERSAO EXISTE. A anterior lia a porta com o
 * SerialInputOutputManager da biblioteca, que espera os dados com
 * UsbDeviceConnection.requestWait() SEM tempo limite, numa thread propria.
 * Quando o Arduino nao respondia a tempo (reconexao a cada 4,5 a 7,5 s, para
 * sempre), o jogo fechava a conexao com essa thread ainda presa dentro do
 * requestWait. No Android 7 (e em varias placas Android 10) isso derruba o
 * processo inteiro com crash nativo:
 *     Fatal signal 11 (SIGSEGV) ... libusbhost.so (usb_request_wait)
 * - a propria biblioteca registra esse crash no CommonUsbSerialPort.read().
 * Era o "o jogo parou" que aparecia de vez em quando, depois de muito tempo
 * ligado.
 *
 * AGORA:
 *  - a leitura usa bulkTransfer com tempo limite (LEITURA_MS): a thread
 *    nunca fica presa mais que isso;
 *  - fechar a porta PRIMEIRO para a leitura e ESPERA a thread sair; so
 *    depois fecha a conexao. Se a thread demorar, e ela mesma quem fecha ao
 *    sair - nunca as duas coisas ao mesmo tempo;
 *  - escrita e fechamento passam pela mesma trava: nunca se fecha a conexao
 *    no meio de uma escrita;
 *  - nenhuma excecao escapa de uma thread (excecao solta numa thread Java
 *    tambem fecha o app com "parou").
 * As funcoes chamadas pelo jogo sao as mesmas de antes.
 */
public class GodotAndroidPlugin extends GodotPlugin {

    private static final int LEITURA_MS = 300;
    private static final int ESPERA_LEITURA_MS = 1500;
    private static final int FLAG_MUTABLE = 0x02000000;   // PendingIntent.FLAG_MUTABLE (API 31)
    private static final Charset ASCII = Charset.forName("US-ASCII");

    private final Object linhasLock = new Object();
    private final ArrayDeque<String> linhas = new ArrayDeque<String>();
    private final StringBuilder parcial = new StringBuilder();
    /** Escrita e fechamento nunca ao mesmo tempo. */
    private final Object ioLock = new Object();
    private final ExecutorService escritor = Executors.newSingleThreadExecutor();
    private final Map<Integer, Long> permissaoPedidaEm = new HashMap<Integer, Long>();

    private volatile UsbSerialPort porta;
    private volatile Leitor leitor;
    private volatile String erro = "";
    private UsbManager usbManager;

    public GodotAndroidPlugin(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "DragonUsbSerial";
    }

    // ------------------------------------------------------------ leitura

    /** Uma thread por porta aberta. Le com tempo limite e sai sozinha. */
    private final class Leitor extends Thread {
        final UsbSerialPort alvo;
        volatile boolean rodando = true;
        /** O fechamento desistiu de esperar: quem fecha a porta e o leitor. */
        volatile boolean fecharAoSair = false;

        Leitor(UsbSerialPort alvo) {
            super("DragonUsbLeitura");
            this.alvo = alvo;
            setDaemon(true);
        }

        @Override
        public void run() {
            byte[] buf = new byte[256];
            try {
                while (rodando) {
                    int n = alvo.read(buf, LEITURA_MS);
                    if (n > 0) receber(buf, n);
                }
            } catch (Throwable t) {
                if (rodando) erro = "USB desconectada: " + mensagem(t);
            } finally {
                if (fecharAoSair) fecharConexao(alvo);
            }
        }
    }

    private void receber(byte[] dados, int n) {
        synchronized (linhasLock) {
            for (int i = 0; i < n; i++) {
                char c = (char) (dados[i] & 0xff);
                if (c == '\n') {
                    String linha = parcial.toString();
                    if (linha.endsWith("\r")) linha = linha.substring(0, linha.length() - 1);
                    parcial.setLength(0);
                    if (linha.length() > 0) {
                        if (linhas.size() >= 64) linhas.removeFirst();
                        linhas.addLast(linha);
                    }
                } else if (parcial.length() < 80) {
                    parcial.append(c);
                } else {
                    parcial.setLength(0);
                }
            }
        }
    }

    // ------------------------------------------------------------ portas

    private UsbManager usb() {
        if (usbManager == null) {
            Activity a = getActivity();
            if (a != null) usbManager = (UsbManager) a.getSystemService(Context.USB_SERVICE);
        }
        return usbManager;
    }

    private static String chave(UsbSerialDriver d) {
        UsbDevice dev = d.getDevice();
        return String.format(Locale.US, "usb:%04X:%04X:%d", dev.getVendorId(), dev.getProductId(), dev.getDeviceId());
    }

    private List<UsbSerialDriver> drivers() {
        UsbManager m = usb();
        if (m == null) return java.util.Collections.emptyList();
        return UsbSerialProber.getDefaultProber().findAllDrivers(m);
    }

    @UsedByGodot
    public String listPorts() {
        try {
            StringBuilder sb = new StringBuilder();
            for (UsbSerialDriver d : drivers()) {
                if (sb.length() > 0) sb.append('\n');
                sb.append(chave(d));
            }
            return sb.toString();
        } catch (Throwable t) {
            erro = "Falha ao listar USB: " + mensagem(t);
            return "";
        }
    }

    @UsedByGodot
    public boolean openPort(String chavePorta, int baud) {
        fecharPorta();
        UsbDeviceConnection conexao = null;
        UsbSerialPort candidata = null;
        try {
            UsbSerialDriver driver = null;
            for (UsbSerialDriver d : drivers()) {
                if (chave(d).equals(chavePorta)) { driver = d; break; }
            }
            if (driver == null) return falhar("USB desconectada");
            UsbDevice dev = driver.getDevice();
            UsbManager m = usb();
            if (m == null) return falhar("Activity indisponivel");
            if (!m.hasPermission(dev)) {
                long agora = SystemClock.elapsedRealtime();
                Long ultima = permissaoPedidaEm.get(dev.getDeviceId());
                if (ultima == null || agora - ultima > 8000L) {
                    permissaoPedidaEm.put(dev.getDeviceId(), agora);
                    Activity host = getActivity();
                    if (host == null) return falhar("Activity indisponivel");
                    Intent intent = new Intent(host.getPackageName() + ".USB_PERMISSION").setPackage(host.getPackageName());
                    int flags = PendingIntent.FLAG_UPDATE_CURRENT | FLAG_MUTABLE;
                    m.requestPermission(dev, PendingIntent.getBroadcast(host, dev.getDeviceId(), intent, flags));
                }
                return falhar("Autorize o Arduino na janela USB do Android");
            }
            permissaoPedidaEm.remove(dev.getDeviceId());
            List<UsbSerialPort> portas = driver.getPorts();
            if (portas == null || portas.isEmpty()) return falhar("USB sem porta serial");
            conexao = m.openDevice(dev);
            if (conexao == null) return falhar("Android recusou abrir o Arduino");
            candidata = portas.get(0);
            candidata.open(conexao);
            candidata.setParameters(baud, UsbSerialPort.DATABITS_8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE);
            try { candidata.setDTR(true); } catch (Throwable ignorado) { }
            try { candidata.setRTS(true); } catch (Throwable ignorado) { }
            Leitor novo = new Leitor(candidata);
            porta = candidata;
            leitor = novo;
            novo.start();
            erro = "";
            return true;
        } catch (Throwable t) {
            // Nenhuma leitura comecou nesta porta: fechar aqui e seguro.
            porta = null;
            leitor = null;
            if (candidata != null) fecharConexao(candidata);
            else if (conexao != null) try { conexao.close(); } catch (Throwable ignorado) { }
            return falhar("Falha USB: " + mensagem(t));
        }
    }

    private boolean falhar(String msg) {
        erro = msg;
        return false;
    }

    @UsedByGodot
    public void closePort() {
        fecharPorta();
    }

    /** Para a leitura, espera a thread sair e so entao fecha a conexao. */
    private void fecharPorta() {
        UsbSerialPort p = porta;
        Leitor l = leitor;
        porta = null;
        leitor = null;
        if (l != null) {
            l.rodando = false;
            if (l != Thread.currentThread()) {
                try {
                    l.join(ESPERA_LEITURA_MS);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
            if (l.isAlive()) {
                // Ainda dentro de uma leitura: ela fecha a porta ao sair.
                l.fecharAoSair = true;
                if (!l.isAlive()) fecharConexao(l.alvo);
                p = null;
            }
        }
        if (p != null) fecharConexao(p);
        synchronized (linhasLock) {
            linhas.clear();
            parcial.setLength(0);
        }
    }

    private void fecharConexao(UsbSerialPort p) {
        synchronized (ioLock) {
            try {
                if (p.isOpen()) p.close();
            } catch (Throwable ignorado) { }
        }
    }

    @UsedByGodot
    public boolean isOpen() {
        return porta != null;
    }

    @UsedByGodot
    public boolean writeLine(String linha) {
        final UsbSerialPort alvo = porta;
        if (alvo == null) return falhar("USB fechada");
        if (linha == null || linha.length() > 32) return falhar("Comando serial longo");
        String limpa = linha;
        while (limpa.length() > 0 && Character.isWhitespace(limpa.charAt(limpa.length() - 1))) {
            limpa = limpa.substring(0, limpa.length() - 1);
        }
        final byte[] dados = (limpa + "\n").getBytes(ASCII);
        try {
            escritor.execute(new Runnable() {
                @Override
                public void run() {
                    synchronized (ioLock) {
                        if (porta != alvo) return;   // fechada/trocada enquanto esperava
                        try {
                            alvo.write(dados, 250);
                        } catch (Throwable t) {
                            erro = "Falha de escrita: " + mensagem(t);
                        }
                    }
                }
            });
        } catch (Throwable t) {
            return falhar("Fila de escrita indisponivel");
        }
        return true;
    }

    @UsedByGodot
    public String pollLines() {
        synchronized (linhasLock) {
            if (linhas.isEmpty()) return "";
            StringBuilder sb = new StringBuilder();
            while (!linhas.isEmpty()) {
                if (sb.length() > 0) sb.append('\n');
                sb.append(linhas.removeFirst());
            }
            return sb.toString();
        }
    }

    @UsedByGodot
    public String getLastError() {
        return erro;
    }

    @UsedByGodot
    public void requestPortrait() {
        final Activity host = getActivity();
        if (host == null) return;
        host.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    if (host.getRequestedOrientation() != ActivityInfo.SCREEN_ORIENTATION_PORTRAIT) {
                        host.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
                    }
                } catch (Throwable t) {
                    erro = "Orientacao indisponivel nesta TV Box: " + mensagem(t);
                }
            }
        });
    }

    @Override
    public void onMainDestroy() {
        try { fecharPorta(); } catch (Throwable ignorado) { }
        try { escritor.shutdown(); } catch (Throwable ignorado) { }
        super.onMainDestroy();
    }

    private static String mensagem(Throwable t) {
        String m = t.getMessage();
        return m != null ? m : t.getClass().getSimpleName();
    }
}
