import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:dot_shorthand_custom_lint/src/rules.dart';

PluginBase createPlugin() => _ExcellentLinter();

class _ExcellentLinter extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        const AvoidNestedShorthandsRule(),
        const PreferEnumShorthandRule(),
      ];
}
