import 'package:flutter/material.dart';
import '../services/billing_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  const PaywallScreen({super.key, this.onUnlocked});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedOption = 0; // 0 = Mensual con 7 días gratis, 1 = Anual con 7 días gratis, 2 = Vitalicio

  @override
  void initState() {
    super.initState();
    BillingService.instance.addListener(_onBillingChanged);
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onBillingChanged);
    super.dispose();
  }

  void _onBillingChanged() {
    if (!mounted) return;
    if (BillingService.instance.purchaseSucceeded) {
      widget.onUnlocked?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Bienvenido a SunPath AR PRO! Acceso desbloqueado.'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.of(context).pop(true);
    } else if (BillingService.instance.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(BillingService.instance.lastError!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    setState(() {});
  }

  Future<void> _handleAction() async {
    final billing = BillingService.instance;
    String productId;
    bool isSub = true;

    if (_selectedOption == 0) {
      productId = BillingService.monthlySubscriptionId;
      isSub = true;
    } else if (_selectedOption == 1) {
      productId = BillingService.yearlySubscriptionId;
      isSub = true;
    } else {
      productId = BillingService.lifetimeProductId;
      isSub = false;
    }

    final res = await billing.buyPlan(productId: productId, isSubscription: isSub);
    if (res == 'PRODUCT_NOT_FOUND' || res == 'STORE_NOT_AVAILABLE') {
      // Si la app está en modo de prueba preliminar o sin conexión al emulador de Play Store
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.darkCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primary),
                SizedBox(width: 8),
                Text('Google Play Billing', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: Text(
              'El producto ($productId) está configurado para Google Play. En entorno de prueba interna o cuando actives los identificadores en Play Console, se abrirá la pasarela nativa de Google con la prueba de 7 días.\n\n¿Deseas activar temporalmente el modo PRO para probar localmente?',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                onPressed: () async {
                  await StorageService.instance.setProStatus(true);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    widget.onUnlocked?.call();
                    Navigator.pop(context, true);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                child: const Text('Activar modo Test', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StorageService.instance;
    final billing = BillingService.instance;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('SunPath AR PRO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de Prueba
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        store.isTrialActive
                            ? 'Prueba Gratuita: ${store.trialDaysRemaining} días restantes'
                            : 'Prueba Gratuita de 7 Días Incluida',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Desbloquea el Potencial Solar Completo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Herramienta de precisión para ingenieros solares, arquitectos e instaladores fotovoltaicos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Lista de Beneficios
              _buildFeatureRow(Icons.camera_alt_outlined, 'Bóveda Solar y Brújula AR en Vivo', 'Visualiza el azimut y elevación del sol en tiempo real sobre tu cámara.'),
              _buildFeatureRow(Icons.calculate_outlined, 'Cálculo de Sombras y Separación FV', 'Dimensiona distancias mínimas entre filas de paneles para evitar pérdidas.'),
              _buildFeatureRow(Icons.picture_as_pdf_outlined, 'Reportes Técnicos PDF con Firma Digital', 'Exporta memorias técnicas oficiales y compártelas directamente con tu cliente.'),
              _buildFeatureRow(Icons.cloud_off_rounded, '100% Offline-First sin Publicidad', 'Máxima velocidad en campo, sin consumo de datos y total privacidad.'),

              const SizedBox(height: 28),

              // Selector de Planes
              _buildPlanCard(
                index: 0,
                title: 'Suscripción Mensual',
                trialBadge: '7 DÍAS GRATIS',
                price: billing.monthlyProduct?.price ?? '\$2.99 USD / mes',
                subtext: 'Cancela cuando quieras en Google Play.',
              ),
              const SizedBox(height: 12),
              _buildPlanCard(
                index: 1,
                title: 'Suscripción Anual',
                trialBadge: '7 DÍAS GRATIS • AHORRA 40%',
                price: billing.yearlyProduct?.price ?? '\$19.99 USD / año',
                subtext: 'Equivalente a \$1.66 USD al mes.',
                isPopular: true,
              ),
              const SizedBox(height: 12),
              _buildPlanCard(
                index: 2,
                title: 'Licencia Vitalicia PRO',
                price: billing.lifetimeProduct?.price ?? '\$34.99 USD',
                subtext: 'Pago único. Acceso para siempre.',
              ),

              const SizedBox(height: 24),

              // Botón Principal
              ElevatedButton(
                onPressed: billing.isPurchasePending ? null : _handleAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                child: billing.isPurchasePending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        _selectedOption < 2
                            ? 'Iniciar Prueba Gratuita de 7 Días'
                            : 'Comprar Licencia Vitalicia',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                      ),
              ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => BillingService.instance.restorePurchases(),
                    child: const Text('Restaurar Compras', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                  const Text(' • ', style: TextStyle(color: AppTheme.textMuted)),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cancela fácilmente en cualquier momento desde Google Play Store ➔ Suscripciones.'),
                        ),
                      );
                    },
                    child: const Text('Términos y Cancelación', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    String? trialBadge,
    required String price,
    required String subtext,
    bool isPopular = false,
  }) {
    final isSelected = _selectedOption == index;

    return InkWell(
      onTap: () => setState(() => _selectedOption = index),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.darkBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (trialBadge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPopular ? AppTheme.accent : AppTheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trialBadge,
                            style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtext, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text(
              price,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
