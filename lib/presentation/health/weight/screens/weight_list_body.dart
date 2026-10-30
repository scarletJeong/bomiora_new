part of 'weight_list_screen.dart';

extension _WeightListBody on _WeightListScreenState {
  // 6. 눈바디 이미지
  Widget _buildBodyImages() {
    final frontImagePath = selectedRecord?.frontImagePath;
    final sideImagePath = selectedRecord?.sideImagePath;
    final gap = healthDp(context, 10);

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = (constraints.maxWidth - gap) / 2;
        return Row(
          children: [
            SizedBox(
              width: side,
              height: side,
              child: PhotoSourceAnchor(
                canOpen: _canAddBodyPhoto,
                onImageSelected: (image) => _applyPickedImage('front', image),
                child: _buildImageContainer('정면사진', frontImagePath),
              ),
            ),
            SizedBox(width: gap),
            SizedBox(
              width: side,
              height: side,
              child: PhotoSourceAnchor(
                canOpen: _canAddBodyPhoto,
                onImageSelected: (image) => _applyPickedImage('side', image),
                child: _buildImageContainer('측면사진', sideImagePath),
              ),
            ),
          ],
        );
      },
    );
  }

  // 이미지 컨테이너 위젯
  Widget _buildImageContainer(String label, String? imagePath) {
    final raw = imagePath?.trim();
    final networkUrl = (raw != null &&
            raw.isNotEmpty &&
            (ImageUrlHelper.isRemoteImageUrl(raw) ||
                raw.startsWith('/api/') ||
                raw.contains('weight_images') ||
                raw.contains('data/weight')))
        ? ImageUrlHelper.getImageUrl(raw)
        : null;
    final localPath = (!kIsWeb &&
            raw != null &&
            raw.isNotEmpty &&
            networkUrl == null &&
            ImagePickerUtils.isImageFileExists(raw))
        ? raw
        : null;
    final blobUrl =
        kIsWeb && raw != null && raw.startsWith('blob:') ? raw : null;
    final hasImage = networkUrl != null || localPath != null || blobUrl != null;

    return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: hasImage ? Colors.grey[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
            border: Border.all(
              color: hasImage ? Colors.grey[300]! : Colors.grey[200]!,
              width: healthDp(context, 1),
            ),
          ),
          child: hasImage
              ? Stack(
                  children: [
                    // 이미지 표시
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 12)),
                      child: (networkUrl != null || blobUrl != null)
                          ? Image.network(
                              networkUrl ?? blobUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildImagePlaceholder(label);
                              },
                            )
                          : Image.file(
                              File(localPath!),
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildImagePlaceholder(label);
                              },
                            ),
                    ),
                    // 삭제 버튼
                    Positioned(
                      top: healthDp(context, 4),
                      right: healthDp(context, 4),
                      child: GestureDetector(
                        onTap: () => _deleteImage(raw!),
                        child: Container(
                          padding: EdgeInsets.all(healthDp(context, 4)),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: healthDp(context, 16),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : _buildImagePlaceholder(label),
    );
  }

  // 이미지 플레이스홀더
  Widget _buildImagePlaceholder(String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: healthDp(context, 40),
          color: Colors.grey[400],
        ),
        SizedBox(height: healthDp(context, 8)),
        Text(
          label,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: healthSp(context, 12),
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  bool _canAddBodyPhoto() {
    if (selectedRecord?.frontImagePath != null &&
        selectedRecord?.sideImagePath != null) {
      AppToastOverlay.showAlert(
        context,
        '하루에 최대 2장까지 등록할 수 있습니다.',
      );
      return false;
    }
    return true;
  }

  Future<void> _applyPickedImage(String type, XFile? image) async {
    if (image == null) return;
    try {
      String? imageUrl;

      if (kIsWeb) {
        try {
          imageUrl = await WeightRepository.uploadImage(image);
        } catch (e) {
          imageUrl = image.path;
        }
      } else {
        final File imageFile = File(image.path);
        imageUrl = await WeightRepository.uploadImage(imageFile);
      }

      if (imageUrl == null || !mounted) return;

      if (selectedRecord != null) {
        final updatedRecord = selectedRecord!.copyWith(
          frontImagePath:
              type == 'front' ? imageUrl : selectedRecord!.frontImagePath,
          sideImagePath:
              type == 'side' ? imageUrl : selectedRecord!.sideImagePath,
        );

        await WeightRepository.updateWeightRecord(updatedRecord);
        notifyHealthDataChanged(HealthRefreshDomain.weight);
        _loadData();
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeightInputScreen(
              recordContextDate: selectedDate,
              initialImages: {
                'front': type == 'front' ? imageUrl : null,
                'side': type == 'side' ? imageUrl : null,
              },
            ),
          ),
        );
      }
    } catch (e) {}
  }

  // 이미지 삭제
  Future<void> _deleteImage(String imagePath) async {
    try {
      // 확인 다이얼로그
      final confirmed = await showHealthDeletePopup(
        context: context,
        title: '이미지 삭제',
        message: '이미지를 삭제하시겠습니까?',
      );

      if (confirmed == true && selectedRecord != null) {
        // 파일 시스템에서 이미지 삭제
        await ImagePickerUtils.deleteImageFile(imagePath);

        // 데이터베이스에서 이미지 경로 제거
        final updatedRecord = selectedRecord!.copyWith(
          clearFrontImage: imagePath == selectedRecord!.frontImagePath,
          clearSideImage: imagePath == selectedRecord!.sideImagePath,
        );

        await WeightRepository.updateWeightRecord(updatedRecord);
        notifyHealthDataChanged(HealthRefreshDomain.weight);
        _loadData(); // 데이터 새로고침
      }
    } catch (e) {}
  }
}
