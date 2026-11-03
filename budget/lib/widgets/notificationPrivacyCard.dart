import 'package:budget/colors.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class NotificationPrivacyCard extends StatelessWidget {
  const NotificationPrivacyCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: getColor(context, "lightDarkAccent").withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: getColor(context, "lightDarkAccentHeavy").withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                appStateSettings["outlinedIcons"]
                    ? Icons.shield_outlined
                    : Icons.shield_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFont(
                  text: "notification-privacy-title".tr(),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFont(
            text: "notification-privacy-description".tr(),
            fontSize: 13.5,
            maxLines: null,
            textColor: getColor(context, "black").withOpacity(0.75),
          ),
        ],
      ),
    );
  }
}
