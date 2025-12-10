import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Reguła lintera: Unikaj zagnieżdżonych skrótów z kropką
class AvoidNestedShorthandsRule extends DartLintRule {
  const AvoidNestedShorthandsRule()
      : super(
          code: const LintCode(
            name: 'avoid_nested_shorthands',
            problemMessage:
                'Nested dot-shorthands are forbidden (e.g., .new(.new(.new()))). '
                'Use fully qualified names or single-level shorthand only.',
          ),
        );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final nodeText = node.toString();
      if (_hasNestedShorthand(nodeText)) {
        reporter.atNode(node, code);
      }
    });
  }

  bool _hasNestedShorthand(String text) {
    final dotShorthandPattern = RegExp(r'\.\w+\(\s*\.\w+\s*\(');
    return dotShorthandPattern.hasMatch(text);
  }
}

/// Reguła lintera: Preferuj skrót z kropką (dot-shorthand)
class PreferEnumShorthandRule extends DartLintRule {
  const PreferEnumShorthandRule()
      : super(
          code: const LintCode(
            name: 'prefer_enum_shorthand',
            problemMessage:
                'Consider using dot-shorthand: use .value instead of Type.value',
          ),
        );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPrefixedIdentifier((node) {
      if (_shouldSuggestShorthand(node)) {
        reporter.atNode(
          node,
          code,
        );
      }
    });

