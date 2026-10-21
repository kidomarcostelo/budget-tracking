import 'package:budget/database/tables.dart' hide AppSettings;
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/accountAndBackup.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/openPopup.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/textInput.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

void openAccountOwnerNamePopup(BuildContext context, {VoidCallback? onSaved}) {
  final TextEditingController controller =
      TextEditingController(text: appStateSettings["accountOwnerName"] ?? "");

  Future<void> save(String name) async {
    await updateSettings(
      "accountOwnerName",
      name.trim(),
      updateGlobalState: true,
    );
    popRoute(context);
    onSaved?.call();
  }

  openPopup(
    context,
    icon: appStateSettings["outlinedIcons"]
        ? Icons.badge_outlined
        : Icons.badge_rounded,
    title: "account-owner-name".tr(),
    description: "account-owner-name-description".tr(),
    descriptionWidget: Padding(
      padding: const EdgeInsetsDirectional.only(top: 15),
      child: TextInput(
        controller: controller,
        autoFocus: true,
        labelText: "name".tr(),
        onSubmitted: save,
      ),
    ),
    onSubmit: () => save(controller.text),
    onSubmitLabel: "save".tr(),
    onCancel: () {
      popRoute(context);
    },
    onCancelLabel: "cancel".tr(),
  );
}

class AccountOwnerNameSetting extends StatefulWidget {
  const AccountOwnerNameSetting({
    this.isOutlined = false,
    this.isExpanded = true,
    this.backgroundColor,
    super.key,
  });

  final bool isOutlined;
  final bool isExpanded;
  final Color? backgroundColor;

  @override
  State<AccountOwnerNameSetting> createState() =>
      _AccountOwnerNameSettingState();
}

class _AccountOwnerNameSettingState extends State<AccountOwnerNameSetting> {
  @override
  Widget build(BuildContext context) {
    final String current = (appStateSettings["accountOwnerName"] == null ||
            appStateSettings["accountOwnerName"].toString().trim().isEmpty)
        ? (googleUser?.displayName ?? "set-account-owner-name".tr())
        : appStateSettings["accountOwnerName"].toString();

    if (widget.isOutlined) {
      return SettingsContainerOutlined(
        onTap: () {
          openAccountOwnerNamePopup(
            context,
            onSaved: () {
              if (mounted) setState(() {});
            },
          );
        },
        title: "account-owner-name".tr(),
        description: current,
        icon: appStateSettings["outlinedIcons"]
            ? Icons.badge_outlined
            : Icons.badge_rounded,
        isExpanded: widget.isExpanded,
      );
    }

    return SettingsContainer(
      backgroundColor: widget.backgroundColor,
      onTap: () {
        openAccountOwnerNamePopup(
          context,
          onSaved: () {
            if (mounted) setState(() {});
          },
        );
      },
      title: "account-owner-name".tr(),
      description: current,
      icon: appStateSettings["outlinedIcons"]
          ? Icons.badge_outlined
          : Icons.badge_rounded,
    );
  }
}
