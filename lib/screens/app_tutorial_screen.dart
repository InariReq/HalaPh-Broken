import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_tutorial_service.dart';
import '../services/guide_mode_demo_data.dart';
import '../services/guide_mode_demo_state.dart';
import '../services/guide_presenter_controller.dart';
import '../services/guide_quest_controller.dart';
import '../widgets/guide_quest_overlay.dart';
import '../widgets/transport_mode_widgets.dart';

class GuideModeTargetKeys {
  final GlobalKey? homeNavKey;
  final GlobalKey? exploreNavKey;
  final GlobalKey? plansNavKey;
  final GlobalKey? favoritesNavKey;
  final GlobalKey? friendsNavKey;
  final GlobalKey? profileNavKey;

  const GuideModeTargetKeys({
    this.homeNavKey,
    this.exploreNavKey,
    this.plansNavKey,
    this.favoritesNavKey,
    this.friendsNavKey,
    this.profileNavKey,
  });
}

class AppTutorialScreen extends StatefulWidget {
  final bool launchedFromSettings;
  final VoidCallback onFinish;
  final VoidCallback onSkip;
  final GuideModeTargetKeys targetKeys;
  final ValueChanged<int>? onStepChanged;
  final GuidePresenterController? presenterController;

  const AppTutorialScreen({
    super.key,
    required this.launchedFromSettings,
    required this.onFinish,
    required this.onSkip,
    this.targetKeys = const GuideModeTargetKeys(),
    this.onStepChanged,
    this.presenterController,
  });

  @override
  State<AppTutorialScreen> createState() => _AppTutorialScreenState();
}

class _AppTutorialScreenState extends State<AppTutorialScreen> {
  late final List<GuideQuestStep> _steps = GuideQuestController.buildSteps();

  int _index = 0;
  bool _closing = false;
  bool _actionBusy = false;
  bool _showObjectiveComplete = false;
  bool _guideCardExpanded = true;
  GuidePresenterScene _currentScene = GuidePresenterScene.practiceIntro;
  bool _destinationPreviewVisible = false;
  bool _routeOptionsVisible = false;
  bool _routeGuideVisible = false;
  bool _fareBreakdownVisible = false;
  bool _destinationSaved = false;
  bool _addedToPlan = false;
  bool _collaborationShown = false;
  bool _liveLoading = false;
  String? _fallbackReason;
  String? _statusMessage;
  String _selectedCommuterType = 'Regular';
  GuideModeDemoRouteOption? _selectedRoute;
  final Set<String> _completedActions = <String>{};
  int _transitionToken = 0;
  int _liveActionToken = 0;

  bool get _isFirst => _index == 0;
  bool get _isLast => _index == _steps.length - 1;
  bool get _isStandaloneReplay =>
      widget.launchedFromSettings && widget.presenterController == null;