    // Obsługuj też MethodInvocation: Border.all(...), ImageFilter.blur(...)
    context.registry.addMethodInvocation((node) {
      if (_shouldSuggestShorthandForMethodInvocation(node)) {
        reporter.atNode(
          node,
          code,
        );
      }
    });
  }

  bool _shouldSuggestShorthand(PrefixedIdentifier node) {
    // 1. Podstawowe sprawdzenie składni: WielkaLitera.malaLitera
    final prefixName = node.prefix.name;
    final identifierName = node.identifier.name;
    if (prefixName.isEmpty || identifierName.isEmpty) return false;
    if (prefixName[0].toUpperCase() != prefixName[0]) {
      return false; // Prefiks nie zaczyna się od wielkiej litery
    }
    if (identifierName[0].toLowerCase() != identifierName[0]) {
      return false; // Identyfikator nie zaczyna się od małej litery
    }

    // 2. Sprawdzenie typu: typ wyrażenia musi odpowiadać nazwie prefiksu
    final expressionType = node.staticType;
    if (expressionType == null) return false;
    // Jeśli nazwa typu nie zgadza się z prefiksem, to prawdopodobnie
    // chodzi o statyczne pole/konstantę innej klasy
    // np. Colors.red (typ Color != Colors) -> nie sugerujemy
    // np. Sizes.p2 (typ double != Sizes) -> nie sugerujemy
    // np. MyEnum.value (typ MyEnum == MyEnum) -> możemy zasugerować
    // np. ImageFilter.blur() (typ ImageFilter == ImageFilter) -> możemy zasugerować
    if (expressionType.element?.name != prefixName) {
      return false;
    }

    // 3. Sprawdzenie kontekstu: oczekiwany typ musi pozwalać na skrót
    final contextType = _getContextType(node);
    if (contextType == null) {
      return false; // Konserwatywnie: jeżeli brak kontekstu, nie sugerujemy
    }

    // Jeżeli oczekiwany typ jest dokładnie takim samym typem jak wyrażenie,
    // użycie skrótu jest bezpieczne.
    // Obejmuje to enumy, statyczne metody, konstruktory itp.
    if (contextType == expressionType) return true;

    // Jeżeli kontekstowy typ jest inny (np. typ bazowy), sprawdź, czy ma
    // statyczny członek o tej samej nazwie — wtedy też można zasugerować.
    if (_typeHasStaticMember(contextType, identifierName)) {
      return true;
    }

    return false;
  }

  bool _shouldSuggestShorthandForMethodInvocation(MethodInvocation node) {
    // Obsługuje: Border.all(...) -> .all(...), ImageFilter.blur(...) -> .blur(...)
    final target = node.target;

    // Target może być PrefixedIdentifier (Border.all) lub null (implicit this.all)
    if (target == null) return false; // Implicit this

    String? prefixName;
    if (target is PrefixedIdentifier) {
      prefixName = target.prefix.name;
    } else if (target is SimpleIdentifier) {
      // To może być Static class method access: Border.all()
      // W tym wypadku target to właśnie SimpleIdentifier "Border"
      prefixName = target.name;
    } else {
      return false;
    }

    final methodName = node.methodName.name;

    // Sprawdzenie składni: WielkaLitera.malaLitera
    if (prefixName.isEmpty || methodName.isEmpty) return false;
    if (prefixName[0].toUpperCase() != prefixName[0]) return false;
    if (methodName[0].toLowerCase() != methodName[0]) return false;

    // Typ zwracany
    final returnType = node.staticType;
    if (returnType == null) return false;

    // Sprawdzenie czy typ zwracany odpowiada nazwie prefiksu
    // Dla ImageFilter.blur() -> returnType to ImageFilter
    // Ale mogą być różne warianty: może być ImageFilter lub ImageFilter?
    final returnTypeNameMatches = returnType.element?.name == prefixName;
    
    // Sprawdzenie kontekstu
    final contextType = _getContextTypeForNode(node);
    if (contextType == null) return false;

    // Jeśli typ się zgadza i kontekst pozwala, sugerujemy
    if (returnTypeNameMatches) {
      if (contextType == returnType) return true;
      if (_isAssignableTo(returnType, contextType)) return true;
    }

    // Alternatywa: jeśli zwracany typ jest przypisywalny do oczekiwanego
    // (np. Border <: BoxBorder), również sugerujemy
    if (_isAssignableTo(returnType, contextType)) {
      return true;
    }

    // Ostatnia szansa: sprawdzamy czy kontekst ma statyczną metodę
    // o tej samej nazwie co nasza metoda
    if (_typeHasStaticMember(contextType, methodName)) {
      return true;
    }

    return false;
  }

  bool _isAssignableTo(DartType? source, DartType? target) {
    if (source == null || target == null) return false;
    if (source == target) return true;

    // Sprawdzenie czy source jest subtype'em target
    // np. Border <: BoxBorder
    if (source is InterfaceType && target is InterfaceType) {
      // Sprawdzamy czy source.element jest subtype'em target.element
      return source.element.allSupertypes.any((supertype) {
        return supertype.element == target.element;
      });
    }

    return false;
  }

  DartType? _getContextType(PrefixedIdentifier node) {
    // Próba pobrania typu z kontekstu (np. parametrów, deklaracji zmiennej, przypisania itp.)

    final parent = node.parent;

    // Named argument: filter: ImageFilter.blur(...) lub padding: EdgeInsets.all(...)
    if (parent is NamedExpression) {
      return parent.element?.type;
    }

    // Jeśli node jest wewnątrz MethodInvocation (dla named arguments w wywołaniu)
    var ancestor = node.parent;
    while (ancestor != null) {
      if (ancestor is NamedExpression) {
        return ancestor.element?.type;
      }
      if (ancestor is MethodInvocation) {
        // Sprawdź czy któryś z named arguments zawiera nasz node
        for (final arg in ancestor.argumentList.arguments) {
          if (arg is NamedExpression) {
            // Sprawdzamy czy nasz node jest dzieckiem tego wyrażenia
            final nodeAncestor =
                node.thisOrAncestorMatching((n) => n == arg.expression);
            if (nodeAncestor != null) {
              return arg.element?.type;
            }
          }
        }
      }
      ancestor = ancestor.parent;
    }

    // Positional argument?
    if (parent is ArgumentList) {
      // This is harder without staticParameterElement on node.
      // But let's skip for now if not available.
    }

    // Deklaracja zmiennej: `final MyEnum e = MyEnum.value;`
    if (parent is VariableDeclaration) {
      // Jeśli deklaracja jawnie podaje typ: `final MyEnum e = ...;`,
      // można odczytać go z rodzica `VariableDeclarationList.type`.
      final parentList = parent.parent;
      if (parentList is VariableDeclarationList) {
        final typeAnnotation = parentList.type;
        if (typeAnnotation != null) {
          final t = typeAnnotation.type;
          if (t != null) return t;
        }
      }

      // Fallback: spróbuj odczytać element zmiennej (stare API `declaredElement`).
      // Jest to oznaczone jako deprecated, ale daje nam jawny typ zamiast `dynamic`.
      try {
        final Element? declared = parent.declaredFragment?.element;
        if (declared is VariableElement) return declared.type;
      } on Object catch (_) {}
      return null;
    }

    // Przypisanie: `x = MyEnum.value;`
    if (parent is AssignmentExpression && parent.rightHandSide == node) {
      final writeElement = parent.writeElement;
      if (writeElement is VariableElement) {
        return writeElement.type;
      }
      return parent.leftHandSide.staticType;
    }

    // Instrukcja `return`: `return MyEnum.value;`
    if (parent is ReturnStatement) {
      // Szukamy otaczającej funkcji/metody, aby odczytać zadeklarowany typ zwracany
      final functionBody = parent.thisOrAncestorOfType<FunctionBody>();
      final function = functionBody?.parent;
      if (function is FunctionDeclaration) {
        return function.returnType?.type;
      } else if (function is MethodDeclaration) {
        return function.returnType?.type;
      }
    }

    return null;
  }

  DartType? _getContextTypeForNode(AstNode node) {
    // Uniwersalna wersja dla dowolnego AstNode (PrefixedIdentifier, MethodInvocation, itp.)
    final parent = node.parent;

    // Named argument: bezpośrednio sprawdzamy typ parametru
    if (parent is NamedExpression) {
      final paramType = parent.element?.type;
      if (paramType != null) return paramType;
    }

    // Szukamy w przodkach NamedExpression
    var ancestor = node.parent;
    while (ancestor != null) {
      if (ancestor is NamedExpression) {
        final paramType = ancestor.element?.type;
        if (paramType != null) return paramType;
      }
      ancestor = ancestor.parent;
    }

    // Deklaracja zmiennej
    if (parent is VariableDeclaration) {
      final parentList = parent.parent;
      if (parentList is VariableDeclarationList) {
        final typeAnnotation = parentList.type;
        if (typeAnnotation != null) {
          final t = typeAnnotation.type;
          if (t != null) return t;
        }
      }
      try {
        final Element? declared = parent.declaredFragment?.element;
        if (declared is VariableElement) return declared.type;
      } on Object catch (_) {}
      return null;
    }

    // Przypisanie
    if (parent is AssignmentExpression) {
      if (parent.rightHandSide == node) {
        final writeElement = parent.writeElement;
        if (writeElement is VariableElement) {
          return writeElement.type;
        }
        return parent.leftHandSide.staticType;
      }
    }

    // Return statement
    if (parent is ReturnStatement) {
      final functionBody = parent.thisOrAncestorOfType<FunctionBody>();
      final function = functionBody?.parent;
      if (function is FunctionDeclaration) {
        return function.returnType?.type;
      } else if (function is MethodDeclaration) {
        return function.returnType?.type;
      }
    }

    return null;
  }

  bool _typeHasStaticMember(DartType type, String memberName) {
    if (type is InterfaceType) {
      final element = type.element;
      // Sprawdź statyczne pola/gettery
      final getter = element.getGetter(memberName);
      if (getter != null && getter.isStatic) return true;
      final method = element.getMethod(memberName);
      if (method != null && method.isStatic) return true;

      // Sprawdź stałe/enumy
      if (element is EnumElement) {
        final field = element.getField(memberName);
        if (field != null) return true;
      }
    }
    return false;
  }
}
