import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:slimsocial_for_facebook/services/store.dart';
import 'package:slimsocial_for_facebook/utils/telemetry.dart';
import 'package:slimsocial_for_facebook/utils/utils.dart';

/// Shows the rating prompt. Returns once the user is done with it.
///
/// [onRated] is called with the star count the moment a star is tapped, before
/// either branch runs, so the caller can record that the question was answered
/// even if what follows fails or is abandoned.
Future<void> showRatingDialog({
  required BuildContext context,
  required Future<void> Function(int stars) onRated,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) => RatingDialog(onRated: onRated),
    );

/// The prompt itself. Two steps: the stars, then — for a low rating — a box.
class RatingDialog extends StatefulWidget {
  const RatingDialog({required this.onRated, super.key});

  final Future<void> Function(int stars) onRated;

  /// At or above this, the user is sent to the store instead of being asked
  /// what is wrong.
  static const int kPositiveStars = 4;

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  final TextEditingController _controller = TextEditingController();
  int? _stars;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onStar(int stars) async {
    //recorded first: a person who rates two stars and then closes the box has
    //still answered, and asking them again would be the nagging the schedule
    //exists to avoid
    await widget.onRated(stars);
    if (!mounted) return;

    if (stars >= RatingDialog.kPositiveStars) {
      Navigator.of(context).pop();
      //no store sheet in an F-Droid build, so the thanks is all there is to
      //give back; showing it unconditionally would double up on Play, where
      //the sheet already appears
      if (!storeServices.canRequestReview) {
        showToast('rate_thanks'.tr());
        return;
      }
      await storeServices.requestReview();
      return;
    }

    setState(() => _stars = stars);
  }

  Future<void> _send() async {
    setState(() => _sending = true);

    final sent = await Telemetry.captureFeedback(
      stars: _stars!,
      text: _controller.text,
    );

    if (!mounted) return;
    Navigator.of(context).pop();
    showToast(sent ? 'rate_thanks'.tr() : 'rate_failed'.tr());
  }

  @override
  Widget build(BuildContext context) {
    if (_stars == null) return _stepStars(context);
    return _stepFeedback(context);
  }

  Widget _stepStars(BuildContext context) => AlertDialog(
        title: Text('rate_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('rate_subtitle'.tr()),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final stars = i + 1;
                return IconButton(
                  key: ValueKey('rating_star_$stars'),
                  icon: const Icon(Icons.star_border),
                  onPressed: () => _onStar(stars),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('rate_later'.tr()),
          ),
        ],
      );

  Widget _stepFeedback(BuildContext context) {
    //nothing to send it to, so no box: a Send button that cannot send is
    //worse than not offering one
    if (!Telemetry.canCollectFeedback) {
      return AlertDialog(
        title: Text('rate_low_title'.tr()),
        content: Text('rate_thanks'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('rate_later'.tr()),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('rate_low_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(hintText: 'rate_low_hint'.tr()),
          ),
          //shown only to someone who turned reporting off, because for them
          //pressing send is the whole of the consent
          if (!Telemetry.isEnabled) ...[
            const SizedBox(height: 12),
            Text(
              'rate_sends_notice'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text('rate_later'.tr()),
        ),
        TextButton(
          onPressed: _sending ? null : _send,
          child: Text('rate_send'.tr()),
        ),
      ],
    );
  }
}
