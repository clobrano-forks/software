import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snapd/snapd.dart';
import 'package:software/services/app_change_service.dart';
import 'package:software/store_app/common/snap_model.dart';
import 'package:software/store_app/common/snap_section.dart';
import 'package:software/store_app/explore/explore_model.dart';
import 'package:software/store_app/explore/snap_banner.dart';
import 'package:software/store_app/common/snap_dialog.dart';
import 'package:software/services/color_generator.dart';
import 'package:ubuntu_service/ubuntu_service.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

class SnapBannerCarousel extends StatefulWidget {
  const SnapBannerCarousel({
    Key? key,
    required this.snapSection,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  final SnapSection snapSection;
  final Duration duration;

  @override
  State<SnapBannerCarousel> createState() => _SnapBannerCarouselState();
}

class _SnapBannerCarouselState extends State<SnapBannerCarousel> {
  @override
  void initState() {
    super.initState();
    context.read<ExploreModel>().loadSection(widget.snapSection.title);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ExploreModel>();
    final size = MediaQuery.of(context).size;
    final sections =
        model.sectionNameToSnapsMap[widget.snapSection.title] ?? [];
    return sections.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(
              bottom: 20,
            ),
            child: YaruCarousel(
              viewportFraction: 1,
              placeIndicator: false,
              autoScrollDuration: widget.duration,
              width: size.width,
              height: 178,
              autoScroll: true,
              children: [
                for (final snap in sections)
                  _AppBannerCarouselItem.create(context, snap)
              ],
            ),
          )
        : const SizedBox();
  }
}

class _AppBannerCarouselItem extends StatefulWidget {
  const _AppBannerCarouselItem({
    Key? key,
    required this.snap,
  }) : super(key: key);

  final Snap snap;

  static Widget create(BuildContext context, Snap snap) {
    return ChangeNotifierProvider<SnapModel>(
      create: (_) => SnapModel(
        getService<SnapdClient>(),
        getService<AppChangeService>(),
        huskSnapName: snap.name,
        colorGenerator: getService<ColorGenerator>(),
      ),
      child: _AppBannerCarouselItem(snap: snap),
    );
  }

  @override
  State<_AppBannerCarouselItem> createState() => _AppBannerCarouselItemState();
}

class _AppBannerCarouselItemState extends State<_AppBannerCarouselItem> {
  @override
  void initState() {
    super.initState();
    context.read<SnapModel>().init();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SnapModel>();
    return SnapBanner(
      watermark: true,
      snap: widget.snap,
      surfaceTintColor: model.surfaceTintColor,
      onTap: () => showDialog(
        context: context,
        builder: (context) =>
            SnapDialog.create(context: context, huskSnapName: widget.snap.name),
      ),
    );
  }
}
