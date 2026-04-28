import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

// --------------- Providers ---------------

final communityPostsStreamProvider = StreamProvider<List<CommunityPost>>((ref) {
  if (Firebase.apps.isEmpty) {
    return Stream.error(
      'Firebase is not initialized. Configure Firebase and restart the app.',
    );
  }

  final query = FirebaseFirestore.instance
      .collection('community_tips')
      .orderBy('createdAt', descending: true);

  return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => CommunityPost.fromFirestore(doc))
            .toList(),
      );
});

class CommunityPost {
  final String id;
  final String authorUid;
  final String userName;
  final String userInitial;
  final Color avatarColor;
  final String message;
  final String tag;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.authorUid,
    required this.userName,
    required this.userInitial,
    required this.avatarColor,
    required this.message,
    required this.tag,
    required this.createdAt,
  });

  factory CommunityPost.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdAt = data['createdAt'];
    final createdAtDate = createdAt is Timestamp
        ? createdAt.toDate()
        : DateTime.now();

    return CommunityPost(
      id: doc.id,
      authorUid: (data['authorUid'] as String?) ?? '',
      userName: (data['userName'] as String?) ?? 'Farmer',
      userInitial: (data['userInitial'] as String?) ?? 'F',
      avatarColor: Color((data['avatarColor'] as int?) ?? AppColors.primary.value),
      message: (data['message'] as String?) ?? '',
      tag: (data['tag'] as String?) ?? '🌾 Crop Tips',
      createdAt: createdAtDate,
    );
  }

  String relativeTime() {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

// --------------- Screen ---------------

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  String _selectedTag = 'All';
  String? _cachedGuestId;

  final List<String> _tags = [
    'All',
    '🌾 Crop Tips',
    '🌿 Natural Remedy',
    '💰 Market Query',
    '💧 Water Saving',
  ];

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostsStreamProvider);
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final viewerId = currentUserId ?? _guestId();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ─── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFF6A1B9A),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
              title: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Farmer Community',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.normal)),
                  Text('Community Tips',
                      style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20),
                    child: Opacity(
                        opacity: 0.15,
                        child: Text('👨‍🌾', style: TextStyle(fontSize: 90))),
                  ),
                ),
              ),
            ),
          ),

          // ─── Filter Tags ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: _tags
                    .map((tag) => _TagChip(
                          label: tag,
                          selected: _selectedTag == tag,
                          onTap: () => setState(() => _selectedTag = tag),
                        ))
                    .toList(),
              ),
            ),
          ),

          // ─── Post Count ──────────────────────────────────────────────
          postsAsync.when(
            data: (posts) {
              final filtered = _selectedTag == 'All'
                  ? posts
                  : posts.where((p) => p.tag == _selectedTag).toList();

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    '${filtered.length} tips',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
          ),

          // ─── Posts ───────────────────────────────────────────────────
          postsAsync.when(
            data: (posts) {
              final filtered = _selectedTag == 'All'
                  ? posts
                  : posts.where((p) => p.tag == _selectedTag).toList();

              if (filtered.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                    child: Text(
                      'No tips yet. Be the first to post one.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = filtered[index];
                    final isMine = post.authorUid.isNotEmpty &&
                      post.authorUid == viewerId;
                      return _PostBubble(
                      post: post,
                      isMine: isMine,
                      onDelete: isMine
                        ? () => _confirmDelete(post)
                          : null,
                    );
                  },
                  childCount: filtered.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Unable to load tips right now.\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ─── FAB: Post ──────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPostDialog(context),
        backgroundColor: const Color(0xFF7B1FA2),
        icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: const Text('Post a Tip',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showPostDialog(BuildContext context) {
    final ctrl = TextEditingController();
    String selectedTag = '🌾 Crop Tips';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Share Experience',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark)),
              const Text('Share your farming tip',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share farming tips... (English)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        const BorderSide(color: Color(0xFF7B1FA2), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedTag,
                decoration: const InputDecoration(
                  labelText: 'Tip category',
                  border: OutlineInputBorder(),
                ),
                items: _tags
                    .where((tag) => tag != 'All')
                    .map(
                      (tag) => DropdownMenuItem<String>(
                        value: tag,
                        child: Text(tag),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setModalState(() => selectedTag = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B1FA2)),
                      onPressed: () async {
                        if (ctrl.text.trim().isNotEmpty) {
                          final posted =
                              await _createPost(ctrl.text.trim(), selectedTag);
                          if (posted && ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        }
                      },
                      child: const Text('Post',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _createPost(String message, String tag) async {
    if (Firebase.apps.isEmpty) {
      _showMessage(
        'Firebase is not configured for this run. Add FIREBASE_WEB_* dart-defines and restart.',
      );
      return false;
    }

    final currentUser = ref.read(authStateProvider).value;
    final name = currentUser?.displayName?.trim().isNotEmpty == true
        ? currentUser!.displayName!.trim()
        : 'Guest Farmer';
    final initial = name.substring(0, 1).toUpperCase();
    final authorUid = currentUser?.uid ?? _guestId();

    try {
      await FirebaseFirestore.instance.collection('community_tips').add({
        'authorUid': authorUid,
        'userName': name,
        'userInitial': initial,
        'avatarColor': _colorFromSeed(authorUid).value,
        'message': message,
        'tag': tag,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      if (!mounted) {
        return false;
      }
      final message = e.code == 'permission-denied'
          ? 'Posting is blocked by Firestore rules. Allow write access for community_tips.'
          : 'Could not post tip: ${e.message ?? e.code}';
      _showMessage(message);
      return false;
    } catch (_) {
      _showMessage('Could not post tip right now. Please try again.');
      return false;
    }
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    if (Firebase.apps.isEmpty) {
      _showMessage(
        'Firebase is not configured for this run. Add FIREBASE_WEB_* dart-defines and restart.',
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tip?'),
        content: const Text('This tip will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('community_tips')
            .doc(post.id)
            .delete();
      } on FirebaseException catch (e) {
        if (!mounted) {
          return;
        }
        final message = e.code == 'permission-denied'
            ? 'Delete is blocked by Firestore rules for this user.'
            : 'Could not delete tip: ${e.message ?? e.code}';
        _showMessage(message);
      } catch (_) {
        _showMessage('Could not delete tip right now. Please try again.');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Color _colorFromSeed(String seed) {
    final palette = <Color>[
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFF00695C),
    ];
    return palette[seed.hashCode.abs() % palette.length];
  }

  String _guestId() {
    if (_cachedGuestId != null) {
      return _cachedGuestId!;
    }

    final box = Hive.box('settings');
    final existing = box.get('community_guest_id') as String?;
    if (existing != null && existing.isNotEmpty) {
      _cachedGuestId = existing;
      return existing;
    }

    final generated = 'guest_${DateTime.now().millisecondsSinceEpoch}';
    _cachedGuestId = generated;
    box.put('community_guest_id', generated);
    return generated;
  }
}

// ─── Tag Chip ─────────────────────────────────────────────────────────────────
class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF7B1FA2) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? const Color(0xFF7B1FA2) : Colors.grey.shade300),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: const Color(0xFF7B1FA2).withValues(alpha: 0.3),
                      blurRadius: 6)
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Post Card ────────────────────────────────────────────────────────────────
class _PostBubble extends StatelessWidget {
  final CommunityPost post;
  final bool isMine;
  final VoidCallback? onDelete;

  const _PostBubble({
    required this.post,
    required this.isMine,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine)
            CircleAvatar(
              radius: 16,
              backgroundColor: post.avatarColor,
              child: Text(
                post.userInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!isMine) const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isMine ? const Color(0xFFD8F7C9) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isMine ? 'You' : post.userName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isMine ? AppColors.primaryDark : post.avatarColor,
                            ),
                          ),
                        ),
                        if (onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.redAccent,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      post.message,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          post.tag,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          post.relativeTime(),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMine) const SizedBox(width: 8),
          if (isMine)
            const Icon(
              Icons.done_all_rounded,
              size: 15,
              color: Color(0xFF4FC3F7),
            ),
        ],
      ),
    );
  }
}
