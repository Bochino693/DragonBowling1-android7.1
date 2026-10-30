package com.lazersport.dragonbowling;

import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
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
 * volta da espera (ouvirTela). O JOGO NUNCA ABRE JANELA NENHUMA SOZINHO: na
 * máquina só há os botões da Zero Delay e ninguém consegue fechar uma janela
 * do Android. A tela inicial e o "Sobrepor a outros apps" são deixados
 * prontos pelo PC (PREPARAR_TV.bat, adb) ou pelo técnico com o controle
 * remoto, nos ajustes.
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

	private final Handler relogio = new Handler(Looper.getMainLooper());

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

	@Override
	protected void onResume() {
		super.onResume();
		telaCheia();
		// só grava o estado (nenhuma janela): a configuração mostra SIM ou NÃO
		relogio.post(gravarEstado);
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
