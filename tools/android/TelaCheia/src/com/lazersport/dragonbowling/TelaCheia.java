package com.lazersport.dragonbowling;

import android.content.Intent;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowInsets;
import android.view.WindowManager;

import org.godotengine.godot.FullScreenGodotApp;

/**
 * A ATIVIDADE DO DRAGON BOWLING NA TV BOX (no lugar da com.godot.game.GodotApp
 * do modelo Android do Godot 3.6.3; o manifesto do modelo aponta para esta).
 *
 * O jogo ocupa a tela INTEIRA da TV Box Android 7.1: sem barra do sistema,
 * sem margem reservada para ela e também na área de "overscan" que o Android
 * da TV deixa preta em volta da imagem; a tela não apaga. É a mesma tela
 * cheia da Build 10 (que o Gradle montava no GodotApp.java), agora num
 * classes2.dex pronto: o APK sai sem Gradle.
 *
 * Os recursos do modelo (o tema) são procurados pelo NOME, no pacote
 * com.godot.game: o Godot muda o pacote do APK na exportação, mas não o dos
 * recursos. A área do jogo é o primeiro filho do conteúdo da janela.
 *
 * O JOGO ABRE SOZINHO AO LIGAR (InicioDaTv, o método do Strike Kids): a
 * tela inicial (DragonInicioAtivo), o aviso de "ligou" (DragonLigou) e a
 * volta da espera (ouvirTela). Enquanto a TV não abre o jogo sozinha, o jogo
 * pede ao Android para ser a tela inicial ("Dragon Bowling" + SEMPRE).
 *
 * Feito por tools/android/TelaCheia/construir.sh (Java 8, sem Gradle).
 */
public class TelaCheia extends FullScreenGodotApp {
	private static final int TELA_CHEIA = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
			| View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
			| View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
			| View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
			| View.SYSTEM_UI_FLAG_FULLSCREEN
			| View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY;
	private static final int JANELA_INTEIRA = WindowManager.LayoutParams.FLAG_FULLSCREEN
			| WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
			| WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
			| WindowManager.LayoutParams.FLAG_LAYOUT_IN_OVERSCAN;

	/**
	 * O pedido da tela inicial (como o Strike Kids faz na tela de espera): uma
	 * vez por abertura do jogo, com o jogo na frente e a placa SOSSEGADA (nenhum
	 * botão nem sensor há SOSSEGO_MS): nunca no meio de uma partida.
	 */
	private static final long SOSSEGO_MS = 20000;
	private static final long OLHAR_DE_NOVO_MS = 5000;
	private static boolean telaInicialPedida = false;
	private final Handler relogio = new Handler(Looper.getMainLooper());
	private long ultimoToque = SystemClock.elapsedRealtime();
	private final Runnable pedirTelaInicial = new Runnable() {
		@Override
		public void run() {
			if (telaInicialPedida || isFinishing()) {
				return;
			}
			if (SystemClock.elapsedRealtime() - ultimoToque < SOSSEGO_MS || !hasWindowFocus()) {
				relogio.postDelayed(this, OLHAR_DE_NOVO_MS);
				return;
			}
			telaInicialPedida = true;
			try {
				String estado = InicioDaTv.estado(TelaCheia.this);
				if (!estado.equals("jogo")) {
					Log.i("DragonBowling", "inicio: a TV ainda não abre o jogo (" + estado + "): "
							+ InicioDaTv.escolher(TelaCheia.this, true));
				}
			} catch (Throwable t) {
				Log.i("DragonBowling", "inicio: tela inicial: " + t);
			}
		}
	};

