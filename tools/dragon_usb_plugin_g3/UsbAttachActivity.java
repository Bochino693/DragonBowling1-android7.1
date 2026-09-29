package com.lazersport.dragon.usbserial;

import android.app.Activity;
import android.os.Bundle;

/**
 * Recebe o encaixe do Arduino dos LEDs (USB_DEVICE_ATTACHED).
 *
 * EXISTIR JA E O TRABALHO. Por causa desta atividade o Android oferece a
 * caixa "Usar por padrao" na janela de permissao USB; marcada uma vez, o
 * Android passa a DAR a permissao ao jogo sozinho a cada encaixe (e no
 * boot), sem perguntar mais.
 *
 * ELA NAO ABRE O JOGO (abrir daqui empilhava uma segunda tela do Godot por
 * cima da primeira — licao do Super Boxing): so fecha, sem desenhar nada.
 */
public class UsbAttachActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        finish();
    }
}
