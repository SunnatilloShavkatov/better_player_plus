import 'dart:math';

import 'package:better_player_example/constants.dart';
import 'package:better_player_example/model/video_list_data.dart';
import 'package:better_player_example/pages/video_list/video_list_widget.dart';
import 'package:material_ui/material_ui.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  final _random = Random();
  final List<String> _videos = [
    Constants.bugBuckBunnyVideoUrl,
    Constants.forBiggerBlazesUrl,
    Constants.forBiggerJoyridesVideoUrl,
    Constants.elephantDreamVideoUrl,
  ];
  List<VideoListData> dataList = [];
  int value = 0;

  @override
  void initState() {
    _setupData();
    super.initState();
  }

  void _setupData() {
    for (int index = 0; index < 10; index++) {
      final randomVideoUrl = _videos[_random.nextInt(_videos.length)];
      dataList.add(VideoListData('Video $index', randomVideoUrl));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Video in list')),
    body: ColoredBox(
      color: Colors.grey,
      child: Column(
        children: [
          TextButton(
            child: const Text('Update page state'),
            onPressed: () {
              setState(() {
                value++;
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: dataList.length,
              itemBuilder: (context, index) {
                final VideoListData videoListData = dataList[index];
                return VideoListWidget(videoListData: videoListData);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
