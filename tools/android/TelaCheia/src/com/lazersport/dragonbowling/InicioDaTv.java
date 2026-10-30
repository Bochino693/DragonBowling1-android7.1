package com.lazersport.dragonbowling;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;

import org.godotengine.godot.utils.ProcessPhoenix;

import java.io.File;
import java.io.FileOutputStream;
import java.util.List;

/**
 * O JOGO ABRE SOZINHO AO LIGAR A TV - de qualquer jeito que ela seja ligada.
 * O método do Strike Kids (repositório beta, strike-kids-gles2:
 * tools/android/StrikeSerial/.../InicioDaTv.java), para as máquinas ficarem
 * todas iguais - mas SEM ABRIR JANELA NENHUMA: na máquina só há os botões da
 * Zero Delay e ninguém consegue fechar uma janela do Android.
 *
 * 1. TELA INICIAL: o jogo é uma tela inicial do Android (DragonInicioAtivo).
 *    Escolhido como a tela inicial da TV, é ele que o Android abre ao ligar
 *    na tomada, ao voltar para o início e a cada HOME. estado() diz se já é.
 *    Ela vem DESLIGADA no APK (senão o Android mostraria ao ligar a janela
 *    "qual tela inicial usar"): o PC (PREPARAR_TV.bat, adb) a liga e já a
 *    escolhe, sem nada aparecer na TV - o jogo nunca pergunta.
 * 2. AVISO DE "LIGOU": ligada na tomada, DragonLigou abre o jogo. No Android
 *    10+ (Android TV) só com "Sobrepor a outros apps" permitido
 *    (podeAbrirDeFundo) - o PREPARAR_TV.bat permite pelo adb.
 * 3. VOLTA DA ESPERA: desligada pelo CONTROLE, a TV não desliga de verdade
 *    (fica em espera) e nada "liga" de novo - um app de "abrir ao ligar" não
 *    percebe nada. Com o processo do jogo vivo (mesmo fechado ou atrás de
 *    outro app), ouvirTela() percebe a tela apagar e acender: depois de 10 s
 *    ou mais apagada, o jogo reinicia do zero (como ao ligar na tomada) e
 *    vem para a frente, sem a imagem travada da placa de vídeo depois da
 *    espera.
 * 4. SAÍDA DO OPERADOR: HOME 5 vezes seguidas no controle remoto
 *    (pediuParaSair) abre a tela inicial da própria TV (sairParaTv).
 * O estado vai para a tela de configuração do jogo (gravarEstado).
 */
final class InicioDaTv {

	private static final String TAG = "DragonBowling";
	private static final String PREFS = "dragon_inicio";
	private static final int VEZES_PARA_SAIR = 5;
	private static final long JANELA_SAIR_MS = 10000;
	private static final long APAGADA_PARA_REINICIAR_MS = 10000;
	private static final long ESPERA_AO_ACENDER_MS = 1500;

	private static long apagouEm = 0;
	private static BroadcastReceiver tela;

	private InicioDaTv() {
	}

	private static Intent home() {
		return new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
	}

	/** Abre uma tela de outro app; false se a TV não tem essa tela. */
	private static boolean abrir(Context c, Intent i) {
		try {
			i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			c.startActivity(i);
			return true;
		} catch (ActivityNotFoundException e) {
			return false;
		} catch (Throwable t) {
			Log.i(TAG, "inicio: " + t);
			return false;
		}
	}

	/** O jogo, como o lançador o abre (só traz para a frente se já está aberto). */
	static void abrirJogo(Context c) {
		Intent jogo = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
		if (jogo != null) {
			jogo.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
			c.startActivity(jogo);
		}
	}

	// ------------------------------------------------------------ tela inicial
	/** A tela inicial que o Android abre hoje (null, ou a janela de escolha). */
	private static ResolveInfo padrao(Context c) {
		return c.getPackageManager().resolveActivity(home(), PackageManager.MATCH_DEFAULT_ONLY);
	}

