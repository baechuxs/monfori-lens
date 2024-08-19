// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:monforilens/ui/screens/preview.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as path;

class SelectPhoto extends StatefulWidget {
  const SelectPhoto({super.key});

  @override
  State<SelectPhoto> createState() => _SelectPhotoState();
  
}

class _SelectPhotoState extends State<SelectPhoto> {
  List<AssetEntity> _photos = [];
  final Map<String, List<AssetEntity>> _groupedPhotos = {};
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  int _currentPage = 0;
  final int _pageSize = 100;
  Set<AssetEntity> _selectedPhotos = {};

  @override
  void initState() {
    super.initState();
    _loadPhotos();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.offset >= _scrollController.position.maxScrollExtent &&
        !_scrollController.position.outOfRange) {
      _loadMorePhotos();
    }
  }

  Future<void> _loadPhotos() async {
    setState(() {
      _isLoading = true;
    });

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps != PermissionState.authorized && ps != PermissionState.limited) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isNotEmpty) {
      final List<AssetEntity> allPhotos = await albums[0].getAssetListPaged(page: 0, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _photos = allPhotos;
        _groupPhotos(allPhotos);
        _isLoading = false;
        _currentPage = 1;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePhotos() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    if (albums.isNotEmpty) {
      final List<AssetEntity> morePhotos = await albums[0].getAssetListPaged(page: _currentPage, size: _pageSize);
      if (!mounted) return;
      setState(() {
        _photos.addAll(morePhotos);
        _groupPhotos(morePhotos);
        _isLoading = false;
        _currentPage++;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _groupPhotos(List<AssetEntity> photos) {
    for (var photo in photos) {
      final String date = DateFormat('dd MMMM yyyy').format(photo.createDateTime);
      if (_groupedPhotos.containsKey(date)) {
        _groupedPhotos[date]!.add(photo);
      } else {
        _groupedPhotos[date] = [photo];
      }
    }
    setState(() {});
  }

  void _selectPhoto(AssetEntity photo) {
    setState(() {
      if (_selectedPhotos.contains(photo)) {
        _selectedPhotos.remove(photo);
      } else {
        _selectedPhotos.add(photo);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPhotos.length == _photos.length) {
        _selectedPhotos.clear();
      } else {
        _selectedPhotos = Set.from(_photos);
      }
    });
  }

  Future<List<File>> _processPhotos() async {

    // Urutkan foto berdasarkan timestamp
    final sortedPhotos = _selectedPhotos.toList()
      ..sort((a, b) => a.createDateTime.compareTo(b.createDateTime));

/*
    // Lakukan pengurutan nama file menggunakan regex
    RegExp regExp = RegExp(r'\d+'); // Contoh regex sederhana
    sortedPhotos.sort((a, b) {
      final nameA = regExp.firstMatch(path.basenameWithoutExtension(a.title))?.group(0) ?? '';
      final nameB = regExp.firstMatch(path.basenameWithoutExtension(b.title))?.group(0) ?? '';
      return nameA.compareTo(nameB);
    });
    */

    // Rename dengan penambahan suffix
    List<File> renamedFiles = [];
for (var photo in sortedPhotos) {
  File? file = await photo.file;
  if (file != null) {
    // Suffix: namafile_mflenstanggal(bulanhari)huruf romawi
    String formattedDate = DateFormat('MMdd').format(photo.createDateTime);
    String suffix = '_mflens$formattedDate${_romanize(_photos.indexOf(photo) + 1)}';
    String newName = '$suffix${path.basenameWithoutExtension(file.path)}${path.extension(file.path)}';

    // Direktori tujuan
    String targetDir = '/storage/emulated/0/Monforilens';

    // Cek apakah direktori sudah ada, jika tidak, buat direktori baru
    Directory directory = Directory(targetDir);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);  // Membuat direktori beserta sub-direktorinya jika perlu
    }

    // Fix untuk error "operation not permitted"
    String newPath = path.join(targetDir, newName); // Pastikan kamu memiliki izin di path ini
    File renamedFile = await file.copy(newPath); // Menyimpan file baru
    renamedFiles.add(renamedFile);
  }
}
return renamedFiles;
  }
  String _romanize(int num) {
    const romanNumerals = {
      1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII', 9: 'IX', 10: 'X'
    };
    return romanNumerals[num] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Select Photos', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _selectedPhotos.length == _photos.length ? "Deselect All" : "Select All",
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: _selectedPhotos.isEmpty ? null : () async {
              List<File> processedPhotos = await _processPhotos();

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Preview(sortedPhotos: processedPhotos),
                ),
              );
            },
            child: Text(
              "Next (${_selectedPhotos.length})",
              style: TextStyle(color: _selectedPhotos.isEmpty ? Colors.grey : Colors.white),
            ),
          ),
        ],
      ),
      body: _isLoading && _photos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: _scrollController,
              itemCount: _groupedPhotos.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _groupedPhotos.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final date = _groupedPhotos.keys.elementAt(index);
                final photos = _groupedPhotos[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        date,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: photos.length,
                      itemBuilder: (context, photoIndex) {
                        final photo = photos[photoIndex];
                        return FutureBuilder<Uint8List?>(
                          future: photo.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                              final isSelected = _selectedPhotos.contains(photo);
                              return GestureDetector(
                                onTap: () => _selectPhoto(photo),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory
(snapshot.data!, fit: BoxFit.cover),
                                    if (isSelected)
                                      Container(
                                        color: Colors.blue.withOpacity(0.5),
                                        child: const Icon(Icons.check, color: Colors.white),
                                      ),
                                  ],
                                ),
                              );
                            } else {
                              return const Center(child: CircularProgressIndicator());
                            }
                          },
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}

