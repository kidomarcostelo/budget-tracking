import 'package:budget/struct/receiptParser.dart';

/// Normalized name token resolver for identifying user ownership
/// and distinguishing internal transfers from external expenses.
class OwnerResolver {
  static const Set<String> _titlesAndSuffixes = {
    'mr',
    'mrs',
    'ms',
    'miss',
    'dr',
    'atty',
    'engr',
    'jr',
    'sr',
    'ii',
    'iii',
    'iv',
    'v',
  };

  /// Clean raw name string: remove punctuation, brackets, lowercase,
  /// and split into non-empty tokens.
  static List<String> tokenize(String? raw) {
    if (raw == null) return [];
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[,.\-_/()\[\]{}:;]'), ' ')
        .trim();
    if (cleaned.isEmpty) return [];

    return cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_titlesAndSuffixes.contains(t))
        .toList();
  }

  /// Check if two tokens match:
  /// 1. Exact match: `a == b`
  /// 2. Initial match: single letter matches start of other (`c` matches `costelo`)
  /// 3. Mask match: `*` or `x` in token (`o***` matches `omar`, `c******` matches `costelo`)
  static bool areTokensMatching(String tokenA, String tokenB) {
    if (tokenA == tokenB) return true;
    if (tokenA.isEmpty || tokenB.isEmpty) return false;

    // Single letter initial match
    if (tokenA.length == 1 && tokenB.startsWith(tokenA)) return true;
    if (tokenB.length == 1 && tokenA.startsWith(tokenB)) return true;

    // Masked matching
    final isMaskA = tokenA.contains('*');
    final isMaskB = tokenB.contains('*');

    if (isMaskA || isMaskB) {
      final maskToken = isMaskA ? tokenA : tokenB;
      final targetToken = isMaskA ? tokenB : tokenA;

      // Both must start with the same initial character
      if (maskToken[0] != targetToken[0]) return false;

      // If both are masks (e.g. `c*` vs `c******`)
      if (isMaskA && isMaskB) {
        return maskToken[0] == targetToken[0];
      }

      // Check unmasked leading characters (e.g. "ki*" vs "kid")
      int prefixLen = 0;
      while (prefixLen < maskToken.length &&
          maskToken[prefixLen] != '*' &&
          prefixLen < targetToken.length) {
        if (maskToken[prefixLen] != targetToken[prefixLen]) return false;
        prefixLen++;
      }
      if (prefixLen < maskToken.length && maskToken[prefixLen] != '*') {
        return false;
      }

      return true;
    }

    return false;
  }

  /// Compare two names to determine if they refer to the same individual.
  static bool areNamesMatching(String? nameA, String? nameB) {
    if (nameA == null || nameB == null) return false;
    final tokensA = tokenize(nameA);
    final tokensB = tokenize(nameB);

    if (tokensA.isEmpty || tokensB.isEmpty) return false;

    // If both have 1 token only
    if (tokensA.length == 1 && tokensB.length == 1) {
      return areTokensMatching(tokensA[0], tokensB[0]) &&
          (tokensA[0].length >= 3 || tokensB[0].length >= 3);
    }

    // Determine shorter and longer token lists
    final shorter = tokensA.length <= tokensB.length ? tokensA : tokensB;
    final longer = tokensA.length <= tokensB.length ? tokensB : tokensA;

    int matchedCount = 0;
    final usedIndices = <int>{};

    for (final shortToken in shorter) {
      for (int i = 0; i < longer.length; i++) {
        if (!usedIndices.contains(i) &&
            areTokensMatching(shortToken, longer[i])) {
          usedIndices.add(i);
          matchedCount++;
          break;
        }
      }
    }

    // If all tokens of the shorter list matched (e.g. "Kid Omar C." in "Kid Omar Costelo")
    if (matchedCount == shorter.length && shorter.isNotEmpty) {
      if (matchedCount >= 2) return true;
      if (shorter[0].length >= 4 && !shorter[0].contains('*')) return true;
    }

    // Or if at least 2 significant tokens match (e.g. "KID OMAR RENDON COSTELO" vs "Kid Omar Costelo")
    if (matchedCount >= 2) {
      return true;
    }

    return false;
  }

  /// Check if a given name matches the user's owner profile.
  static bool isOwnerMatch(
    String? name, {
    String? ownerName,
    String? googleDisplayName,
  }) {
    if (name == null || name.trim().isEmpty) return false;

    if (ownerName != null && ownerName.trim().isNotEmpty) {
      if (areNamesMatching(name, ownerName)) return true;
    }

    if (googleDisplayName != null && googleDisplayName.trim().isNotEmpty) {
      if (areNamesMatching(name, googleDisplayName)) return true;
    }

    return false;
  }

  /// Classify whether a transaction is a self-transfer between accounts owned
  /// by the user, or an expense paid to an external party.
  static bool isSelfTransfer({
    required ParsedBankReceipt receipt,
    String? ownerName,
    String? googleDisplayName,
    required bool destinationWalletExists,
  }) {
    // 1. Identical From and To: guaranteed self-transfer
    if (receipt.sourceName != null &&
        receipt.destinationName != null &&
        areNamesMatching(receipt.sourceName, receipt.destinationName)) {
      return true;
    }

    final isSourceOwner = isOwnerMatch(
      receipt.sourceName,
      ownerName: ownerName,
      googleDisplayName: googleDisplayName,
    );

    final isDestOwner = isOwnerMatch(
      receipt.destinationName,
      ownerName: ownerName,
      googleDisplayName: googleDisplayName,
    );

    // 2. Both source and destination resolve to the owner
    if (isSourceOwner && isDestOwner) {
      return true;
    }

    // 3. Source is owner and destination wallet exists in Cashew
    if (isSourceOwner && destinationWalletExists) {
      // If destinationName is specified and definitely NOT the owner (e.g. "RICA T." or "Maria Santos"),
      // then it's an expense to an external recipient!
      if (receipt.destinationName != null &&
          receipt.destinationName!.trim().isNotEmpty &&
          !isDestOwner) {
        return false;
      }
      return true;
    }

    return false;
  }
}
