import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/statusBox.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Warning card informing the user that Android battery optimizations may
/// terminate background payment monitoring, with a direct action button to
/// request an exemption from the system.
class BatteryOptimizationCard extends StatelessWidget {
  const BatteryOptimizationCard({
    super.key,
    required this.onRequestExemption,
  });

  final VoidCallback onRequestExemption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatusBox(
            title: "battery-optimization-active".tr(),
            description: "battery-optimization-active-description".tr(),
            icon: appStateSettings["outlinedIcons"] == true
                ? Icons.battery_alert_outlined
                : Icons.battery_alert_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 5),
          Button(
            label: "disable-battery-optimization".tr(),
            icon: appStateSettings["outlinedIcons"] == true
                ? Icons.battery_charging_full_outlined
                : Icons.battery_charging_full_rounded,
            onTap: onRequestExemption,
          ),
        ],
      ),
    );
  }
}
