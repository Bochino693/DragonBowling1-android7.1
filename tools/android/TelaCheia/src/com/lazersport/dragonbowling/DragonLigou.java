package com.lazersport.dragonbowling;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

/**
 * A TV LIGOU (na tomada): abre o jogo, como um app de "auto start" (Launch
 * on Boot) faz - sem precisar de outro app (a StrikeLigou do Strike Kids).
 * Como o auto start: acende a tela (se o Android ligou com ela apagada),
 * abre o jogo na hora e de novo aos REABRIR_MS (a tela inicial da TV ou a
 * entrada de TV às vezes aparecem por cima logo depois de ligar; com o jogo
 * já na frente, abrir de novo não faz nada).
 * No Android 10+ o sistema só deixa abrir daqui com "Sobrepor a outros apps"
 * permitido - o mesmo que o auto start pede: o jogo pede na 1a vez
 * (InicioDaTv.pedirSobrepor), ou o PREPARAR_TV.bat / o adb da própria TV
 * permitem. Com o jogo escolhido como tela inicial (DragonInicioAtivo), o
 * Android já o abre sozinho e isto é a segunda garantia.
 * QUICKBOOT_POWERON: o "ligou" das TVs e TV Boxes com inicialização rápida.
 */
public class DragonLigou extends BroadcastReceiver {

	private static final long[] REABRIR_MS = {5000, 15000};

	@Override
	public void onReceive(Context c, Intent i) {
		final Context app = c.getApplicationContext();
		try {
			Log.i("DragonBowling", "inicio: a TV ligou (" + i.getAction() + "): abrindo o jogo"
					+ (InicioDaTv.podeAbrirDeFundo(app) ? "" : " (Android 10+ sem 'Sobrepor a outros apps': pode ser barrado)"));
			InicioDaTv.acenderTela(app);
			InicioDaTv.abrirJogo(app);
		} catch (Throwable t) {
			Log.i("DragonBowling", "inicio: ligou: " + t);
		}
		// o aviso de "ligou" pode esperar (até 60 s): reabre como o auto start
		final PendingResult fim = goAsync();
		Handler h = new Handler(Looper.getMainLooper());
		for (int n = 0; n < REABRIR_MS.length; n++) {
			final boolean ultimo = n == REABRIR_MS.length - 1;
			h.postDelayed(new Runnable() {
				@Override
				public void run() {
					try {
						InicioDaTv.abrirJogo(app);
					} catch (Throwable t) {
						Log.i("DragonBowling", "inicio: reabrir: " + t);
					}
					if (ultimo) {
						fim.finish();
					}
				}
			}, REABRIR_MS[n]);
		}
	}
}
