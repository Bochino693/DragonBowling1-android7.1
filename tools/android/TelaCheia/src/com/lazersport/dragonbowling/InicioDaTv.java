package com.lazersport.dragonbowling;

import android.app.Activity;
import android.app.role.RoleManager;
import android.content.ActivityNotFoundException;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.os.SystemClock;
import android.provider.Settings;
import android.util.Log;
import android.widget.Toast;

import org.godotengine.godot.utils.ProcessPhoenix;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.spec.PKCS8EncodedKeySpec;
import java.security.spec.X509EncodedKeySpec;
import java.util.ArrayList;
import java.util.List;

/**
 * O JOGO ABRE SOZINHO AO LIGAR A TV - de qualquer jeito que ela seja ligada.
 * CÓPIA do InicioDaTv do Strike Kids (repositório beta, strike-kids-gles2:
 * tools/android/StrikeSerial/.../InicioDaTv.java), o método que já funciona
 * na placa da TV: só os nomes mudam. A mais, só o que grava o estado para a
 * tela de configuração do jogo (gravarEstado) - nada que apareça na tela.
 *
 * 1. TELA INICIAL: o jogo é uma tela inicial do Android (DragonInicioAtivo).
 *    Escolhido como a tela inicial da TV, é ele que o Android abre ao ligar
 *    na tomada, ao voltar para o início e a cada HOME. estado() diz se já é;
 *    escolher() abre a escolha do Android (o papel HOME do Android 10+, os
 *    ajustes da tela inicial ou a janela "Sempre / Só uma vez") - o jogo
 *    pede sozinho enquanto não for (TelaCheia, sozinho = true). Escolhido
 *    uma vez, nunca mais pergunta.
 * 2. VOLTA DA ESPERA: desligada pelo CONTROLE, a TV não desliga de verdade
 *    (fica em espera) e nada "liga" de novo - um app de "abrir ao ligar" não
 *    percebe nada. Com o processo do jogo vivo (mesmo fechado ou atrás de
 *    outro app), ouvirTela() percebe a tela apagar e acender: depois de 10 s
 *    ou mais apagada, o jogo reinicia do zero (como ao ligar na tomada) e
 *    vem para a frente, sem a imagem travada da placa de vídeo depois da
 *    espera. Ligada na tomada, DragonLigou também abre o jogo.
 * 3. SAÍDA DO OPERADOR: sairParaTv() abre a tela inicial da própria TV (HOME
 *    5 vezes seguidas - pediuParaSair()).
 * 4. O JOGO SE PREPARA SOZINHO (a mais que o Strike Kids, para o Google TV,
 *    que não deixa trocar a tela inicial): com a Depuração USB ligada, o
 *    jogo entra no adb da própria TV (AdbDaTv) e faz o mesmo do
 *    PREPARAR_TV.bat - prepararPeloAdb(). Desligada, nada aparece.
 */
final class InicioDaTv {

	private static final String TAG = "DragonBowling";
	static final int PEDIDO_PAPEL = 7501;
	private static final String PREFS = "dragon_inicio";
	private static final int VEZES_PARA_SAIR = 5;
	private static final long JANELA_SAIR_MS = 10000;
	private static final long APAGADA_PARA_REINICIAR_MS = 10000;
	private static final long ESPERA_AO_ACENDER_MS = 1500;

	private static long pedidoEm = 0;
	private static boolean pedidoSozinho = false;
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

