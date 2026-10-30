package com.lazersport.dragonbowling;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/**
 * A TV LIGOU (na tomada): abre o jogo, como o "Launch on Boot" fazia - sem
 * precisar de outro app (a StrikeLigou do Strike Kids). Com o jogo escolhido
 * como tela inicial (DragonInicioAtivo) o Android já o abre sozinho; isto é
 * a segunda garantia: no Android 10+ o sistema só deixa abrir daqui com
 * "Sobrepor a outros apps" permitido (InicioDaTv.podeAbrirDeFundo; o jogo
 * pede, e o PREPARAR_TV.bat permite pelo adb). QUICKBOOT_POWERON: o "ligou"
 * das TVs e TV Boxes com inicialização rápida.
 */
public class DragonLigou extends BroadcastReceiver {
	@Override
	public void onReceive(Context c, Intent i) {
		try {
			Log.i("DragonBowling", "inicio: a TV ligou (" + i.getAction() + "): abrindo o jogo"
					+ (InicioDaTv.podeAbrirDeFundo(c) ? "" : " (Android 10+ sem 'Sobrepor a outros apps': pode ser barrado)"));
			InicioDaTv.abrirJogo(c);
		} catch (Throwable t) {
			Log.i("DragonBowling", "inicio: ligou: " + t);
		}
	}
}