  @override
  void initState() {
    super.initState();
    GuideModeDemoState.reset();
    widget.presenterController?.addListener(_handlePresenterSignal);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  @override
  void dispose() {
    _liveActionToken++;
    _transitionToken++;
    widget.presenterController?.removeListener(_handlePresenterSignal);
    super.dispose();
  }

  void _notifyStepChanged() {
    widget.onStepChanged?.call(_index);
  }

  void _handlePresenterSignal() {
    final controller = widget.presenterController;
    final signal = controller?.lastSignal;
    if (signal == null || _closing) return;
    switch (signal) {
      case GuidePresenterSignal.openExplore:
        _completeIfExpected(
          GuideQuestActionId.openExplore,
          'Objective complete: Explore opened.',
        );
        break;
      case GuidePresenterSignal.selectIntramuros:
        final destination = controller?.selectedDestination;
        if (destination == null ||
            !destination.name.toLowerCase().contains('intramuros')) {
          return;
        }
        GuideModeDemoState.selectIntramuros();
        setState(() {
          _destinationPreviewVisible = true;
        });
        _completeIfExpected(
          GuideQuestActionId.selectIntramuros,
          'Objective complete: Intramuros selected.',
        );
        break;
      case GuidePresenterSignal.openSettings:
        _completeIfExpected(
          GuideQuestActionId.openSettings,
          'Objective complete: Settings opened.',
        );
        break;
      case GuidePresenterSignal.openFavorites:
      case GuidePresenterSignal.openPlans:
      case GuidePresenterSignal.openFriends:
        break;
    }
    controller?.clearSignal();
  }

  Future<void> _close({
    required bool skipped,
    required String reason,
  }) async {
    if (_closing) return;
    debugPrint('Guide Mode closed: $reason');
    _transitionToken++;
    _liveActionToken++;
    setState(() {
      _closing = true;
      _actionBusy = false;
      _liveLoading = false;
    });
    await AppTutorialService.setTutorialCompleted(true);
    if (!mounted) return;
    if (skipped) {
      widget.onSkip();
    } else {
      widget.onFinish();
    }
  }

  Future<void> _advance() async {
    if (_isLast) {
      GuideModeDemoState.finishGuide();
      _close(skipped: false, reason: 'finish');
      return;
    }
    setState(() {
      _index += 1;
      _showObjectiveComplete = false;
      _statusMessage = null;
      _guideCardExpanded = true;
      _syncSceneForIndex();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  void _back() {
    final canGoBack = !_isFirst && !_closing;
    if (!canGoBack) {
      debugPrint(
        'Guide Mode back: currentStep=$_index, canGoBack=$canGoBack, '
        'result=${_actionBusy ? 'blocked loading' : 'first step'}',
      );
      return;
    }
    final nextIndex = (_index - 1).clamp(0, _steps.length - 1);
    _liveActionToken++;
    debugPrint(
      'Guide Mode back: currentStep=$_index, canGoBack=true, '
      'result=${_actionBusy ? 'cancelLoadingAndPreviousStep' : 'previousStep'} $nextIndex',
    );
    _transitionToken++;
    setState(() {
      _index = nextIndex;
      _resetTransientStateForStep(nextIndex);
      _clearCompletedActionsFrom(nextIndex);
      _syncSceneForIndex();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  void _restartGuide() {
    _transitionToken++;
    _liveActionToken++;
    setState(() {
      _index = 0;
      _showObjectiveComplete = false;
      _statusMessage = null;
      _completedActions.clear();
      _guideCardExpanded = true;
      _currentScene = GuidePresenterScene.practiceIntro;
      _destinationPreviewVisible = false;
      _routeOptionsVisible = false;
      _routeGuideVisible = false;
      _fareBreakdownVisible = false;
      _destinationSaved = false;
      _addedToPlan = false;
      _collaborationShown = false;
      _liveLoading = false;
      _fallbackReason = null;
      _selectedCommuterType = 'Regular';
      _selectedRoute = null;
    });
    GuideModeDemoState.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyStepChanged());
  }

  void _resetTransientStateForStep(int targetIndex) {
    _showObjectiveComplete = false;
    _statusMessage = null;
    _guideCardExpanded = true;
    _actionBusy = false;
    _liveLoading = false;

    GuideModeDemoState.restoreForStep(targetIndex);

    if (targetIndex < 3) {
      _destinationPreviewVisible = false;
    }
    if (targetIndex < 4) {
      _routeOptionsVisible = false;
      _selectedRoute = null;
      _fallbackReason = null;
    }
    if (targetIndex < 5) {
      _routeGuideVisible = false;
    }
    if (targetIndex < 6) {
      _fareBreakdownVisible = false;
    }
    if (targetIndex < 8) {
      _destinationSaved = false;
    }
    if (targetIndex < 10) {
      _addedToPlan = false;
    }
    if (targetIndex < 12) {
      _collaborationShown = false;
    }
    if (targetIndex < 14) {
      _selectedCommuterType = GuideModeDemoState.commuterType;
    }
  }

  void _clearCompletedActionsFrom(int targetIndex) {
    for (var i = targetIndex; i < _steps.length; i++) {
      final actionId = _steps[i].actionId;
      if (actionId != null) {
        _completedActions.remove(actionId);
      }
    }
  }

  void _syncSceneForIndex() {
    final sceneIndex = _index.clamp(
      0,
      GuidePresenterScene.values.length - 1,
    );
    _currentScene = GuidePresenterScene.values[sceneIndex];
  }

  void _handleCardPrimary(GuideQuestStep step) {
    if (_closing || _actionBusy) return;
    final actionId = step.actionId;
    if (step.type == GuideQuestStepType.finish ||
        actionId == GuideQuestActionId.finish) {
      GuideModeDemoState.finishGuide();
      _close(skipped: false, reason: 'finish');
      return;
    }
    if (_isStandaloneReplay && _shouldCompleteFromCardInReplay(step)) {
      _completeReplayFallbackStep(step);
      return;
    }
    if (!step.requiresUserAction) {
      _completeObjective(actionId ?? step.title, step.completionMessage);
      return;
    }
    setState(() {
      _guideCardExpanded = false;
      _statusMessage = null;
      _showObjectiveComplete = false;
    });
  }

  bool _shouldCompleteFromCardInReplay(GuideQuestStep step) {
    return step.actionId == GuideQuestActionId.openExplore ||
        step.actionId == GuideQuestActionId.selectIntramuros;
  }

  void _completeReplayFallbackStep(GuideQuestStep step) {
    final actionId = step.actionId ?? step.title;
    switch (step.actionId) {
      case GuideQuestActionId.openExplore:
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.selectIntramuros:
        GuideModeDemoState.selectIntramuros();
        setState(() {
          _destinationPreviewVisible = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      default:
        _completeObjective(actionId, step.completionMessage);
    }
  }

  Future<void> _handleGuideAction(String actionId) async {
    if (_actionBusy || _closing) return;
    final step = _steps[_index];
    if (step.actionId != actionId) return;

    debugPrint('Guide live action started: $actionId');
    if (step.allowsApiCalls) {
      debugPrint('Guide live action may call APIs: $actionId');
    }

    switch (actionId) {
      case GuideQuestActionId.viewRoutes:
        await _runViewRoutesAction(actionId);
        break;
      case GuideQuestActionId.pickRecommendedRoute:
        final recommended = GuideModeDemoData.routeOptions.firstWhere(
          (route) => route.recommended,
        );
        GuideModeDemoState.selectRecommendedRoute();
        setState(() {
          _selectedRoute = recommended;
          _routeGuideVisible = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.continueToFareBreakdown:
        GuideModeDemoState.viewFareBreakdown();
        setState(() {
          _fareBreakdownVisible = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.reviewFareBreakdown:
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.saveDestinationConcept:
        GuideModeDemoState.saveIntramurosFavorite();
        setState(() {
          _destinationSaved = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.reviewSavedFavorite:
        widget.onStepChanged?.call(7);
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.addToSamplePlan:
        GuideModeDemoState.addSamplePlan();
        setState(() {
          _addedToPlan = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.openPlans:
        widget.onStepChanged?.call(10);
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.showCollaboration:
        GuideModeDemoState.showCollaborationPreview();
        setState(() {
          _collaborationShown = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.openSettings:
        widget.onStepChanged?.call(12);
        _completeObjective(actionId, step.completionMessage);
        break;
      case GuideQuestActionId.selectCommuterType:
        GuideModeDemoState.selectCommuterType(_selectedCommuterType);
        setState(() {
          _fareBreakdownVisible = true;
        });
        _completeObjective(actionId, step.completionMessage);
        break;
      default:
        _completeObjective(actionId, step.completionMessage);
    }
  }

  Future<void> _runViewRoutesAction(String actionId) async {
    final actionToken = ++_liveActionToken;
    debugPrint('Guide Mode viewRoutes: using stable demo route panel');
    debugPrint(
      'Guide Mode viewRoutes: skipped live RouteOptionsScreen in guide mode',
    );

    if (!_isCurrentViewRoutesAction(actionToken, 'stable demo start')) {
      return;
    }

    setState(() {
      _actionBusy = false;
      _liveLoading = false;
      _routeOptionsVisible = true;
      _fallbackReason =
          'This walkthrough uses stable sample route cards. Normal View Routes still uses live route results outside Guide Mode.';
    });
    GuideModeDemoState.viewRoutes();

    _completeObjective(actionId, 'Route choices opened.');
  }

  bool _isCurrentViewRoutesAction(
    int actionToken,
    String phase, {
    bool logIgnored = true,
  }) {
    if (!mounted || _closing) {
      if (logIgnored) {
        debugPrint('Guide Mode viewRoutes: live result ignored after close');
      }
      return false;
    }
    if (actionToken != _liveActionToken) {
      if (logIgnored) {
        debugPrint(
          'Guide Mode viewRoutes: live result ignored because stale action '
          'at $phase',
        );
      }
      return false;
    }
    return true;
  }

  void _completeIfExpected(String actionId, String message) {
    final expected = _steps[_index].actionId;
    if (expected != actionId || _guideCardExpanded) return;
    _completeObjective(actionId, message);
  }

  void _completeObjective(String actionId, String message) {
    if (!mounted || _completedActions.contains(actionId)) return;
    final token = ++_transitionToken;
    setState(() {
      _completedActions.add(actionId);
      _showObjectiveComplete = true;
      _statusMessage = message;
    });
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!mounted || _closing || token != _transitionToken) return;
      _advance();
    });
  }

  Future<void> _handleSystemBack() async {
    if (_closing) return;
    if (!_isFirst) {
      _back();
      return;
    }

    debugPrint(
      'Guide Mode back: currentStep=$_index, canGoBack=false, '
      'result=confirm exit',
    );
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Exit Guide Mode?'),
          content: const Text(
            'You can replay Guide Mode later from Settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
    if (!mounted || shouldExit != true) return;
    await _close(skipped: true, reason: 'back');
  }

  WidgetBuilder? _demoBuilderFor(GuideQuestDemoCardType type) {
    return switch (type) {
      GuideQuestDemoCardType.destinationCard => _buildDestinationExample,
      GuideQuestDemoCardType.destinationPreview =>
        _buildDestinationPreviewStage,
      GuideQuestDemoCardType.routeOptions => _buildRouteOptionsExample,
      GuideQuestDemoCardType.routeGuide => _buildRouteGuideExample,
      GuideQuestDemoCardType.fareBreakdown => _buildFareBreakdownExample,
      GuideQuestDemoCardType.plan => _buildPlanExample,
      GuideQuestDemoCardType.collaboration => _buildCollaborationExample,
      GuideQuestDemoCardType.reminders => _buildReminderExample,
      GuideQuestDemoCardType.tripHistory => _buildHistoryExample,
      GuideQuestDemoCardType.finish => _buildFinishExample,
      GuideQuestDemoCardType.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    final stage = _stageBuilderFor(step.actionId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_handleSystemBack());
        }
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          key: ValueKey(_currentScene),
          children: [
            if (!_guideCardExpanded && stage != null) stage(context),
            GuideQuestOverlay(
              step: step,
              stepIndex: _index,
              totalSteps: _steps.length,
              // Target-key highlights are disabled for stability.
              // The old live GlobalKey target tracking caused framework
              // descendant assertions when Guide Mode moved between screens.
              targetKey: null,
              demoBuilder: _demoBuilderFor(step.demoCardType),
              expanded: _guideCardExpanded,
              isFirst: _isFirst,
              isLast: _isLast,
              isBusy: _closing || _actionBusy,
              showObjectiveComplete: _showObjectiveComplete,
              statusMessage: _statusMessage,
              onSkip: () => _close(skipped: true, reason: 'skip'),
              onBack: _back,
              onFinish: () {
                GuideModeDemoState.finishGuide();
                _close(skipped: false, reason: 'finish');
              },
              onPrimaryAction: () => _handleCardPrimary(step),
              onReminderTap: () => setState(() => _guideCardExpanded = true),
              onPracticeAgain: _restartGuide,
            ),
          ],
        ),
      ),
    );
  }

  WidgetBuilder? _stageBuilderFor(String? actionId) {
    return switch (actionId) {
      GuideQuestActionId.viewRoutes => _buildDestinationActionStage,
      GuideQuestActionId.pickRecommendedRoute => _buildRouteOptionsActionStage,
      GuideQuestActionId.continueToFareBreakdown => _buildRouteGuideActionStage,
      GuideQuestActionId.reviewFareBreakdown => _buildFareReviewActionStage,
      GuideQuestActionId.saveDestinationConcept => _buildFareActionStage,
      GuideQuestActionId.reviewSavedFavorite => _buildFavoriteReviewStage,
      GuideQuestActionId.addToSamplePlan => _buildFavoriteActionStage,
      GuideQuestActionId.openPlans => _buildPlanActionStage,
      GuideQuestActionId.showCollaboration => _buildCollaborationActionStage,
      GuideQuestActionId.openSettings => _buildSettingsActionStage,
      GuideQuestActionId.selectCommuterType => _buildCommuterTypeActionStage,
      _ => null,
    };
  }

  Widget _buildStageShell({
    required BuildContext context,
    required Widget child,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: _showObjectiveComplete,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 78, 16, 100),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(14),
                      child: Material(
                        color: Colors.transparent,
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DestinationPreview(
              destination: GuideModeDemoData.destinations.first,
              saved: _destinationSaved,
            ),
            if (_destinationPreviewVisible) ...[
              const SizedBox(height: 10),
              const _GuideNote(
                text:
                    'Intramuros is selected for this walkthrough. Nothing has been saved yet.',
              ),
            ],
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.alt_route_rounded,
              label: _liveLoading ? 'Loading route choices...' : 'View Routes',
              onPressed: _liveLoading
                  ? null
                  : () => _handleGuideAction(GuideQuestActionId.viewRoutes),
            ),
            if (_fallbackReason != null) ...[
              const SizedBox(height: 10),
              _GuideNote(text: _fallbackReason!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouteOptionsActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_routeOptionsVisible) ...[
              const _GuideNote(
                text:
                    'These sample route choices show how HalaPH compares commute options.',
              ),
              const SizedBox(height: 10),
            ],
            if (_fallbackReason != null) ...[
              _GuideNote(text: _fallbackReason!),
              const SizedBox(height: 10),
            ],
            for (final route in GuideModeDemoData.routeOptions) ...[
              _DemoRouteOptionCard(
                route: route,
                selected: _selectedRoute == route,
                onTap: route.recommended
                    ? () => _handleGuideAction(
                          GuideQuestActionId.pickRecommendedRoute,
                        )
                    : null,
              ),
              if (route != GuideModeDemoData.routeOptions.last)
                const SizedBox(height: 9),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRouteGuideActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          children: [
            if (_routeGuideVisible) ...[
              const _GuideNote(
                text: 'This guide follows the selected Jeepney + Train route.',
              ),
              const SizedBox(height: 10),
            ],
            _buildRouteGuideExample(context),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.payments_rounded,
              label: 'Continue to fare breakdown',
              onPressed: () => _handleGuideAction(
                GuideQuestActionId.continueToFareBreakdown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          children: [
            if (_fareBreakdownVisible) ...[
              const _GuideNote(
                text: 'Fare details are open for the selected commute route.',
              ),
              const SizedBox(height: 10),
            ],
            _buildFareBreakdownExample(context),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: _destinationSaved
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: _destinationSaved
                  ? 'Saved in Guide Mode'
                  : 'Save destination',
              onPressed: _destinationSaved
                  ? null
                  : () => _handleGuideAction(
                        GuideQuestActionId.saveDestinationConcept,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareReviewActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          children: [
            if (_fareBreakdownVisible) ...[
              const _GuideNote(
                text:
                    'Fare details are open for the selected commute route. Walking stays ₱0.',
              ),
              const SizedBox(height: 10),
            ],
            _buildFareBreakdownExample(context),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.favorite_border_rounded,
              label: 'Continue to Save destination',
              onPressed: () => _handleGuideAction(
                GuideQuestActionId.reviewFareBreakdown,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DestinationPreview(
              destination: GuideModeDemoData.destinations.first,
              saved: true,
            ),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.playlist_add_rounded,
              label:
                  _addedToPlan ? 'Added to sample plan' : 'Add to sample plan',
              onPressed: _addedToPlan
                  ? null
                  : () => _handleGuideAction(
                        GuideQuestActionId.addToSamplePlan,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteReviewStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GuideNote(
              text:
                  'Favorites is showing local Guide Mode state. Your real saved places are unchanged.',
            ),
            const SizedBox(height: 12),
            _DestinationPreview(
              destination: GuideModeDemoData.destinations.first,
              saved: true,
            ),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.check_circle_rounded,
              label: 'Continue',
              onPressed: () => _handleGuideAction(
                GuideQuestActionId.reviewSavedFavorite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          children: [
            _buildPlanExample(context),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.check_circle_rounded,
              label: 'Continue to collaboration',
              onPressed: () => _handleGuideAction(
                GuideQuestActionId.openPlans,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollaborationActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          children: [
            _buildCollaborationExample(context),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.settings_rounded,
              label: _collaborationShown
                  ? 'Collaboration reviewed'
                  : 'Preview collaboration',
              onPressed: _collaborationShown
                  ? null
                  : () => _handleGuideAction(
                        GuideQuestActionId.showCollaboration,
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsActionStage(BuildContext context) {
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _GuideNote(
              text:
                  'The Profile tab includes commuter type, trip history, account options, and Settings access.',
            ),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.confirmation_number_rounded,
              label: 'Continue to commuter type',
              onPressed: () => _handleGuideAction(
                GuideQuestActionId.openSettings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommuterTypeActionStage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const types = ['Regular', 'Student', 'PWD', 'Senior'];
    return _buildStageShell(
      context: context,
      child: _GuideExampleCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a Guide Mode fare type',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Student changes the sample estimate from ₱43 to ₱34. This does not update your real profile.',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in types)
                  ChoiceChip(
                    selected: _selectedCommuterType == type,
                    label: Text(type),
                    onSelected: (_) {
                      setState(() {
                        _selectedCommuterType = type;
                      });
                      GuideModeDemoState.selectCommuterType(type);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _buildFareBreakdownExample(context),
            const SizedBox(height: 12),
            _StageActionButton(
              icon: Icons.check_circle_rounded,
              label: 'Confirm ${GuideModeDemoState.commuterType}',
              onPressed: () => _handleGuideAction(
                GuideQuestActionId.selectCommuterType,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDestinationPreviewStage(BuildContext context) {
    return _GuideExampleCard(
      child: _DestinationPreview(
        destination: GuideModeDemoData.destinations.first,
        saved: _destinationSaved,
      ),
    );
  }

  Widget _buildDestinationExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final destinations = GuideModeDemoData.destinations.take(2).toList();
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < destinations.length; i++) ...[
            _DestinationPreview(destination: destinations[i]),
            if (i != destinations.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: colorScheme.outlineVariant),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteOptionsExample(BuildContext context) {
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final route in GuideModeDemoData.routeOptions) ...[
            _DemoRouteOptionCard(route: route),
            if (route != GuideModeDemoData.routeOptions.last)
              const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteGuideExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        children: [
          for (final step in GuideModeDemoData.routeGuideSteps) ...[
            _MiniGuideStep(step: step),
            if (step != GuideModeDemoData.routeGuideSteps.last)
              Divider(height: 14, color: colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _buildFareBreakdownExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fareLines = GuideModeDemoState.fareBreakdown();
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fare breakdown',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _MiniInfoPill(
                icon: Icons.confirmation_number_rounded,
                label: GuideModeDemoState.commuterType,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final line in fareLines) ...[
            if (line.isTotal) Divider(color: colorScheme.outlineVariant),
            _MiniFareRow(
              label: line.label,
              amount: line.amount,
              bold: line.isTotal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanExample(BuildContext context) {
    final plan = GuideModeDemoData.plan;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DemoBadge(icon: Icons.calendar_month_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _MiniInfoPill(
                icon: Icons.account_balance_wallet_rounded,
                label: plan.estimatedBudget,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${plan.stopCount} stops • Shared: ${plan.shared ? 'Yes' : 'No'}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [for (final stop in plan.stops) _TextChip(label: stop)],
          ),
        ],
      ),
    );
  }

  Widget _buildCollaborationExample(BuildContext context) {
    final collaboration = GuideModeDemoData.collaboration;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _DemoBadge(icon: Icons.groups_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  collaboration.planTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _MiniInfoPill(
                icon: Icons.people_alt_rounded,
                label: '${collaboration.participants.length} people',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final participant in collaboration.participants)
                _ParticipantAvatar(label: participant),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            collaboration.note,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderExample(BuildContext context) {
    final reminder = GuideModeDemoData.reminder;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _DemoBadge(icon: Icons.notifications_active_rounded),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Plan reminders',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ReminderLine(text: reminder.primary),
          const SizedBox(height: 8),
          _ReminderLine(text: reminder.secondary),
          const SizedBox(height: 10),
          Text(
            'Preview only. Guide Mode does not request notification permission.',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryExample(BuildContext context) {
    final trip = GuideModeDemoData.tripHistory;
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Row(
        children: [
          const _DemoBadge(icon: Icons.check_circle_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trip.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${trip.stopCount} stops • ${trip.finishedLabel}',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishExample(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GuideExampleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 44,
                  height: 44,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.navigation_rounded,
                        color: colorScheme.primary);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You completed your Intramuros Practice Trip.',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in const [
            'Chose a destination',
            'Compared route options',
            'Read route guide steps',
            'Checked fare estimate',
            'Saved a favorite',
            'Created a sample plan',
            'Previewed collaboration',
            'Set commuter type',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideExampleCard extends StatelessWidget {
  final Widget child;

  const _GuideExampleCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: child,
    );
  }
}

class _DestinationPreview extends StatelessWidget {
  final GuideModeDemoDestination destination;
  final bool saved;

  const _DestinationPreview({
    required this.destination,
    this.saved = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(destination.icon, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                destination.name,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${destination.type} • ${destination.locationLabel}',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                destination.ratingDisplay,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _DecorativeIconButton(
          icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: saved ? Colors.red : colorScheme.primary,
        ),
        const SizedBox(width: 6),
        _DecorativeIconButton(
          icon: Icons.directions_rounded,
          color: colorScheme.primary,
        ),
      ],
    );
  }
}

class _DemoRouteOptionCard extends StatelessWidget {
  final GuideModeDemoRouteOption route;
  final bool selected;
  final VoidCallback? onTap;

  const _DemoRouteOptionCard({
    required this.route,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer.withValues(alpha: 0.38)
                : colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected || onTap != null
                  ? colorScheme.primary.withValues(alpha: 0.50)
                  : colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            route.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        if (route.recommended) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    route.fare,
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TransportModeSequence(modes: route.modes, compact: true),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MiniInfoPill(
                      icon: Icons.schedule_rounded, label: route.time),
                  _MiniInfoPill(
                      icon: Icons.verified_rounded, label: route.source),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                route.reason,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _StageActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _GuideNote extends StatelessWidget {
  final String text;

  const _GuideNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DecorativeIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DecorativeIconButton({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _MiniGuideStep extends StatelessWidget {
  final GuideModeDemoRouteStep step;

  const _MiniGuideStep({required this.step});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final modeColor = colorForTravelMode(context, step.mode);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
          child: Text(
            '${step.number}',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Icon(iconForTravelMode(step.mode), color: modeColor, size: 20),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.instruction,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (step.fare != null)
                    Text(
                      step.fare!,
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                step.transferHint ?? step.modeLabel,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniFareRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool bold;

  const _MiniFareRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: bold ? colorScheme.primary : colorScheme.onSurface,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniInfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  final String label;

  const _TextChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DemoBadge extends StatelessWidget {
  final IconData icon;

  const _DemoBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: colorScheme.primary, size: 22),
    );
  }
}

class _ParticipantAvatar extends StatelessWidget {
  final String label;

  const _ParticipantAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: colorScheme.primary,
            child: Text(
              label.isEmpty ? '?' : label.substring(0, 1),
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderLine extends StatelessWidget {
  final String text;

  const _ReminderLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 17, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
