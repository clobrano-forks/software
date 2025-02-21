import 'package:flutter/material.dart';
import 'package:packagekit/packagekit.dart';
import 'package:provider/provider.dart';
import 'package:software/store_app/my_apps/my_apps_page.dart';
import 'package:software/store_app/my_apps/my_packages_model.dart';
import 'package:software/store_app/my_apps/package_banner.dart';
import 'package:ubuntu_service/ubuntu_service.dart';
import 'package:yaru_widgets/yaru_widgets.dart';

class MyPackagesPage extends StatefulWidget {
  const MyPackagesPage({Key? key}) : super(key: key);

  static Widget create(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyPackagesModel(getService<PackageKitClient>()),
      child: const MyPackagesPage(),
    );
  }

  @override
  State<MyPackagesPage> createState() => _MyPackagesPageState();
}

class _MyPackagesPageState extends State<MyPackagesPage> {
  @override
  void initState() {
    context.read<MyPackagesModel>().init();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<MyPackagesModel>();
    return YaruPage(
      children: [
        if (model.packages.isEmpty)
          Container()
        else
          GridView.builder(
            gridDelegate: myAppsGridDelegate,
            shrinkWrap: true,
            itemCount: model.packages.length,
            itemBuilder: (context, index) {
              final packageId = model.packages.elementAt(index);
              return PackageBanner.create(context, packageId);
            },
          ),
      ],
    );
  }
}
