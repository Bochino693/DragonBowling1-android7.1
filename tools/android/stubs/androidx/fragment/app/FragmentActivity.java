package androidx.fragment.app;

/**
 * SÓ PARA COMPILAR a TelaCheia: no Godot 3.6.3 a FullScreenGodotApp (a mãe
 * dela) é uma FragmentActivity do androidx, e o javac precisa enxergar essa
 * classe. O androidx de verdade só existe no repositório do Google, então
 * fica este esqueleto. Ele NÃO vai para o classes2.dex nem para o APK: no
 * aparelho vale a FragmentActivity de verdade, que já está no classes.dex do
 * modelo do Godot.
 */
public class FragmentActivity extends android.app.Activity {
}