	@Override
	public void onCreate(Bundle savedInstanceState) {
		// o tema principal do modelo (fundo preto, tela cheia, overscan); sem
		// ele a janela ficaria com o tema da imagem de abertura
		int tema = recurso("GodotAppMainTheme", "style");
		if (tema != 0) {
			setTheme(tema);
		}
		super.onCreate(savedInstanceState);
		getWindow().addFlags(JANELA_INTEIRA | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
		getWindow().setBackgroundDrawable(new ColorDrawable(Color.BLACK));
		View area = areaDoJogo();
		if (area != null) {
			area.setPadding(0, 0, 0, 0);
			if (Build.VERSION.SDK_INT >= 20) {
				// no lugar do ajuste do Godot, que deixaria a margem das barras
				area.setOnApplyWindowInsetsListener(new View.OnApplyWindowInsetsListener() {
					@Override
					public WindowInsets onApplyWindowInsets(View v, WindowInsets insets) {
						v.setPadding(0, 0, 0, 0);
						return insets;
					}
				});
			}
		}
		telaCheia();
		// a TV voltando da espera (ligada pelo controle) reinicia o jogo
		InicioDaTv.ouvirTela(this);
	}

	/** O estado do "abrir ao ligar" para a tela de configuração (SELECT) do jogo. */
	private final Runnable gravarEstado = new Runnable() {
		@Override
		public void run() {
			try {
				InicioDaTv.gravarEstado(TelaCheia.this);
			} catch (Throwable t) {
				Log.i("DragonBowling", "inicio: estado: " + t);
			}
		}
	};

	@Override
	protected void onResume() {
		super.onResume();
		telaCheia();
		// (de volta dos ajustes do Android: a configuração já mostra o novo estado)
		relogio.post(gravarEstado);
		relogio.removeCallbacks(pedirTelaInicial);
		if (!telaInicialPedida) {
			relogio.postDelayed(pedirTelaInicial, OLHAR_DE_NOVO_MS);
		}
	}

	@Override
	protected void onPause() {
		relogio.removeCallbacks(pedirTelaInicial);
		super.onPause();
	}

	/**
	 * Botão ou sensor da placa (ou o controle remoto): alguém está jogando.
	 * (Só teclas e botões: um eixo de joystick que treme não pode impedir o
	 * pedido para sempre - e o jogo não usa o direcional.)
	 */
	@Override
	public boolean dispatchKeyEvent(KeyEvent evento) {
		ultimoToque = SystemClock.elapsedRealtime();
		return super.dispatchKeyEvent(evento);
	}

	@Override
	public void onActivityResult(int pedido, int resultado, Intent dados) {
		super.onActivityResult(pedido, resultado, dados);
		if (pedido == InicioDaTv.PEDIDO_PAPEL) {
			try {
				InicioDaTv.depoisDoPapel(this, resultado);
			} catch (Throwable t) {
				Log.i("DragonBowling", "inicio: tela inicial: " + t);
			}
		}
	}

	@Override
	public void onWindowFocusChanged(boolean hasFocus) {
		super.onWindowFocusChanged(hasFocus);
		if (hasFocus) {
			telaCheia();
		}
	}

	/** Reafirma a janela na tela inteira toda vez que o jogo volta à frente. */
	private void telaCheia() {
		getWindow().addFlags(JANELA_INTEIRA);
		getWindow().setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);
		getWindow().getDecorView().setSystemUiVisibility(TELA_CHEIA);
	}

	/** A área onde o Godot desenha (godot_fragment_container). */
	private View areaDoJogo() {
		View conteudo = findViewById(android.R.id.content);
		if (conteudo instanceof ViewGroup && ((ViewGroup) conteudo).getChildCount() > 0) {
			return ((ViewGroup) conteudo).getChildAt(0);
		}
		int id = recurso("godot_fragment_container", "id");
		return id != 0 ? findViewById(id) : null;
	}

	private int recurso(String nome, String tipo) {
		Resources r = getResources();
		int id = r.getIdentifier(nome, tipo, "com.godot.game");
		if (id == 0) {
			id = r.getIdentifier(nome, tipo, getPackageName());
		}
		return id;
	}
}
