import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 首页 Inspector 面板宽度提供者
final homeInspectorWidthProvider = StateProvider<double>((ref) => 460);

/// 任务详情页 Insights 面板宽度提供者
final detailInsightsWidthProvider = StateProvider<double>((ref) => 320);

/// 最小面板宽度
const double kMinPanelWidth = 280;

/// 最大面板宽度（相对于屏幕宽度的比例）
const double kMaxPanelWidthRatio = 0.5;
