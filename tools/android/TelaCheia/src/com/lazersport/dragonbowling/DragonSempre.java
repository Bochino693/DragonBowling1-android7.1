package com.lazersport.dragonbowling;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.util.Log;

/**
 * O GUARDA DA MÁQUINA: O JOGO SEMPRE NA TELA, DE QUALQUER JEITO QUE A TV LIGUE.
 *
 * Desligada e ligada pelo CONTROLE, a TV não reinicia: fica em espera e
 * volta - não há aviso de "ligou" (DragonLigou), e o Google TV volta para a
 * tela dele. Um app comum no fundo fica congelado pelo Android 14 e não
 * percebe nada. Este serviço fica em PRIMEIRO PLANO (o Android não o
 * congela), como o de um app de quiosque:
 *  - a tela acendeu (volta da espera): abre o jogo na hora e de novo aos
 *    REABRIR_MS;
 *  - a cada OLHAR_MS, com a tela acesa: o jogo fora da frente por FORA_MS
 *    (a tela da TV, uma entrada HDMI, outro app por cima) volta para a
 *    frente.
 * Não traz o jogo de volta enquanto o operador estiver usando a TV (HOME 5
 * vezes: InicioDaTv.pausarGuarda) nem enquanto o jogo pede uma permissão
 * na instalação. No Android 10+ o Android só deixa abrir o jogo daqui com
 * "Sobrepor a outros apps" permitido (o jogo pede na instalação).
 * Começa no "ligou" (DragonLigou) e sempre que o jogo abre (TelaCheia).
 */
public class DragonSempre extends Service {

	private static final String TAG = "DragonBowling";
	private static final String CANAL = "dragon_sempre";
	private static final int AVISO = 7701;
	/** ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE (Android 14). */
	private static final int TIPO_USO_ESPECIAL = 0x40000000;
	private static final long OLHAR_MS = 10000;
	private static final long FORA_MS = 20000;
	private static final long[] REABRIR_MS = {0, 3000, 8000};

	private final Handler relogio = new Handler(Looper.getMainLooper());
	private long foraDesde = 0;
	private BroadcastReceiver tela;

	/** Liga o guarda (no "ligou" e quando o jogo abre). */
	static void comecar(Context c) {
		try {
			Intent i = new Intent(c, DragonSempre.class);
			if (Build.VERSION.SDK_INT >= 26) {
				c.startForegroundService(i);
			} else {
				c.startService(i);
			}
		} catch (Throwable t) {
			Log.i(TAG, "guarda: não começou: " + t);
		}
	}

	@Override
	public int onStartCommand(Intent intent, int flags, int startId) {
		emPrimeiroPlano();
		if (tela == null) {
			tela = new BroadcastReceiver() {
				@Override
				public void onReceive(Context c, Intent i) {
					Log.i(TAG, "guarda: a tela acendeu (" + i.getAction() + "): abrindo o jogo");
					reabrir();
				}
			};
			IntentFilter f = new IntentFilter(Intent.ACTION_SCREEN_ON);
			f.addAction(Intent.ACTION_USER_PRESENT);
			try {
				registerReceiver(tela, f);
			} catch (Throwable t) {
				tela = null;
				Log.i(TAG, "guarda: tela: " + t);
			}
		}
		relogio.removeCallbacks(olhar);
		relogio.postDelayed(olhar, OLHAR_MS);
		return START_STICKY;
	}

	@SuppressWarnings("deprecation")
	private void emPrimeiroPlano() {
		try {
			Notification.Builder b;
			if (Build.VERSION.SDK_INT >= 26) {
				NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
				if (nm != null && nm.getNotificationChannel(CANAL) == null) {
					nm.createNotificationChannel(new NotificationChannel(CANAL, "Dragon Bowling na tela", NotificationManager.IMPORTANCE_MIN));
				}
				b = new Notification.Builder(this, CANAL);
			} else {
				b = new Notification.Builder(this).setPriority(Notification.PRIORITY_MIN);
			}
			Notification n = b.setSmallIcon(getApplicationInfo().icon)
					.setContentTitle("Dragon Bowling")
					.setContentText("Mantendo o jogo na tela")
					.setOngoing(true)
					.build();
			if (Build.VERSION.SDK_INT >= 34) {
				startForeground(AVISO, n, TIPO_USO_ESPECIAL);
			} else {
				startForeground(AVISO, n);
			}
		} catch (Throwable t) {
			Log.i(TAG, "guarda: primeiro plano: " + t);
		}
	}

	/** A tela acendeu: o jogo na hora e de novo (a tela da TV aparece por cima). */
	private void reabrir() {
		for (long espera : REABRIR_MS) {
			relogio.postDelayed(new Runnable() {
				@Override
				public void run() {
					if (!InicioDaTv.guardaPausada(DragonSempre.this) && !Vigia.estaNaFrente()) {
						try {
							InicioDaTv.abrirJogo(DragonSempre.this);
						} catch (Throwable t) {
							Log.i(TAG, "guarda: abrir: " + t);
						}
					}
				}
			}, espera);
		}
	}

	private final Runnable olhar = new Runnable() {
		@Override
		public void run() {
			try {
				long agora = SystemClock.elapsedRealtime();
				if (!telaAcesa() || Vigia.estaNaFrente() || InicioDaTv.guardaPausada(DragonSempre.this)) {
					foraDesde = 0;
				} else if (foraDesde == 0) {
					foraDesde = agora;
				} else if (agora - foraDesde >= FORA_MS) {
					foraDesde = 0;
					Log.i(TAG, "guarda: o jogo saiu da tela: trazendo de volta");
					InicioDaTv.abrirJogo(DragonSempre.this);
				}
			} catch (Throwable t) {
				Log.i(TAG, "guarda: " + t);
			}
			relogio.postDelayed(this, OLHAR_MS);
		}
	};

	@SuppressWarnings("deprecation")
	private boolean telaAcesa() {
		PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
		if (pm == null) {
			return false;
		}
		return Build.VERSION.SDK_INT >= 20 ? pm.isInteractive() : pm.isScreenOn();
	}

	@Override
	public void onDestroy() {
		relogio.removeCallbacks(olhar);
		if (tela != null) {
			try {
				unregisterReceiver(tela);
			} catch (Throwable ignored) {
			}
			tela = null;
		}
		super.onDestroy();
	}

	@Override
	public IBinder onBind(Intent intent) {
		return null;
	}
}