	/**
	 * A tela inicial do jogo está ligada? O PREPARAR_TV.bat -DevolverTv a
	 * desliga (a TV volta a ser TV): aí o jogo não pede mais nada.
	 */
	static boolean telaDoJogoLigada(Context c) {
		try {
			int e = c.getPackageManager().getComponentEnabledSetting(new ComponentName(c, DragonInicioAtivo.class));
			return e != PackageManager.COMPONENT_ENABLED_STATE_DISABLED
					&& e != PackageManager.COMPONENT_ENABLED_STATE_DISABLED_USER;
		} catch (Throwable t) {
			return true;
		}
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

	/**
	 * Abre a escolha da tela inicial: "ja" (já é o jogo), "papel" (a janela do
	 * Android 10+), "ajustes", "escolha" (a janela "Sempre / Só uma vez"),
	 * "app" (a página da tela inicial da TV: "Limpar padrões"), "config" ou ""
	 * (nada abriu). sozinho (o jogo pedindo na tela de espera): só as janelas
	 * de escolha, nunca a página do app nem os ajustes gerais.
	 */
	static String escolher(Activity a, boolean sozinho) {
		String agora = estado(a);
		if (agora.equals("jogo")) {
			return "ja";
		}
		pedidoSozinho = sozinho;
		if (Build.VERSION.SDK_INT >= 29 && pedirPapel(a)) {
			return "papel";
		}
		return semPapel(a, agora, sozinho);
	}

	private static boolean pedirPapel(Activity a) {
		try {
			RoleManager rm = a.getSystemService(RoleManager.class);
			if (rm == null || !rm.isRoleAvailable(RoleManager.ROLE_HOME) || rm.isRoleHeld(RoleManager.ROLE_HOME)) {
				return false;
			}
			pedidoEm = SystemClock.elapsedRealtime();
			a.startActivityForResult(rm.createRequestRoleIntent(RoleManager.ROLE_HOME), PEDIDO_PAPEL);
			return true;
		} catch (Throwable t) {
			Log.i(TAG, "inicio: papel: " + t);
			return false;
		}
	}

	/** A janela do papel voltou: se ela nem apareceu (TV sem essa janela), segue pelos ajustes. */
	static void depoisDoPapel(Activity a, int resultado) {
		if (resultado == Activity.RESULT_OK || SystemClock.elapsedRealtime() - pedidoEm > 1500) {
			return;
		}
		String agora = estado(a);
		if (!agora.equals("jogo")) {
			semPapel(a, agora, pedidoSozinho);
		}
	}

	private static String semPapel(Activity a, String agora, boolean sozinho) {
		if (abrir(a, new Intent(Settings.ACTION_HOME_SETTINGS))) {
			return "ajustes";
		}
		if (agora.equals("escolher") && abrir(a, home())) {
			return "escolha";
		}
		if (sozinho) {
			return "";
		}
		ResolveInfo ri = padrao(a);
		if (ri != null && ri.activityInfo != null && !ri.activityInfo.packageName.equals(a.getPackageName())
				&& abrir(a, new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + ri.activityInfo.packageName)))) {
			return "app";
		}
		if (abrir(a, new Intent(Settings.ACTION_SETTINGS))) {
			return "config";
		}
		return "";
	}

	// ------------------------------------------------------------ pelo adb da própria TV
	private static final int PORTA_ADB = 5555;
	private static final String DESLIGADAS = "/data/local/tmp/dragonbowling_telas_desligadas.txt";
	private static final String[] TELAS_DO_GOOGLE = {"com.google.android.apps.tv.launcherx",
			"com.google.android.tungsten.setupwraith", "com.google.android.tvlauncher"};

	/**
	 * O JOGO SE PREPARA SOZINHO: com a Depuração USB ligada (Opções do
	 * desenvolvedor), entra no adb da própria TV (AdbDaTv) e faz o mesmo do
	 * PREPARAR_TV.bat - a tela inicial do jogo ligada e escolhida, as telas da
	 * TV desligadas (só depois de conferir a do jogo), "Sobrepor" permitido e
	 * TV sempre ligada. A TV pergunta "Permitir depuração?" uma vez (no
	 * máximo uma vez a cada vez que a TV liga); com "Sempre permitir", nunca
	 * mais. Devolve: "pronta", "incompleta", "adb_desligado" (nada aparece),
	 * "sem_permissao", "devolvida" (o -DevolverTv desligou a tela do jogo)
	 * ou "erro: ...". Demorado: nunca na linha da tela.
	 */
	static String prepararPeloAdb(Context c) {
		String r = prepararPeloAdbSemGuardar(c);
		c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("adb", r.startsWith("erro") ? "erro" : r).commit();
		return r;
	}

	private static String prepararPeloAdbSemGuardar(Context c) {
		if (!telaDoJogoLigada(c)) {
			return "devolvida";
		}
		AdbDaTv adb;
		try {
			adb = AdbDaTv.conectar("127.0.0.1", PORTA_ADB, 1500);
		} catch (IOException e) {
			return "adb_desligado";
		}
		try {
			SharedPreferences p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
			long ligou = ligouEm(c);
			boolean podePerguntar = p.getLong("adb_perguntou", Long.MIN_VALUE) != ligou;
			if (podePerguntar) {
				p.edit().putLong("adb_perguntou", ligou).commit();
			}
			if (!adb.entrar(chaveDoJogo(c), "DragonBowling@tv", podePerguntar, 5000, 120000)) {
				return "sem_permissao";
			}
			String saida = adb.shell(comandoPreparar(c), 60000);
			Log.i(TAG, "inicio: pelo adb: " + saida.trim().replace('\n', ' '));
			return saida.contains("TV_PRONTA") ? "pronta" : "incompleta";
		} catch (Throwable t) {
			Log.i(TAG, "inicio: pelo adb: " + t);
			return "erro: " + t;
		} finally {
			adb.close();
		}
	}

	/** Um número que muda a cada vez que a TV liga (para perguntar no máximo uma vez). */
	private static long ligouEm(Context c) {
		try {
			int vezes = Settings.Global.getInt(c.getContentResolver(), "boot_count", -1);
			if (vezes >= 0) {
				return vezes;
			}
		} catch (Throwable ignored) {
		}
		return (System.currentTimeMillis() - SystemClock.elapsedRealtime()) / 600000L;
	}

	/** A chave do jogo para o adb da TV: criada uma vez e guardada no jogo. */
	private static KeyPair chaveDoJogo(Context c) throws Exception {
		File priv = new File(c.getFilesDir(), "adb_chave.pk8");
		File pub = new File(c.getFilesDir(), "adb_chave.pub");
		KeyFactory kf = KeyFactory.getInstance("RSA");
		if (priv.exists() && pub.exists()) {
			try {
				return new KeyPair(kf.generatePublic(new X509EncodedKeySpec(lerTudo(pub))),
						kf.generatePrivate(new PKCS8EncodedKeySpec(lerTudo(priv))));
			} catch (Throwable estragada) {
				Log.i(TAG, "inicio: chave do adb estragada: nova");
			}
		}
		KeyPairGenerator g = KeyPairGenerator.getInstance("RSA");
		g.initialize(2048);
		KeyPair k = g.generateKeyPair();
		gravarTudo(priv, k.getPrivate().getEncoded());
		gravarTudo(pub, k.getPublic().getEncoded());
		return k;
	}

	private static byte[] lerTudo(File f) throws IOException {
		RandomAccessFile r = new RandomAccessFile(f, "r");
		try {
			byte[] b = new byte[(int) r.length()];
			r.readFully(b);
			return b;
		} finally {
			r.close();
		}
	}

	private static void gravarTudo(File f, byte[] b) throws IOException {
		FileOutputStream o = new FileOutputStream(f);
		try {
			o.write(b);
		} finally {
			o.close();
		}
	}

	/**
	 * As telas iniciais da TV que saem: as que o Android mostra (menos o jogo,
	 * os Ajustes e as de fundo, com prioridade negativa) e as do Google TV.
	 */
	static List<String> outrasTelasIniciais(Context c) {
		List<String> lista = new ArrayList<String>();
		for (ResolveInfo r : c.getPackageManager().queryIntentActivities(home(), PackageManager.MATCH_DEFAULT_ONLY)) {
			if (r.activityInfo == null || r.priority < 0) {
				continue;
			}
			String p = r.activityInfo.packageName;
			if (p.equals(c.getPackageName()) || p.equals("android") || p.matches("com\\.android\\.(tv\\.)?settings") || lista.contains(p)) {
				continue;
			}
			lista.add(p);
		}
		for (String g : TELAS_DO_GOOGLE) {
			if (!lista.contains(g)) {
				lista.add(g);
			}
		}
		return lista;
	}

	/** Os comandos do PREPARAR_TV.bat para esta TV (AdbDaTv.comandoPreparar). */
	static String comandoPreparar(Context c) {
		return AdbDaTv.comandoPreparar(c.getPackageName(), DragonInicioAtivo.class.getName(), outrasTelasIniciais(c), DESLIGADAS);
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
	 * O "SOBREPOR A OUTROS APPS", COMO UM APP DE AUTO START PEDE: abre a tela do
	 * Android já no Dragon Bowling (ou a lista) com um aviso de o que fazer.
	 * Permitido uma vez, o aviso de "ligou" (DragonLigou) abre o jogo sempre
	 * que a TV liga - e nunca mais pede. false se a TV não tem essa tela.
	 */
	static boolean pedirSobrepor(final Activity a) {
		final String aviso = "PARA O JOGO ABRIR SOZINHO AO LIGAR A TV: deixe DRAGON BOWLING "
				+ "PERMITIDO (ligado) e aperte VOLTAR. É só desta vez.";
		boolean abriu = abrir(a, new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + a.getPackageName())))
				|| abrir(a, new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION));
		if (abriu) {
			try {
				// o aviso fica por cima da tela do Android (duas vezes: uns 7 s)
				Toast.makeText(a.getApplicationContext(), aviso, Toast.LENGTH_LONG).show();
				new Handler(Looper.getMainLooper()).postDelayed(new Runnable() {
					@Override
					public void run() {
						Toast.makeText(a.getApplicationContext(), aviso, Toast.LENGTH_LONG).show();
					}
				}, 3500);
			} catch (Throwable ignored) {
			}
		}
		return abriu;
	}

	/**
	 * ACENDE A TELA DA TV ao ligar: se o Android ligou com a tela apagada (TV
	 * em espera com a placa ligada), o jogo a acende, como um aviso de alarme.
	 * Se a TV ficou desligada de verdade (só a luz vermelha), nada a fazer por
	 * aqui: é o ajuste da TV de ligar quando a energia volta.
	 */
	@SuppressWarnings("deprecation")
	static void acenderTela(Context c) {
		try {
			PowerManager pm = (PowerManager) c.getSystemService(Context.POWER_SERVICE);
			if (pm == null) {
				return;
			}
			PowerManager.WakeLock luz = pm.newWakeLock(PowerManager.SCREEN_BRIGHT_WAKE_LOCK
					| PowerManager.ACQUIRE_CAUSES_WAKEUP | PowerManager.ON_AFTER_RELEASE, "DragonBowling:ligou");
			luz.acquire(20000);
		} catch (Throwable t) {
			Log.i(TAG, "inicio: acender a tela: " + t);
		}
	}

	/**
	 * Para a tela de configuração do jogo (SELECT): user://inicio_tv.cfg, uma
	 * linha "nome=valor" por item - tela_inicial (estado()), sobrepor (sim,
	 * nao ou nao_precisa), a versão do Android e quantas vezes o Vigia
	 * reiniciou o jogo travado. Só grava: nada aparece.
	 */
	static void gravarEstado(Context c) {
		String sobrepor = Build.VERSION.SDK_INT < 29 ? "nao_precisa" : (podeAbrirDeFundo(c) ? "sim" : "nao");
		String texto = "tela_inicial=" + estado(c).replace('\n', ' ') + "\nsobrepor=" + sobrepor
				+ "\nandroid=" + Build.VERSION.RELEASE + "\nsdk=" + Build.VERSION.SDK_INT
				+ "\nvigia=" + Vigia.reinicios(c)
				+ "\nadb=" + c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("adb", "") + "\n";
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
	 * O GUARDA (DragonSempre) traz o jogo de volta quando ele sai da tela; aqui
	 * ele espera um pouco: o operador usando a TV (HOME 5 vezes) ou o jogo
	 * pedindo uma permissão na instalação.
	 */
	static void pausarGuarda(Context c, long ms) {
		c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
				.putLong("guarda_ate", SystemClock.elapsedRealtime() + ms).commit();
	}

	static boolean guardaPausada(Context c) {
		long ate = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("guarda_ate", 0);
		long agora = SystemClock.elapsedRealtime();
		// (depois de a TV religar o relógio recomeça: um "até" maior que 20 min é velho)
		return agora < ate && ate - agora <= 20 * 60000L;
	}

	/** Abre a tela inicial da própria TV (ou os ajustes): o nome dela, "config" ou "". */
	static String sairParaTv(Context c) {
		// o operador vai usar a TV: o guarda espera 15 min (HOME volta ao jogo)
		pausarGuarda(c, 15 * 60000L);
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

	/** HOME 5 vezes em 10 s (ou o jogo caindo sem parar): true = sair para a tela da TV. */
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
