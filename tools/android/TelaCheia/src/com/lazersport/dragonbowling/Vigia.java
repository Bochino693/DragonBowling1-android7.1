package com.lazersport.dragonbowling;

import android.content.Context;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;

import org.godotengine.godot.utils.ProcessPhoenix;

/**
 * O VIGIA: O JOGO NUNCA FICA PARADO NA TELA.
 *
 * No buffet ninguém desliga e liga a máquina se o jogo travar: a imagem
 * ficaria parada o dia inteiro. O vigia (uma linha de execução só dele)
 * confere a cada OLHAR_MS, com o jogo na frente:
 *  - o desenho do Godot: um aviso entra na fila do desenho
 *    (TelaCheia.naFilaDoDesenho) e só roda quando o Godot desenha um quadro;
 *  - a linha da tela do Android (a que, parada, mostraria "o app não está
 *    respondendo").
 * Parado um dos dois por TRAVADO_MS, o jogo reinicia do zero, como ao ligar
 * a TV (ProcessPhoenix, o mesmo da volta da espera). Na abertura e logo
 * depois de voltar para a frente (COMECO_MS), e com o jogo fora da frente
 * (TV em espera, ajustes, pedido da tela inicial), não vigia. Cada reinício
 * é contado e aparece na configuração do jogo (SELECT).
 */
final class Vigia {

	private static final String TAG = "DragonBowling";
	private static final String PREFS = "dragon_inicio";
	private static final long OLHAR_MS = 3000;
	private static final long TRAVADO_MS = 45000;
	private static final long COMECO_MS = 90000;

	private static volatile TelaCheia atual;
	private static volatile boolean naFrente;
	private static volatile long naFrenteDesde;
	private static volatile long ultimoQuadro;
	private static volatile long ultimaTela;
	private static Thread linha;
	private static final Handler TELA = new Handler(Looper.getMainLooper());

	private static final Runnable QUADRO = new Runnable() {
		@Override
		public void run() {
			ultimoQuadro = SystemClock.elapsedRealtime();
		}
	};

	private static final Runnable LINHA_DA_TELA = new Runnable() {
		@Override
		public void run() {
			ultimaTela = SystemClock.elapsedRealtime();
		}
	};

	private Vigia() {
	}

	/** O jogo voltou para a frente (onResume): vigia, depois da folga. */
	static void naFrente(TelaCheia t) {
		long agora = SystemClock.elapsedRealtime();
		naFrenteDesde = agora;
		ultimoQuadro = agora;
		ultimaTela = agora;
		atual = t;
		naFrente = true;
		comecar(t.getApplicationContext());
	}

	/** O jogo saiu da frente (onPause, antes de o Godot parar de desenhar). */
	static void foraDaFrente() {
		naFrente = false;
	}

	static void acabou(TelaCheia t) {
		if (atual == t) {
			naFrente = false;
			atual = null;
		}
	}

	/** Quantas vezes o vigia já reiniciou o jogo travado nesta TV. */
	static int reinicios(Context c) {
		return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getInt("vigia_reinicios", 0);
	}

	private static synchronized void comecar(final Context app) {
		if (linha != null) {
			return;
		}
		linha = new Thread(new Runnable() {
			@Override
			public void run() {
				vigiar(app);
			}
		}, "DragonVigia");
		linha.setDaemon(true);
		linha.start();
	}

	private static void vigiar(Context app) {
		while (true) {
			try {
				Thread.sleep(OLHAR_MS);
			} catch (InterruptedException e) {
				return;
			}
			TelaCheia t = atual;
			if (t == null || !naFrente) {
				continue;
			}
			try {
				t.naFilaDoDesenho(QUADRO);
			} catch (Throwable e) {
				// sem o Godot para perguntar: não conta como travado
				ultimoQuadro = SystemClock.elapsedRealtime();
			}
			TELA.post(LINHA_DA_TELA);
			long agora = SystemClock.elapsedRealtime();
			if (!naFrente || agora - naFrenteDesde < COMECO_MS) {
				continue;
			}
			long semQuadro = agora - ultimoQuadro;
			long semTela = agora - ultimaTela;
			if (semQuadro > TRAVADO_MS || semTela > TRAVADO_MS) {
				Log.i(TAG, "vigia: jogo parado (desenho " + semQuadro / 1000 + " s, tela " + semTela / 1000 + " s): reiniciando");
				contar(app);
				try {
					ProcessPhoenix.triggerRebirth(app);
				} catch (Throwable e) {
					android.os.Process.killProcess(android.os.Process.myPid());
				}
				return;
			}
		}
	}

	private static void contar(Context app) {
		try {
			SharedPreferences p = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
			p.edit().putInt("vigia_reinicios", p.getInt("vigia_reinicios", 0) + 1).commit();
		} catch (Throwable ignored) {
		}
	}
}