	private static boolean ehCandidata(Context c, ResolveInfo ri) {
		List<ResolveInfo> todas = c.getPackageManager().queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY);
		for (ResolveInfo r : todas) {
			if (r.activityInfo.packageName.equals(ri.activityInfo.packageName) && r.activityInfo.name.equals(ri.activityInfo.name)) {
				return true;
			}
		}
		return false;
	}

	/** "jogo" (a TV já abre o jogo), "escolher" (o Android ainda pergunta) ou "outra|Nome". */
	static String estado(Context c) {
		ResolveInfo ri = padrao(c);
		if (ri == null || ri.activityInfo == null) {
			return "escolher";
		}
		if (ri.activityInfo.packageName.equals(c.getPackageName())) {
			return "jogo";
		}
		// sem uma escolhida, o Android devolve a própria janela de escolha
		if (!ehCandidata(c, ri)) {
			return "escolher";
		}
		return "outra|" + ri.loadLabel(c.getPackageManager());
	}

	// ------------------------------------------------------------ Android 10+
	/**
	 * ANDROID 10 OU MAIS NOVO (as TVs com Android TV 10 a 14): o Android não
	 * deixa um app abrir uma tela "de fundo" - o aviso de "ligou" (DragonLigou)
	 * e a volta da espera (ouvirTela) ficam barrados. A exceção é o app com
	 * "Sobrepor a outros apps" (SYSTEM_ALERT_WINDOW) permitido: com ela o jogo
	 * abre sozinho ao ligar mesmo sem ser a tela inicial. No Android 7.1 (TV
	 * Box) não há essa barreira.
	 */
	static boolean podeAbrirDeFundo(Context c) {
		if (Build.VERSION.SDK_INT < 29) {
			return true;
		}
		try {
			return Settings.canDrawOverlays(c);
		} catch (Throwable t) {
			return false;
		}
	}

	/**
	 * Para a tela de configuração do jogo (SELECT): user://inicio_tv.cfg, uma
	 * linha "nome=valor" por item - tela_inicial (estado()), sobrepor (sim,
	 * nao ou nao_precisa) e a versão do Android. Só grava: nada aparece.
	 */
	static void gravarEstado(Context c) {
		String sobrepor = Build.VERSION.SDK_INT < 29 ? "nao_precisa" : (podeAbrirDeFundo(c) ? "sim" : "nao");
		String texto = "tela_inicial=" + estado(c).replace('\n', ' ') + "\nsobrepor=" + sobrepor
				+ "\nandroid=" + Build.VERSION.RELEASE + "\nsdk=" + Build.VERSION.SDK_INT + "\n";
		File arquivo = new File(c.getFilesDir(), "inicio_tv.cfg");
		FileOutputStream saida = null;
		try {
			saida = new FileOutputStream(arquivo);
			saida.write(texto.getBytes("UTF-8"));
		} catch (Throwable t) {
			Log.i(TAG, "inicio: estado: " + t);
		} finally {
			if (saida != null) {
				try {
					saida.close();
				} catch (Throwable ignored) {
				}
			}
		}
	}

	// ------------------------------------------------------------ saída
	/** A tela inicial da própria TV (a de maior prioridade que não é o jogo), ou null. */
	private static ResolveInfo outraTela(Context c) {
		PackageManager pm = c.getPackageManager();
		ResolveInfo melhor = null;
		for (ResolveInfo r : pm.queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY)) {
			if (r.activityInfo == null || r.activityInfo.packageName.equals(c.getPackageName())) {
				continue;
			}
			// a "FallbackHome" dos Ajustes (só a do começo do boot) tem prioridade -1000
			if (melhor == null || r.priority > melhor.priority
					|| (r.priority == melhor.priority && sistema(r) && !sistema(melhor))) {
				melhor = r;
			}
		}
		return melhor;
	}

	private static boolean sistema(ResolveInfo r) {
		return (r.activityInfo.applicationInfo.flags & ApplicationInfo.FLAG_SYSTEM) != 0;
	}

	/**
	 * Abre a tela inicial da própria TV (ou os ajustes, se o PREPARAR_TV.bat
	 * -SoOJogo desligou a da TV): o nome dela, "config" ou "". Só quando o
	 * operador aperta HOME 5 vezes no controle remoto.
	 */
	static String sairParaTv(Context c) {
		ResolveInfo outra = outraTela(c);
		if (outra != null) {
			Intent i = home().setClassName(outra.activityInfo.packageName, outra.activityInfo.name)
					.addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED);
			if (abrir(c, i)) {
				return outra.loadLabel(c.getPackageManager()).toString();
			}
		}
		return abrir(c, new Intent(Settings.ACTION_SETTINGS)) ? "config" : "";
	}

	/** HOME 5 vezes em 10 s: true = sair para a tela da TV. */
	static boolean pediuParaSair(Context c) {
		SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
		long agora = SystemClock.elapsedRealtime();
		long desde = p.getLong("desde", 0);
		int vezes = p.getInt("vezes", 0);
		if (agora < desde || agora - desde > JANELA_SAIR_MS) {
			desde = agora;
			vezes = 0;
		}
		vezes++;
		boolean sair = vezes >= VEZES_PARA_SAIR;
		p.edit().putLong("desde", sair ? 0 : desde).putInt("vezes", sair ? 0 : vezes).commit();
		return sair;
	}

	// ------------------------------------------------------------ volta da espera
	/**
	 * Tela apagada 10 s ou mais e acesa de novo = o jogo reinicia do zero.
	 * Fica ouvindo enquanto o processo do jogo viver (mesmo com o jogo
	 * fechado ou atrás de outro app).
	 */
	static void ouvirTela(Activity atividade) {
		if (tela != null) {
			return;
		}
		final Context app = atividade.getApplicationContext();
		tela = new BroadcastReceiver() {
			@Override
			public void onReceive(Context c, Intent i) {
				if (Intent.ACTION_SCREEN_OFF.equals(i.getAction())) {
					apagouEm = SystemClock.elapsedRealtime();
					return;
				}
				long apagada = apagouEm > 0 ? SystemClock.elapsedRealtime() - apagouEm : 0;
				apagouEm = 0;
				if (apagada < APAGADA_PARA_REINICIAR_MS) {
					return;
				}
				Log.i(TAG, "inicio: a TV voltou da espera (" + apagada / 1000 + " s): o jogo reinicia");
				new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
					@Override
					public void run() {
						try {
							ProcessPhoenix.triggerRebirth(app);
						} catch (Throwable t) {
							Log.i(TAG, "inicio: reiniciar: " + t);
						}
					}
				}, ESPERA_AO_ACENDER_MS);
			}
		};
		IntentFilter f = new IntentFilter(Intent.ACTION_SCREEN_OFF);
		f.addAction(Intent.ACTION_SCREEN_ON);
		try {
			app.registerReceiver(tela, f);
		} catch (Throwable t) {
			tela = null;
			Log.i(TAG, "inicio: tela: " + t);
		}
	}
}
