import 'package:flutter/material.dart';
import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../shared/widgets/app_components.dart';

class AddFilesSheet extends StatefulWidget {
  final String subjectName;
  final Function(String fileName, String section)? onFileAdded;

  const AddFilesSheet({super.key, required this.subjectName, this.onFileAdded});

  static Future<void> show(
    BuildContext context, {
    required String subjectName,
    Function(String fileName, String section)? onFileAdded,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => AddFilesSheet(
        subjectName: subjectName,
        onFileAdded: onFileAdded,
      ),
    );
  }

  @override
  State<AddFilesSheet> createState() => _AddFilesSheetState();
}

class _AddFilesSheetState extends State<AddFilesSheet> {
  String? _selectedSource;
  String _targetSection = 'Notes';
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _selectedFileName = '';

  final List<String> _sections = const ['Syllabus', 'Notes', 'Books', 'Previous papers'];

  void _onSourceSelected(String source, String sampleName) {
    setState(() {
      _selectedSource = source;
      _selectedFileName = sampleName;
    });
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _uploadProgress = i * 0.2);
    }

    widget.onFileAdded?.call(_selectedFileName, _targetSection);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "$_selectedFileName" to $_targetSection'),
          backgroundColor: AppColors.textPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add files', style: AppTypography.sectionHeading),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_selectedSource == null) ...[
              _buildSourceRow(
                icon: Icons.add_to_drive_outlined,
                label: 'Choose from Google Drive',
                onTap: () => _onSourceSelected('Drive', '${widget.subjectName}_drive_doc.pdf'),
              ),
              _buildSourceRow(
                icon: Icons.upload_file_outlined,
                label: 'Upload from phone',
                onTap: () => _onSourceSelected('Phone', 'Lecture_notes.pdf'),
              ),
              _buildSourceRow(
                icon: Icons.camera_alt_outlined,
                label: 'Take a photo',
                onTap: () => _onSourceSelected('Photo', 'Whiteboard_photo.jpg'),
              ),
              _buildSourceRow(
                icon: Icons.mic_none_outlined,
                label: 'Record audio',
                onTap: () => _onSourceSelected('Audio', 'Lecture_recording.m4a'),
              ),
              _buildSourceRow(
                icon: Icons.link_outlined,
                label: 'Paste a link',
                onTap: () => _onSourceSelected('Link', 'Reference_article.pdf'),
              ),
            ] else ...[
              Text(
                'Add "$_selectedFileName" to:',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sections.map((sec) {
                  final isSel = _targetSection == sec;
                  return AppChip(
                    label: sec,
                    isSelected: isSel,
                    onTap: () => setState(() => _targetSection = sec),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              if (_isUploading) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Uploading to Drive...', style: AppTypography.secondary),
                    Text('${(_uploadProgress * 100).toInt()}%', style: AppTypography.smallLabel),
                  ],
                ),
                const SizedBox(height: 8),
                AppProgressBar(value: _uploadProgress),
                const SizedBox(height: 16),
              ] else ...[
                AppPrimaryButton(
                  label: 'Add to $_targetSection',
                  onPressed: _startUpload,
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _selectedSource = null),
                    child: const Text('Back to options'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.textPrimary),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
