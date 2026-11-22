/// High-performance, zero-dependency formatter for STEM LaTeX math expressions.
/// Converts raw LaTeX syntax into clean, readable Unicode math typography
/// for native Flutter rendering without heavy webviews or external runtimes.
class StemFormulaFormatter {
  StemFormulaFormatter._();

  static const Map<String, String> _superscripts = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
    '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽', ')': '⁾',
    'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ', 'e': 'ᵉ',
    'f': 'ᶠ', 'g': 'ᵍ', 'h': 'ʰ', 'i': 'ⁱ', 'j': 'ʲ',
    'k': 'ᵏ', 'l': 'ˡ', 'm': 'ᵐ', 'n': 'ⁿ', 'o': 'ᵒ',
    'p': 'ᵖ', 'r': 'ʳ', 's': 'ˢ', 't': 'ᵗ', 'u': 'ᵘ',
    'v': 'ᵛ', 'w': 'ʷ', 'x': 'ˣ', 'y': 'ʸ', 'z': 'ᶻ',
  };

  static const Map<String, String> _subscripts = {
    '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄',
    '5': '₅', '6': '₆', '7': '₇', '8': '₈', '9': '₉',
    '+': '₊', '-': '₋', '=': '₌', '(': '₍', ')': '₎',
    'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ',
    'k': 'ₖ', 'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ',
    'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ', 't': 'ₜ', 'u': 'ᵤ',
    'v': 'ᵥ', 'x': 'ₓ',
  };

  static const Map<String, String> _symbols = {
    r'\alpha': 'α',
    r'\beta': 'β',
    r'\gamma': 'γ',
    r'\Gamma': 'Γ',
    r'\delta': 'δ',
    r'\Delta': 'Δ',
    r'\epsilon': 'ε',
    r'\varepsilon': 'ε',
    r'\zeta': 'ζ',
    r'\eta': 'η',
    r'\theta': 'θ',
    r'\Theta': 'Θ',
    r'\iota': 'ι',
    r'\kappa': 'κ',
    r'\lambda': 'λ',
    r'\Lambda': 'Λ',
    r'\mu': 'μ',
    r'\nu': 'ν',
    r'\xi': 'ξ',
    r'\pi': 'π',
    r'\Pi': 'Π',
    r'\rho': 'ρ',
    r'\sigma': 'σ',
    r'\Sigma': 'Σ',
    r'\tau': 'τ',
    r'\upsilon': 'υ',
    r'\phi': 'φ',
    r'\Phi': 'Φ',
    r'\chi': 'χ',
    r'\psi': 'ψ',
    r'\Psi': 'Ψ',
    r'\omega': 'ω',
    r'\Omega': 'Ω',
    r'\times': '×',
    r'\cdot': '·',
    r'\div': '÷',
    r'\pm': '±',
    r'\mp': '∓',
    r'\approx': '≈',
    r'\neq': '≠',
    r'\ne': '≠',
    r'\leq': '≤',
    r'\le': '≤',
    r'\geq': '≥',
    r'\ge': '≥',
    r'\ll': '≪',
    r'\gg': '≫',
    r'\infty': '∞',
    r'\propto': '∝',
    r'\sim': '∼',
    r'\int': '∫',
    r'\iint': '∬',
    r'\iiint': '∭',
    r'\oint': '∮',
    r'\sum': '∑',
    r'\prod': '∏',
    r'\nabla': '∇',
    r'\partial': '∂',
    r'\to': '→',
    r'\rightarrow': '→',
    r'\leftarrow': '←',
    r'\Rightarrow': '⇒',
    r'\Leftarrow': '⇐',
    r'\Leftrightarrow': '⇔',
    r'\iff': '⇔',
    r'\implies': '⇒',
    r'\in': '∈',
    r'\notin': '∉',
    r'\subset': '⊂',
    r'\subseteq': '⊆',
    r'\cup': '∪',
    r'\cap': '∩',
    r'\forall': '∀',
    r'\exists': '∃',
    r'\degree': '°',
    r'^\circ': '°',
  };

  /// Cleans and converts a LaTeX or STEM formula string to Unicode presentation.
  static String format(String input) {
    if (input.isEmpty) return input;

    String text = input.trim();

    // Strip leading/trailing math delimiters
    if (text.startsWith(r'$$') && text.endsWith(r'$$') && text.length >= 4) {
      text = text.substring(2, text.length - 2).trim();
    } else if (text.startsWith(r'$') && text.endsWith(r'$') && text.length >= 2) {
      text = text.substring(1, text.length - 1).trim();
    } else if (text.startsWith(r'\[') && text.endsWith(r'\]') && text.length >= 4) {
      text = text.substring(2, text.length - 2).trim();
    } else if (text.startsWith(r'\(') && text.endsWith(r'\)') && text.length >= 4) {
      text = text.substring(2, text.length - 2).trim();
    }

    // Strip common font wrappers: \text{...}, \mathrm{...}, \mathbf{...}, \mathit{...}
    text = text.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|mathit|textnormal|operatorname)\{([^}]*)\}'),
      (m) => m.group(1) ?? '',
    );

    // Convert \frac{a}{b} recursively to (a)/(b)
    final fracRegex = RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
    while (fracRegex.hasMatch(text)) {
      text = text.replaceAllMapped(fracRegex, (m) {
        final num = m.group(1) ?? '';
        final den = m.group(2) ?? '';
        return '($num / $den)';
      });
    }

    // Convert \sqrt[n]{x} or \sqrt{x}
    text = text.replaceAllMapped(
      RegExp(r'\\sqrt(?:\[([^\]]*)\])?\{([^{}]*)\}'),
      (m) {
        final root = m.group(1);
        final content = m.group(2) ?? '';
        if (root != null && root.isNotEmpty) {
          return '$root√($content)';
        }
        return '√($content)';
      },
    );

    // Replace named Greek and operator symbols
    _symbols.forEach((k, v) {
      text = text.replaceAll(k, v);
    });

    // Handle superscripts: ^{...} or ^x
    text = text.replaceAllMapped(RegExp(r'\^\{([^}]+)\}'), (m) {
      final inside = m.group(1) ?? '';
      return _convertSuper(inside);
    });
    text = text.replaceAllMapped(RegExp(r'\^([0-9a-zA-Z+-])'), (m) {
      final ch = m.group(1) ?? '';
      return _superscripts[ch] ?? '^$ch';
    });

    // Handle subscripts: _{...} or _x
    text = text.replaceAllMapped(RegExp(r'_\{([^}]+)\}'), (m) {
      final inside = m.group(1) ?? '';
      return _convertSub(inside);
    });
    text = text.replaceAllMapped(RegExp(r'_([0-9a-zA-Z+-])'), (m) {
      final ch = m.group(1) ?? '';
      return _subscripts[ch] ?? '_$ch';
    });

    // Clean up escaped spaces and spacing commands
    text = text
        .replaceAll(r'\,', ' ')
        .replaceAll(r'\;', ' ')
        .replaceAll(r'\quad', '   ')
        .replaceAll(r'\qquad', '     ')
        .replaceAll(r'\{', '{')
        .replaceAll(r'\}', '}');

    return text.trim();
  }

  static String _convertSuper(String val) {
    final buffer = StringBuffer();
    for (final char in val.split('')) {
      buffer.write(_superscripts[char] ?? char);
    }
    return buffer.toString();
  }

  static String _convertSub(String val) {
    final buffer = StringBuffer();
    for (final char in val.split('')) {
      buffer.write(_subscripts[char] ?? char);
    }
    return buffer.toString();
  }
}
