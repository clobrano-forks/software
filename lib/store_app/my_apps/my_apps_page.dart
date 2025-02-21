import 'package:flutter/material.dart';
import 'package:software/l10n/l10n.dart';
import 'package:software/store_app/my_apps/my_packages_page.dart';
import 'package:software/store_app/my_apps/my_snaps_page.dart';
import 'package:yaru_icons/yaru_icons.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

class MyAppsPage extends StatelessWidget {
  const MyAppsPage({Key? key, this.online = true}) : super(key: key);

  final bool online;

  static Widget createTitle(BuildContext context) =>
      Text(context.l10n.myAppsPageTitle);

  @override
  Widget build(BuildContext context) {
    return YaruTabbedPage(
      tabIcons: const [
        YaruIcons.package_snap,
        YaruIcons.package_deb,
        YaruIcons.computer
      ],
      tabTitles: const ['Snaps', 'Debian packages', 'System upgrades'],
      views: [
        MySnapsPage.create(context, online),
        MyPackagesPage.create(context),
        const Center(
          child: Icon(
            YaruIcons.computer,
            size: 100,
          ),
        )
      ],
    );
  }
}

const myAppsGridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
  mainAxisExtent: 110,
  mainAxisSpacing: 15,
  crossAxisSpacing: 15,
  maxCrossAxisExtent: 600,
);
