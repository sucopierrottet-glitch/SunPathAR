import 'package:flutter/material.dart';
import '../services/billing_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class PaywallScreen extends StatefulWidget {
  final VoidCallback? onUnlocked;
  final bool isMandatoryGate;

  const PaywallScreen({
    super.key,
    this.onUnlocked,
    this.isMandatoryGate = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  int _selectedOption = 0; // 0 = Mensual, 1 = Anual, 2 = Vitalicio

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
    final store = StorageService.instance;
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
    if (!mounted) return;

    if (res == 'PRODUCT_NOT_FOUND' || res == 'STORE_NOT_AVAILABLE') {
      final isTrialStep = store.needsSevenDayTrialActivation && _selectedOption < 2;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                isTrialStep ? 'Activar Prueba de 7 Días' : 'Google Play Billing',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Text(
            isTrialStep
                ? 'Tus 3 horas de acceso gratuito han terminado. En producción se abrirá la pasarela de Google Play con 7 días de prueba gratis antes de cobrar ($productId).\n\n¿Deseas iniciar tu prueba gratuita de 7 días ahora?'
                : 'El producto ($productId) está configurado para Google Play Store. En modo de prueba local puedes simular el pago para desbloquear PRO.',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isTrialStep) {
                  await store.activateSevenDayFreeTrial();
                } else {
                  await store.setProStatus(true);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  widget.onUnlocked?.call();
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: Text(
                isTrialStep ? 'Iniciar 7 Días Gratis' : 'Simular Compra PRO',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StorageService.instance;
    final billing = BillingService.instance;

    final bool showTrialOffer = !store.hasStartedSevenDayTrial && !store.isPaidOnlyStage;
    final bool isPaidOnly = store.isPaidOnlyStage;
    final bool isGate = widget.isMandatoryGate && !store.hasFullAccess;

    String badgeText;
    Color badgeColor;
    String headlineText;
    String subtitleText;

    if (store.isThreeHourFreeActive) {
      badgeText = 'Etapa 1: ${store.formattedFreeTimeRemaining} gratis restantes';
      badgeColor = AppTheme.success;
      headlineText = 'Disfruta Todo PRO Gratis 3 Horas';
      subtitleText = 'Después de tus 3 horas gratis podrás activar 7 días de prueba sin costo.';
    } else if (store.needsSevenDayTrialActivation) {
      badgeText = 'Tus 3 horas gratis terminaron';
      badgeColor = AppTheme.primary;
      headlineText = 'Activa tu Prueba Gratuita de 7 Días';
      subtitleText = 'Para continuar usando la cámara AR, radar de sombra y escáner solar, inicia tus 7 días gratis.';
    } else if (store.isSevenDayTrialActive) {
      badgeText = 'Prueba Gratuita: ${store.trialDaysRemaining} días restantes';
      badgeColor = AppTheme.primary;
      headlineText = 'Asegura tu Acceso PRO Ilimitado';
      subtitleText = 'Tu prueba de 7 días está activa. Suscríbete o adquiere licencia vitalicia cuando quieras.';
    } else {
      badgeText = 'Prueba Gratuita de 7 Días Finalizada';
      badgeColor = Colors.redAccent;
      headlineText = 'Desbloquea SunPath AR PRO';
      subtitleText = 'Tus 3 horas de uso y tu prueba de 7 días han finalizado. Elige un plan para continuar.';
    }

    return PopScope(
      canPop: !isGate,
      child: Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: !isGate,
          leading: isGate
              ? null
              : IconButton(
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
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPaidOnly ? Icons.lock_outline_rounded : Icons.verified_rounded,
                          color: badgeColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  headlineText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),

                // Embudo de 3 Etapas visual
                _buildStageStep('1. 3 Horas de Uso Gratis', 'Acceso total desde el primer minuto sin tarjeta.', store.isThreeHourFreeActive, !store.isThreeHourFreeActive),
                _buildStageStep('2. Free Trial de 7 Días', 'Al acabar las 3h, activa 7 días gratis en Google Play.', store.isSevenDayTrialActive || store.needsSevenDayTrialActivation, store.isPaidOnlyStage),
                _buildStageStep('3. Suscripción o Compra PRO', 'Tras los 7 días, acceso continuo solo con plan activo.', store.isPaidOnlyStage, store.isPro),

                const SizedBox(height: 20),

                // Selector de Planes
                _buildPlanCard(
                  index: 0,
                  title: 'Suscripción Mensual',
                  trialBadge: showTrialOffer ? '7 DÍAS GRATIS' : null,
                  price: billing.monthlyProduct?.price ?? '\$2.99 USD / mes',
                  subtext: showTrialOffer
                      ? '7 días gratis, luego \$2.99/mes. Cancela cuando quieras.'
                      : 'Acceso mensual ilimitado. Cancela cuando quieras.',
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  index: 1,
                  title: 'Suscripción Anual',
                  trialBadge: showTrialOffer ? '7 DÍAS GRATIS • AHORRA 40%' : 'AHORRA 40%',
                  price: billing.yearlyProduct?.price ?? '\$19.99 USD / año',
                  subtext: 'Equivalente a \$1.66 USD al mes.',
                  isPopular: true,
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  index: 2,
                  title: 'Licencia Vitalicia PRO',
                  price: billing.lifetimeProduct?.price ?? '\$34.99 USD',
                  subtext: 'Pago único. Acceso para siempre sin suscripciones.',
                ),

                const SizedBox(height: 22),

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
                          _selectedOption < 2 && showTrialOffer
                              ? 'Activar Prueba Gratuita de 7 Días'
                              : (_selectedOption == 2
                                  ? 'Comprar Licencia Vitalicia'
                                  : 'Suscribirse Ahora'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                ),

                const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildStageStep(String title, String subtitle, bool isCurrent, bool isCompleted) {
    final Color c = isCurrent
        ? AppTheme.primary
        : (isCompleted ? AppTheme.success : AppTheme.textMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle_rounded
                : (isCurrent ? Icons.radio_button_checked_rounded : Icons.circle_outlined),
            color: c,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isCurrent || isCompleted ? Colors.white : AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      if (trialBadge != null)
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
                  ),
                  const SizedBox(height: 4),
                  Text(subtext, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
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
